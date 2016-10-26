package Synctl::Seeker;

use strict;
use warnings;

use Carp;
use Synctl qw(:error :verbose);


sub __path
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__path'} = $value;
    }

    return $self->{'__path'};
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
    my ($class, $path, @err) = @_;
    my $self;

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self = bless({}, $class);
    $self->__path($path);
    $self->__filter(sub { return 1 });

    return $self;
}


sub path
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__path();
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


sub __normalize_output
{
    my ($output) = @_;
    my $code;

    if (ref($output) eq 'ARRAY') {
	@$output = ();
        $code = sub { push(@$output, { @_ }) };
    } elsif (ref($output) eq 'CODE') {
        $code = $output;
    } else {
	return throw(EINVLD, $output);
    }

    return $code;
}


sub __seek_link
{
    my ($self, $path, $ohandler, $ehandler) = @_;
    my ($dev, $inode, $mode, $user, $group, $mtime);
    my $lpath = $self->__path() . $path;

    ($dev, $inode, $mode, $user, $group, $mtime) =
	(lstat($lpath))[0, 1, 2, 4, 5, 9];

    $ohandler->(NAME => $path, PATH => $lpath, MODE => $mode, USER => $user,
		GROUP => $group, MTIME => $mtime, INODE => $dev .':'. $inode);
    return 1;
}

sub __seek_file
{
    my ($self, $path, $ohandler, $ehandler) = @_;
    my ($dev, $inode, $mode, $user, $group, $mtime);
    my $fpath = $self->__path() . $path;

    ($dev, $inode, $mode, $user, $group, $mtime) =
	(stat($fpath))[0, 1, 2, 4, 5, 9];

    $ohandler->(NAME => $path, PATH => $fpath, MODE => $mode, USER => $user,
		GROUP => $group, MTIME => $mtime, INODE => $dev .':'. $inode);
    return 1;
}

sub __seek_directory
{
    my ($self, $path, $ohandler, $ehandler) = @_;
    my ($dev, $inode, $mode, $user, $group, $mtime);
    my ($dpath, $dh, $entry, $sep, %output);
    my $count = 0;

    $dpath = $self->path() . $path;
    
    if ($path eq '/') {
	$sep = '';
    } else {
	$sep = '/';
    }

    ($dev, $inode, $mode, $user, $group, $mtime) =
	(stat($dpath))[0, 1, 2, 4, 5, 9];

    %output = (NAME => $path, PATH => $dpath, MODE => $mode, USER => $user,
	       GROUP => $group, MTIME => $mtime, INODE => $dev .':'. $inode);

    if (!opendir($dh, $dpath)) {
	$ehandler->(%output);
	return $count;
    }

    $ohandler->(%output);
    $count++;

    foreach $entry (grep { ! /^\.\.?$/ } readdir($dh)) {
	$count += $self->__seek($path . $sep . $entry, $ohandler, $ehandler);
    }

    closedir($dh);
    return $count;
}

sub __seek
{
    my ($self, $path, $ohand, $ehand) = @_;
    my $rpath = $self->__path() . $path;

    notify(DEBUG, IFCHECK, $path);

    if (!$self->__filter()->($path)) { return 0; }

    if (-l $rpath) { return $self->__seek_link($path, $ohand, $ehand); }
    if (-f $rpath) { return $self->__seek_file($path, $ohand, $ehand); }
    if (-d $rpath) { return $self->__seek_directory($path, $ohand, $ehand); }

    $ehand->($path);
    return 0;
}

sub seek
{
    my ($self, $output, $error, @err) = @_;
    my ($ohandler, $ehandler);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($ohandler = __normalize_output($output))) {
	return undef;
    }

    if (defined($error)) {
	if (!defined($ehandler = __normalize_output($error))) {
	    return undef;
	}
    } else {
	$ehandler = sub {};
    }

    return $self->__seek('/', $ohandler, $ehandler);
}


1;
__END__
