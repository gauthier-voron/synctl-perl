package Synctl::Receiver;

use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:mode);
use POSIX qw(lchown);
use Synctl qw(:error :verbose);


sub __server_path
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__server_path'} = $value;
    }

    return $self->{'__server_path'};
}

sub __client_path
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__client_path'} = $value;
    }

    return $self->{'__client_path'};
}

sub __snapshot
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__snapshot'} = $value;
    }

    return $self->{'__snapshot'};
}

sub __deposit
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__deposit'} = $value;
    }

    return $self->{'__deposit'};
}

sub __filter
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__filter'} = $value;
    }

    return $self->{'__filter'};
}


sub new
{
    my ($class, $server_path, $client_path, $snapshot, $deposit, @err) = @_;
    my $self;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self = bless({}, $class);
    
    $self->__server_path($server_path);
    $self->__client_path($client_path);
    $self->__snapshot($snapshot);
    $self->__deposit($deposit);
    $self->__filter(sub { return 1 });

    $self->force(1);
    
    return $self;
}


sub force
{
    my ($self, $value, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    if (defined($value)) {
	$self->{'force'} = $value;
    }

    return $self->{'force'};
}

sub filter
{
    my ($self, $value, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (defined($value)) {
	if (ref($value) eq 'CODE') {
	    $self->__filter(sub { $_ = shift() ; return $value->($_) });
	} else {
	    return throw(EINVLD, $value);
	}
    }

    return $self->__filter();
}


sub server_path
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__server_path();
}

sub client_path
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__client_path();
}

sub snapshot
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__snapshot();
}

sub deposit
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__deposit();
}


sub __normalize_error
{
    my ($error, $sep) = @_;

    if (!defined($sep)) {
	$sep = '';
    }

    if (ref($error) eq 'CODE') {
	return $error;
    } elsif (ref($error) eq 'ARRAY') {
	return sub { push(@$error, shift()); }
    } elsif (ref($error) eq 'IO::Handle') {
        return sub { $error->printf("%s%s", shift(), $sep) };
    } elsif (ref($error) eq 'SCALAR') {
	return sub { $$error .= shift() . $sep; }
    } else {
	return undef;
    }
}


sub __server_properties
{
    my ($self, $name) = @_;
    my $spath = $self->server_path();
    my ($props, $path);

    if ($spath eq '/') {
	$path = $name;
    } elsif ($name eq '/') {
	$path = $spath;
    } else {
	$path = $spath . $name;
    }
    
    $props = $self->snapshot()->get_properties($path);

    if (defined($props)) {
	$props->{PATH} = $path;
    }

    return $props;
}

sub __client_properties
{
    my ($self, $name) = @_;
    my $cpath = $self->client_path();
    my ($path, $mode, $user, $group, $mtime, $inode);

    if ($cpath eq '/') {
	$path = $name;
    } elsif ($name eq '/') {
	$path = $cpath;
    } else {
	$path = $cpath . $name;
    }

    ($mode, $user, $group, $mtime, $inode) = (lstat($path))[2, 4, 5, 9, 1];

    if (!defined($mode)) {
	return { PATH => $path, MODE => 0 };
    } else {
	return { PATH => $path, MODE => $mode, USER => $user, GROUP => $group,
		 MTIME => $mtime, INODE => $inode };
    }
}

sub __delete
{
    my ($self, $path) = @_;
    my ($dh, $entry);

    if (-d $path && !(-l $path)) {
	if (!chmod(0700, $path)) {
	    return 0;
	}
	
	if (!opendir($dh, $path)) {
	    return 0;
	}

	foreach $entry (grep { ! /^\.\.?$/ } readdir($dh)) {
	    $self->__delete($path . '/' . $entry);
	}

	closedir($dh);
	if (!rmdir($path)) {
	    return 0;
	}
    } else {
	if (!unlink($path)) {
	    return 0;
	}
    }

    return 1;
}


sub __receive_properties
{
    my ($self, $sprops, $cprops) = @_;
    my ($smode, $cmode) = (S_IMODE($sprops->{MODE}), S_IMODE($cprops->{MODE}));
    my ($user, $group) = (-1, -1);
    my ($sval, $cval);
    my $diff = 0;

    if ((S_IFMT($sprops->{MODE}) != S_IFLNK) &&
	($smode != $cmode || $self->force())) {
	if (chmod($smode, $cprops->{PATH})) {
	    $diff = ($smode != $cmode);
	}
    }

    if (defined($sval = $sprops->{USER}) &&
	(!defined($cval = $cprops->{USER}) || $cval != $sval)) {
	$user = $sval;
    }

    if (defined($sval = $sprops->{GROUP}) &&
	(!defined($cval = $cprops->{GROUP}) || $cval != $sval)) {
	$group = $sval;
    }

    if ($user != -1 || $group != -1) {
	if (lchown($user, $group, $cprops->{PATH})) {
	    $diff = 1;
	}
    }

    if (defined($sval = $sprops->{MTIME}) &&
	(!defined($cval = $cprops->{MTIME}) || $cval != $sval)) {
	if (utime($sval, $sval, $cprops->{PATH})) {
	    $diff = 1;
	}
    }

    return $diff;
}

