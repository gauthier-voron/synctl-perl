package Synctl::FileSnapshot;

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

sub __pcache
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__pcache'} = $value;
    }

    return $self->{'__pcache'};
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
    $self->__pcache({});

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

    if (defined($self->_date()))          { return undef; }
    if (!mkdir($self->__path()))          { return undef; }
    if (!mkdir($self->__path_property())) { return undef; }
    if (!defined($self->_date($date)))    { return undef; }

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
    my $pcache = $self->__pcache();
    my $hash = md5_hex($path);
    my ($key, $value, $text);

    $text = '';
    foreach $key (keys(%args)) {
	$value = $args{$key};
	$text .= sprintf("%s => %d:%s\n", $key, length($value), $value);
    }

    $pcache->{$hash} = $text;
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

sub __parse_properties
{
    my ($self, $text) = @_;
    my ($line, $key, $value, $length, %properties);
    my $append = 0;

    foreach $line (split("\n", $text)) {
	if (defined($value) && length($value) < $length) {
	    $value .= "\n" . $line;
	} else {
	    if (!($line =~ /^(\S+) => (.*)$/)) {
		return undef;
	    }
	
	    ($key, $value) = ($1, $2);

	    if (!($value =~ /^(\d+):(.*)$/)) {
		return undef;
	    }

	    ($length, $value) = ($1, $2);
	}

	if (length($value) != $length) {
	    return undef;
	}

	$properties{$key} = $value;
	$value = undef;
    }

    return \%properties;
}

sub _get_properties
{
    my ($self, $path, @err) = @_;
    my $hash = md5_hex($path);
    my $pcache = $self->__pcache();
    my ($ppath, $text, $properties, $fh);

    if (!defined($text = $pcache->{$hash})) {
	$ppath = $self->__path_property() . '/' . $hash;

	if (!open($fh, '<', $ppath)) {
	    return undef;
	} else {
	    local $/ = undef;
	    $text = <$fh>;
	    close($fh);
	}
    }

    return $self->__parse_properties($text);
}

sub _flush
{
    my ($self) = @_;
    my $pcache = $self->__pcache();
    my $ppath = $self->__path_property() . '/';
    my ($hash, $text, $fh, $path, $ret, $rem);

    $ret = 1;
    $rem = {};

    foreach $hash (keys(%$pcache)) {
	$text = $pcache->{$hash};

	$path = $ppath . $hash;
	if (!open($fh, '>', $path)) {
	    $ret = 0;
	    $rem->{$hash} = $text;
	    next;
	}

	printf($fh "%s", $text);
	close($fh);
    }

    $self->__pcache($rem);

    return $ret;
}


1;
__END__
