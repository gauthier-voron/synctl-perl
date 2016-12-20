package Synctl::Ssh::1::1::Controler;

use parent qw(Synctl::Controler);
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error);
use Synctl::Ssh::1::1::Connection;
use Synctl::Ssh::1::1::Deposit;
use Synctl::Ssh::1::1::Snapshot;


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
    my ($self, $in, $out, @err) = @_;
    my ($connection);

    if (!defined($in) || !defined($out)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_init())) {
	return undef;
    }

    $connection = Synctl::Ssh::1::1::Connection->new($in, $out);
    if (!defined($connection)) {
	return undef;
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
    return Synctl::Ssh::1::1::Deposit->new($connection);
}

sub snapshot
{
    my ($self, @err) = @_;
    my ($connection, @ids);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    @ids = $connection->call('snapshot');

    return map { Synctl::Ssh::1::1::Snapshot->new($connection, $_); } @ids;
}

sub create
{
    my ($self, @err) = @_;
    my ($connection, $id, $snapshot);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    $id = $connection->call('create');

    $snapshot = Synctl::Ssh::1::1::Snapshot->new($connection, $id);
    $snapshot->load();

    return $snapshot;
}

sub delete
{
    my ($self, $snapshot, @err) = @_;
    my ($connection, $ret);

    if (!defined($snapshot)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($snapshot) || !$snapshot->isa('Synctl::Snapshot')) {
	return throw(EINVLD, $snapshot);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $connection = $self->__connection();
    return $connection->call('delete', $snapshot->id());
}


1;
__END__