sub __receive_link
{
    my ($self, $name, $sprops, $cprops) = @_;
    my ($content, $shash, $chash, $ret);
    my $diff = 0;

    if ($cprops->{MODE} == 0) {
	$chash = 0;
    } else {
	$content = readlink($cprops->{PATH});
	if (!defined($content)) {
	    return undef;
	}
	$chash = md5_hex($content);
    }

    $shash = $self->snapshot()->get_file($sprops->{PATH});

    if ($shash ne $chash) {
	$ret = $self->deposit()->recv($shash, \$content);
	if (!$ret) {
	    return undef;
	}
	
	if ($cprops->{MODE} != 0 && !unlink($cprops->{PATH})) {
	    return undef;
	}
	if (!symlink($content, $cprops->{PATH})) {
	    return undef;
	}

	$diff = 1;
    }

    if ($self->__receive_properties($sprops, $cprops)) {
	$diff = 1;
    }
    
    return $diff;
}

sub __receive_file
{
    my ($self, $name, $sprops, $cprops) = @_;
    my ($fh, $mode, $flag, $ctx, $shash, $chash, $ret);
    my $diff = 0;

    if ($cprops->{MODE} == 0) {
	$chash = 0;
    } else {
	$mode = $cprops->{MODE};
	$flag = S_IRUSR | S_IWUSR;
	if ($self->force() && (($mode & $flag) != $flag)) {
	    $mode |= $flag;
	    if (!chmod($mode, $cprops->{PATH})) {
		return undef;
	    }
	}

	if (!open($fh, '<', $cprops->{PATH})) {
	    return undef;
	}

	$ctx = Digest::MD5->new();
	$ctx->addfile($fh);

	close($fh);
	$chash = $ctx->hexdigest();
    }

    $shash = $self->snapshot()->get_file($sprops->{PATH});

    if ($shash ne $chash) {
	if (!open($fh, '>', $cprops->{PATH})) {
	    return undef;
	}

	$ret = $self->deposit()->recv($shash, $fh);

	close($fh);
	if (!$ret) {
	    return undef;
	}

	$diff = 1;
    }

    if ($self->__receive_properties($sprops, $cprops)) {
	$diff = 1;
    }
    
    return $diff;
}

sub __receive_directory
{
    my ($self, $name, $sprops, $cprops) = @_;
    my ($dh, @sentries, @centries, $entry, $cmp, $ret, $mode);
    my $sep = ($name eq '/') ? '' : '/';
    my $diff = 0;

    if ($cprops->{MODE} == 0) {
	if (!mkdir($cprops->{PATH})) {
	    return undef;
	}
	$diff = 1;
    } else {
	$mode = $cprops->{MODE};
	if ($self->force() && (($mode & S_IRWXU) != S_IRWXU)) {
	    $mode |= S_IRWXU;
	    if (!chmod($mode, $cprops->{PATH})) {
		return undef;
	    }
	}
	
	if (!opendir($dh, $cprops->{PATH})) {
	    return undef;
	} else {
	    @centries = sort { $a cmp $b }
	               grep { ! /^\.\.?$/ }
	               readdir($dh);
	    closedir($dh);
	}
    }

    @sentries = sort { $a cmp $b }
	        grep { ! /^\.\.?$/ }
                @{ $self->snapshot()->get_directory($sprops->{PATH}) };

    $ret = 0;
    
    while (@sentries && @centries) {
	$cmp = $sentries[0] cmp $centries[0];
	
	if ($cmp <= 0) {
	    $ret += $self->__receive($name . $sep . $sentries[0]);
	    shift(@sentries);
	}

	if ($cmp > 0) {
	    $ret += $self->__receive($name . $sep . $centries[0]);
	}

	if ($cmp >= 0) {
	    shift(@centries);
	}
    }

    foreach $entry (@sentries, @centries) {
	$ret += $self->__receive($name . $sep . $entry);
    }

    if ($self->__receive_properties($sprops, $cprops)) {
	$diff = 1;
    }
    
    return $diff + $ret;
}

sub __receive
{
    my ($self, $name) = @_;
    my $sprops = $self->__server_properties($name);
    my $cprops = $self->__client_properties($name);
    my $filter = $self->filter();
    my ($stype, $ctype, $action);
    my %actions = (
	S_IFLNK() => \&__receive_link,
	S_IFREG() => \&__receive_file,
	S_IFDIR() => \&__receive_directory,
	);

    notify(DEBUG, IFCHECK, $name);

    if (!$filter->($name)) {
	return 0;
    }

    if (!defined($sprops)) {
	$self->__delete($cprops->{PATH});
	return 1;
    }

    $stype = S_IFMT($sprops->{MODE});
    $ctype = S_IFMT($cprops->{MODE});

    $action = $actions{$stype};
    if (!defined($action)) {
	return 0;
    }

    if ($stype != $ctype && $ctype != 0) {
	$self->__delete($cprops->{PATH});
	$cprops->{MODE} = 0;
    }

    notify(INFO, IFRECV, $name);
    return $action->($self, $name, $sprops, $cprops);
}


sub receive
{
    my ($self, @err) = @_;
    my ($done, $err);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    $done = $self->__receive('/');
    $err = 0;
    return ($done, $err);
}


1;
__END__
