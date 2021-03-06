package Synctl::File::1::Snapshot;

use parent qw(Synctl::Snapshot);
use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);


sub __path
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__path'} = $value;
    }
    
    return $self->{'__path'};
}

sub __id
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__id'} = $value;
    }

    return $self->{'__id'};
}


sub _new
{
    my ($self, $path, $id, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    if (!defined($path) || ref($path) ne '') { confess('invalid argument'); }
    if (!defined($id) || ref($id) ne '') { confess('invalid argument'); }
    if (!defined($self->SUPER::_new())) { return undef; }

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

sub path
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->__path();
}


sub _id
{
    my ($self) = @_;
    return $self->__id();
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

sub _get_properties
{
    my ($self, $path, @err) = @_;
    my $hash = md5_hex($path);
    my $ppath = $self->__path_property() . '/' . $hash;
    my ($line, $key, $value, $length, $fh);
    my %properties;

    if (!open($fh, '<', $ppath)) { return undef; }
    
    while (defined($line = <$fh>)) {
	chomp($line);
	
	if (!($line =~ /^(\S+) => (.*)$/)) { goto err; }
	($key, $value) = ($1, $2);

	if (!($value =~ /^(\d+):(.*)$/)) { close($fh); goto err; }
	($length, $value) = ($1, $2);

	while (length($value) < $length && defined($line = <$fh>)) {
	    chomp($line);
	    $value .= "\n" . $line;
	}

	if (!defined($line) || length($value) != $length) { goto err; }

	$properties{$key} = $value;
    }

    close($fh);
    return \%properties;
  err:
    close($fh);
    return undef;
}

sub _flush
{
    my ($self) = @_;

    # nothing to do

    return 1;
}


1;
__END__
