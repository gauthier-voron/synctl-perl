package Synctl::File::1::Snapshot;

use parent qw(Synctl::Snapshot);
use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Synctl qw(:error :verbose);


sub __path { return shift()->_rw('__path', @_); }
sub __id   { return shift()->_rw('__id',   @_); }

sub _id   { return shift()->_ro('__id',   @_); }

sub path { return shift()->_ro('__path', @_); }


sub _new
{
    my ($self, $path, $id, @err) = @_;

    if (!defined($path) || !defined($id)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__path($path);
    $self->__id($id);

    return $self;
}


sub __now
{
    my ($S, $M, $H, $d, $m, $y, @r) = localtime();

    $y += 1900;
    $m += 1;

    return sprintf("%04d-%02d-%02d-%02d-%02d-%02d", $y, $m, $d, $H, $M, $S);
}

sub _init
{
    my ($self) = @_;
    my $date = __now();
    my $fh;

    if (defined($self->_date()))          { return undef; }
    if (!mkdir($self->__path()))          { return undef; }
    if (!mkdir($self->__path_property())) { return undef; }
    if (!defined($self->_date($date)))    { return undef; }
    
    if (open($fh, '>', $self->__path() . '/version')) {
	printf($fh "1\n");
	close($fh);
    } else {
	return undef;
    }

    return 1;
}


sub __path_content
{
    my ($self) = @_;
    return $self->__path() . '/content';
}

sub __path_property
{
    my ($self) = @_;
    return $self->__path() . '/property';
}

sub __path_date
{
    my ($self) = @_;
    return $self->__path() . '/date';
}


sub _date
{
    my ($self, $value) = @_;
    my ($fh);

    if (defined($value)) {
	if (!open($fh, '>', $self->__path_date())) {
	    return undef;
	}
	
	printf($fh "%s\n", $value);
	close($fh);
	
	return $value;
    }

    if (!open($fh, '<', $self->__path_date())) {
	return undef;
    }

    $value = <$fh>;
    close($fh);
    
    chomp($value);
    return $value;
}


sub __set_properties
{
    my ($self, $path, %args) = @_;
    my $hash = md5_hex($path);
    my $ppath = $self->__path_property() . '/' . $hash;
    my ($key, $value, $fh);

    if (!open($fh, '>', $ppath)) { return undef; }

    foreach $key (keys(%args)) {
	$value = $args{$key};
	printf($fh "%s => %d:%s\n", $key, length($value), $value);
    }

    close($fh);
    return 1;
}

sub _set_file
{
    my ($self, $path, $content, %args) = @_;
    my ($key, $cpath, $fh);

    $cpath = $self->__path_content() . $path;

    if (-e $cpath)               { return undef; }
    if (!open($fh, '>', $cpath)) { return undef; }

    printf($fh "%s", $content);

    close($fh);

    if (!$self->__set_properties($path, %args)) {
	unlink($cpath);
	return undef;
    } else {
	return 1;
    }
}

sub _set_directory
{
    my ($self, $path, %args) = @_;
    my ($key, $cpath);

    $cpath = $self->__path_content()  . $path;

    if (-e $cpath)                { return undef; }
    if (!mkdir($cpath))           { return undef; }

    if (!$self->__set_properties($path, %args)) {
	rmdir($cpath);
	return undef;
    } else {
	return 1;
    }
}


sub _get_file
{
    my ($self, $path) = @_;
    my ($cpath, $fh, $content);

    $cpath = $self->__path_content() . $path;

    if (!open($fh, '<', $cpath)) { return undef; }

    local $/ = undef;
    $content = <$fh>;

    close($fh);
    return $content;
}

sub _get_directory
{
    my ($self, $path) = @_;
    my ($cpath, $dh, @entries);

    $cpath = $self->__path_content() . $path;

    if (!opendir($dh, $cpath)) { return undef; }
    @entries = grep { ! /^\.\.?$/ } readdir($dh);
    closedir($dh);
    
    return \@entries;
}

sub _get_properties_path
{
    my ($self, $ppath) = @_;
    my ($line, $key, $value, $length, $fh);
    my %properties;

    if (!open($fh, '<', $ppath)) {
	return undef;
    }
    
    while (defined($line = <$fh>)) {
	chomp($line);
	
	if (!($line =~ /^(\S+) => (.*)$/)) {
	    goto err;
	}

	($key, $value) = ($1, $2);

	if (!($value =~ /^(\d+):(.*)$/)) {
	    goto err;
	}

	($length, $value) = ($1, $2);

	while (length($value) < $length && defined($line = <$fh>)) {
	    chomp($line);
	    $value .= "\n" . $line;
	}

	if (!defined($line) || length($value) != $length) {
	    goto err;
	}

	$properties{$key} = $value;
    }

    close($fh);
    return \%properties;
  err:
    close($fh);
    return undef;
}

sub _get_properties
{
    my ($self, $path) = @_;
    my ($hash, $ppath);

    $hash = md5_hex($path);
    $ppath = $self->__path_property() . '/' . $hash;

    return $self->_get_properties_path($ppath);
}

sub _flush
{
    my ($self) = @_;

    # nothing to do

    return 1;
}


sub _checkup_content_file
{
    my ($self, $refcounts, $corrupted, $hashes, $path) = @_;
    my ($cpath, $fh, $hash);

    $hashes->{md5_hex($path)} = $path;

    $cpath = $self->__path_content() . $path;
    if ((-s $cpath) != 32) {
	$corrupted->{$path} = 1;
	return 0;
    }

    if (!open($fh, '<', $cpath)) {
	return throw(ESYS, $!, $cpath);
    } else {
	chomp($hash = <$fh>);
	close($fh);
    }

    if (!($hash =~ /^[0-9a-f]{32}$/)) {
	$corrupted->{$path} = 1;
	return 0;
    }

    $refcounts->{$hash} += 1;
    return 0;
}

sub _checkup_content_directory
{
    my ($self, $refcounts, $corrupted, $hashes, $path) = @_;
    my ($cpath, $dh, $entry, $epath, $sep, $qpath, $ret);

    $hashes->{md5_hex($path)} = $path;

    if ($path eq '/') {
	$sep = '';
    } else {
	$sep = '/';
    }

    $cpath = $self->__path_content() . $path;
    if (!opendir($dh, $cpath)) {
	return throw(ESYS, $!, $cpath);
    } else {
	$ret = 0;
	foreach $entry (grep { ! /^\.\.?$/ } readdir($dh)) {
	    $epath = $path . $sep . $entry;
	    $qpath =$self->__path_content() . $epath;
	    if (-f $qpath) {
		$ret = $self->_checkup_content_file($refcounts,
						    $corrupted,
						    $hashes, $epath);
	    } elsif (-d $qpath) {
		$ret = $self->_checkup_content_directory($refcounts,
							 $corrupted,
							 $hashes, $epath);
	    }

	    if (!defined($ret)) {
		last;
	    }
	}
	closedir($dh);
    }

    return $ret;
}


sub _checkup_property
{
    my ($self, $corrupted, $hashes, $entry, $cpath) = @_;
    my ($ppath, $ret);

    $ppath = $self->__path_property() . '/' . $entry;
    $ret = $self->_get_properties_path($ppath);

    if (!defined($ret)) {
	$corrupted->{$cpath} = 1;
    }

    return 0;
}

sub _checkup_properties
{
    my ($self, $corrupted, $hashes) = @_;
    my ($dh, $entry, $cpath);

    if (!opendir($dh, $self->__path_property())) {
	return throw(ESYS, $!, $self->__path_property());
    } else {
	foreach $entry (grep { ! /^\.\.?$/ } readdir($dh)) {
	    $cpath = $hashes->{$entry};
	    if (!defined($cpath)) {
		$corrupted->{$entry} = 1;
		next;
	    }

	    $self->_checkup_property($corrupted, $hashes, $entry, $cpath);

	    delete($hashes->{$entry});
	}
	closedir($dh);
    }

    return 0;
}

sub _checkup
{
    my ($self, $refcounts) = @_;
    my (%corrupted, %hashes, $entry);

    if (!defined($self->_checkup_content_directory($refcounts, \%corrupted,
		 \%hashes, '/'))) {
	return undef;
    }

    if (!defined($self->_checkup_properties(\%corrupted, \%hashes))) {
	return undef;
    }

    foreach $entry (values(%hashes)) {
	$corrupted{$entry} = 1;
    }

    return [ keys(%corrupted) ];
}

sub checkup
{
    my ($self, $refcounts, @err) = @_;
    my ($ref, $count);

    if (!defined($refcounts)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($refcounts) ne 'HASH') {
	return throw(EINVLD, $refcounts);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    foreach $ref (keys(%$refcounts)) {
	if (ref($ref) ne '') {
	    return throw(EINVLD, $refcounts);
	} elsif (!($ref =~ /^[0-9a-f]{32}$/)) {
	    return throw(EINVLD, $refcounts);
	}
    }

    foreach $count (values(%$refcounts)) {
	if (ref($count) ne '') {
	    return throw(EINVLD, $refcounts);
	} elsif (!($count =~ /^\d+$/)) {
	    return throw(EINVLD, $refcounts);
	}
    }

    return $self->_checkup($refcounts);
}


1;
__END__
