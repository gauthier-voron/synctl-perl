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
    my ($self, $connection, $id, @err) = @_;

    if (!defined($connection) || !defined($id)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!blessed($connection)||!$connection->isa('Synctl::SshProtocol')) {
	return throw(EINVLD, $connection);
    } elsif (ref($id) ne '') {
	return throw(EINVLD, $id);
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__connection($connection);
    $self->__id($id);
    return $self;
}


sub _init
{
    return undef;
}

sub _id
{
    my ($self) = @_;
    return $self->__id();
}

sub _date
{
    my ($self) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_date', $id);
    return $connection->recv();
}

sub _set_file
{
    my ($self, $path, $content, %args) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_set_file', $id, $path, $content, %args);
    return $connection->recv();
}

sub _set_directory
{
    my ($self, $path, %args) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_set_directory', $id, $path, %args);
    return $connection->recv();
}

sub _get_file
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_get_file', $id, $path);
    return $connection->recv();
}

sub _get_directory
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_get_directory', $id, $path);
    return $connection->recv();
}

sub _get_properties
{
    my ($self, $path) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    $connection->send('snapshot_get_properties', $id, $path);
    return $connection->recv();
}


1;
__END__
