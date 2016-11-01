package Synctl::SshDeposit;

use parent qw(Synctl::Deposit);
use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);

use Synctl qw(:verbose);


sub __connection {
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__connection'} = $value;
    }
    
    return $self->{'__connection'};
}


sub _new
{
    my ($self, $connection, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    if (!defined($connection)) { confess('missing argument'); }
    if (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__connection($connection);
    return $self;
}


sub _init
{
    my ($self) = @_;
    my $connection;

    $connection = $self->__connection();
    $connection->send('deposit_init');
    return $connection->recv();
}

sub _size
{
    my ($self) = @_;
    my ($connection);

    $connection = $self->__connection();
    $connection->send('deposit_size');

    return $connection->recv();
}

sub _hash
{
    my ($self, $handler) = @_;
    my ($connection, $type, $data);

    $connection = $self->__connection();
    $connection->send('deposit_hash');
    
    do {
	($type, $data) = $connection->recv();
	if ($type eq 'output') {
	    $handler->($data);
	}
    } while ($type ne 'ret');
    
    return $data;
}

sub _get
{
    my ($self, $hash) = @_;
    my $connection;

    $connection = $self->__connection();
    $connection->send('deposit_get', $hash);
    return $connection->recv();
}

sub _put
{
    my ($self, $hash) = @_;
    my $connection;

    $connection = $self->__connection();
    $connection->send('deposit_put', $hash);
    return $connection->recv();
}

sub _send
{
    my ($self, $provider) = @_;
    my ($connection, $data);

    $connection = $self->__connection();
    $connection->send('deposit_send');

    while (defined($data = $provider->())) {
	$connection->send($data);
    }
    $connection->send(undef);

    $data = $connection->recv();
    return $data;
}

sub _recv
{
    my ($self, $hash, $handler) = @_;
    my ($connection, $type, $data);

    $connection = $self->__connection();
    $connection->send('deposit_recv', $hash);
    
    do {
	($type, $data) = $connection->recv();
	if ($type eq 'output') {
	    $handler->($data);
	}
    } while ($type ne 'ret');
    
    return $data;
}


1;
__END__
