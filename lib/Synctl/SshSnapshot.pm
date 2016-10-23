package Synctl::SshSnapshot;

use parent qw(Synctl::Snapshot);
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error);


sub __connection
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__connection'} = $value;
    }
    
    return $self->{'__connection'};
}

sub __date
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__date'} = $value;
    }
    
    return $self->{'__date'};
}


sub _new
{
    my ($self, $connection, $date, @err) = @_;

    if (!defined($connection) || !defined($date)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!blessed($connection)||!$connection->isa('Synctl::SshProtocol')) {
	return throw(EINVLD, $connection);
    } elsif (ref($date) ne '') {
	return throw(EINVLD, $date);
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__connection($connection);
    $self->__date($date);
    return $self;
}


sub _init
{
    return undef;
}

sub _date
{
    my ($self) = @_;
    return $self->__date();
}

sub _set_file
{
    my ($self, $path, $content, %args) = @_;
    my $connection = $self->__connection();
    my $date = $self->__date();

    $connection->send('snapshot_set_file', $date, $path, $content, %args);
    return $connection->recv();
}

sub _set_directory
{
    my ($self, $path, %args) = @_;
    my $connection = $self->__connection();
    my $date = $self->__date();

    $connection->send('snapshot_set_directory', $date, $path, %args);
    return $connection->recv();
}

sub _get_file
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $date = $self->__date();

    $connection->send('snapshot_get_file', $date, $path);
    return $connection->recv();
}

sub _get_directory
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $date = $self->__date();

    $connection->send('snapshot_get_directory', $date, $path);
    return $connection->recv();
}

sub _get_properties
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $date = $self->__date();

    $connection->send('snapshot_get_properties', $date, $path);
    return $connection->recv();
}


1;
__END__
