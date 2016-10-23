package Synctl::SshControler;

use parent qw(Synctl::Controler);
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error);
use Synctl::SshDeposit;
use Synctl::SshSnapshot;


sub __connection
{
    my ($self, $connection) = @_;

    if (defined($connection)) {
	$self->{'__connection'} = $connection;
    }

    return $self->{'__connection'};
}


sub _init
{
    my ($self, $connection, @err) = @_;
    my $ack;

    if (!defined($connection)) {
	return throw(ESYNTAX, undef);
    } if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!blessed($connection)||!$connection->isa('Synctl::SshProtocol')) {
	return throw(EINVLD, $connection);
    } elsif (!defined($self->SUPER::_init())) {
	return undef;
    }

    if (!$connection->send('syn')) {
	return throw(EPROT, 'syn');
    } 

    $ack = $connection->recv();
    if (!defined($ack) || $ack ne 'ack') {
	return throw(EPROT, 'ack');
    }

    $self->__connection($connection);

    return $self;
}


sub deposit
{
    my ($self, @err) = @_;
    my $connection;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    return Synctl::SshDeposit->new($connection);
}

sub snapshot
{
    my ($self, @err) = @_;
    my ($connection, @ret);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    $connection->send('snapshot');
    @ret = $connection->recv();

    return map { Synctl::SshSnapshot->new($connection, $_); } @ret;
}

sub create
{
    my ($self, @err) = @_;
    my ($connection, $ret);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    $connection->send('create');

    return Synctl::SshSnapshot->new($connection, $connection->recv());
}

sub delete
{
    my ($self, $date, @err) = @_;
    my ($connection, $ret);

    if (!defined($date)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (ref($date) ne '') {
	return throw(EINVLD, $date);
    }

    $connection = $self->__connection();
    $ret = $connection->send('delete', $date);

    return $ret;
}


1;
__END__
