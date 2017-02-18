package Synctl::Snapshot;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);

use Synctl qw(:error);


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    return $self;
}


sub _init           { confess('abstract method'); }
sub _id             { confess('abstract method'); }
sub _date           { confess('abstract method'); }
sub _set_file       { confess('abstract method'); }
sub _set_directory  { confess('abstract method'); }
sub _get_file       { confess('abstract method'); }
sub _get_directory  { confess('abstract method'); }
sub _get_properties { confess('abstract method'); }
sub _flush          { confess('abstract method'); }


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
	    if (ref($value) ne '') {
		return undef;
	    }
	} else {
	    return undef;
	}
    }

    return 1;
}


sub init
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_init();
}

sub id
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_id();
}

sub date
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_date();
}

sub set_file
{
    my ($self, $path, $content, %args) = @_;

    if (!defined($path) || !defined($content)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (ref($content) ne '') {
	return throw(EINVLD, $content);
    } elsif (!defined($self->_wrap_properties(\%args))) {
	return throw(EINVLD, \%args);
    }

    if ($path eq '/') {
	return undef;
    } elsif (!$self->_check_path($path)) {
	return undef;
    }

    return $self->_set_file($path, $content, %args);
}

sub set_directory
{
    my ($self, $path, %args) = @_;

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (!defined($self->_wrap_properties(\%args))) {
	return throw(EINVLD, \%args);
    }

    if (!$self->_check_path($path)) {
	return undef;
    }

    return $self->_set_directory($path, %args);
}

sub get_file
{
    my ($self, $path, @err) = @_;

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!$self->_check_path($path)) {
	return undef;
    }

    return $self->_get_file($path);
}

sub get_directory
{
    my ($self, $path, @err) = @_;

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!$self->_check_path($path)) {
	return undef;
    }

    return $self->_get_directory($path);
}

sub get_properties
{
    my ($self, $path, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!$self->_check_path($path)) {
	return undef;
    }

    return $self->_get_properties($path);    
}

sub flush
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_flush();
}


1;
__END__
