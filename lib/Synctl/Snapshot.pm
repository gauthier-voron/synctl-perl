package Synctl::Snapshot;

use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);


sub _new
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self;
}

sub new
{
    my ($class, @args) = @_;
    my $self;

    $self = bless({}, $class);
    $self = $self->_new(@args);
    
    return $self;
}


sub _init           { confess('abstract method'); }
sub _date           { confess('abstract method'); }
sub _set_file       { confess('abstract method'); }
sub _set_directory  { confess('abstract method'); }
sub _get_file       { confess('abstract method'); }
sub _get_directory  { confess('abstract method'); }
sub _get_properties { confess('abstract method'); }


sub _check_path
{
    my ($self, $path) = @_;

    if (!($path =~ m|^/|))              { return 0; }
    if ($path =~ m|^/.*/$|)             { return 0; }
    if ($path =~ m|//|)                 { return 0; }
    if ($path =~ m|^(.*/)?\.(/.*)?$|)   { return 0; }
    if ($path =~ m|^(.*/)?\.\.(/.*)?$|) { return 0; }

    return 1;
}

sub _wrap_properties
{
    my ($self, $args) = @_;
    my ($key, $value);

    foreach $key (keys(%$args)) {
	if (grep { $key eq $_ } qw(MODE USER GROUP MTIME INODE SIZE)) {
	    $value = $args->{$key};
	    if (ref($value) ne '') { return undef; }
	} else {
	    return undef;
	}
    }

    return 1;
}


sub init
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->_init();
}

sub date
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->_date();
}

sub set_file
{
    my ($self, $path, $content, %args) = @_;

    if (!defined($path) || ref($path) ne '') { confess('invalid argument'); }
    if (!defined($content) || ref($content) ne '') { 
	confess('invalid argument');
    }
    if (!defined($self->_wrap_properties(\%args))) {
	confess('invalid argument');
    }

    if ($path eq '/')               { return undef; }
    if (!$self->_check_path($path)) { return undef; }

    return $self->_set_file($path, $content, %args);
}

sub set_directory
{
    my ($self, $path, %args) = @_;

    if (!defined($path) || ref($path) ne '') { confess('invalid argument'); }
    if (!defined($self->_wrap_properties(\%args))) {
	confess('invalid argument');
    }

    if (!$self->_check_path($path)) { return undef; }

    return $self->_set_directory($path, %args);
}

sub get_file
{
    my ($self, $path, @err) = @_;

    if (!defined($path) || ref($path) ne '') { confess('invalid argument'); }
    if (@err) { confess('unexpected argument'); }

    if (!$self->_check_path($path)) { return undef; }

    return $self->_get_file($path);
}

sub get_directory
{
    my ($self, $path, @err) = @_;

    if (!defined($path) || ref($path) ne '') { confess('invalid argument'); }
    if (@err) { confess('unexpected argument'); }

    if (!$self->_check_path($path)) { return undef; }

    return $self->_get_directory($path);
}

sub get_properties
{
    my ($self, $path, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    if (!$self->_check_path($path)) { return undef; }

    return $self->_get_properties($path);    
}


1;
__END__
