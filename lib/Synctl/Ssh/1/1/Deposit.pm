package Synctl::Ssh::1::1::Deposit;

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
    return $connection->call('deposit_init');
}

sub _size
{
    my ($self) = @_;
    my ($connection);

    $connection = $self->__connection();
    return $connection->call('deposit_size');
}

sub _hash
{
    my ($self, $handler) = @_;
    my $connection = $self->__connection();
    my ($callback, $calltag, $ret);

    $callback = sub {
	my ($stag, $rtag, $type, $data) = @_;
	
	if ($type eq 'data') {
	    $handler->($data);
	    return 1;
	} elsif ($type eq 'stop') {
	    $ret = $data;
	    return 0;
	}
    };

    $calltag = $connection->talk('deposit_hash', $callback);
    while ($connection->wait($calltag))
        {}

    return $ret;
}

sub _get
{
    my ($self, $hash) = @_;
    my $connection;

    $connection = $self->__connection();
    my $ret = $connection->call('deposit_get', $hash);
    return $ret;
}

sub _put
{
    my ($self, $hash) = @_;
    my $connection;

    $connection = $self->__connection();
    return $connection->call('deposit_put', $hash);
}

sub _send
{
    my ($self, $provider) = @_;
    my $connection = $self->__connection();
    my ($callback, $calltag, $data, $ret);

    $callback = sub {
	my ($stag, $rtag, $type, $hash) = @_;

	if ($type eq 'accept') {
	    while (defined($data = $provider->())) {
		$connection->send($rtag, undef, 'data', $data);
	    }
	
	    $connection->send($rtag, undef, 'stop', undef);
	    return 1;
	} elsif ($type eq 'hash') {
	    $ret = $hash;
	    return 0;
	}
    };

    $calltag = $connection->talk('deposit_send', $callback);
    $connection->wait($calltag);  # transfert
    $connection->wait($calltag);  # get hash

    return $ret;
}

sub _recv
{
    my ($self, $hash, $handler) = @_;
    my $connection = $self->__connection();
    my ($callback, $calltag, $ret);

    $callback = sub {
	my ($stag, $rtag, $type, $data) = @_;
	
	if ($type eq 'data') {
	    $handler->($data);
	    return 1;
	} elsif ($type eq 'stop') {
	    $ret = $data;
	    return 0;
	}
    };

    $calltag = $connection->talk('deposit_recv', $callback, $hash);
    while ($connection->wait($calltag))
        {}

    return $ret;
}


1;
__END__
