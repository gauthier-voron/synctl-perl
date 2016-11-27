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

sub __cache
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__cache'} = $value;
    }

    return $self->{'__cache'};
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
    $self->__cache({});

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
    my ($callback, $calltag, $ret, $cache);

    $cache = $self->__cache();

    $callback = sub {
	my ($stag, $rtag, $type, $data) = @_;
	
	if ($type eq 'data') {
	    $handler->($data);
	    $cache->{$data} = 1;
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
    my ($connection, $cache, $value, $remote);

    $connection = $self->__connection();
    $cache = $self->__cache();

    if (!defined($value = $cache->{$hash}) || $value == 0) {
	$value = $connection->call('deposit_get', $hash);
	$remote = 1;

	if (defined($value)) {
	    $value = 1;
	} else {
	    $value = -1;
	}

	$cache->{$hash} = $value;
    }

    if ($value < 0) {
	return undef;
    } elsif (!$remote) {
	$connection->send('deposit_get', undef, $hash);
    }

    $cache->{$hash} = $value + 1;
    return 1;
}

sub _put
{
    my ($self, $hash) = @_;
    my ($connection, $cache, $value, $remote);

    $connection = $self->__connection();
    $cache = $self->__cache();

    if (!defined($value = $cache->{$hash}) || $value == 0 || $value == 1) {
	$value = $connection->call('deposit_put', $hash);
	$remote = 1;

	if (!defined($value)) {
	    $value = -1;
	} elsif ($value == 0) {
	    $value = 0;
	} else {
	    $value = 2;
	}

	$cache->{$hash} = $value;
    }

    if ($value < 0) {
	return undef;
    } elsif (!$remote) {
	$connection->send('deposit_put', undef, $hash);
    }

    $value = $value - 1;
    $cache->{$hash} = $value;

    if ($value < 0) {
	return 0;
    } else {
	return 1;
    }
}

sub _send
{
    my ($self, $provider) = @_;
    my $connection = $self->__connection();
    my $cache = $self->__cache();
    my ($callback, $calltag, $data, $value, $ret);

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

    if (defined($value = $cache->{$ret})) {
	if ($value < 0) {
	    $value = 1;
	} else {
	    $value = $value + 1;
	}
    } else {
	$value = 1;
    }

    $cache->{$ret} = $value;

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

sub _flush
{
    my ($self) = @_;
    my $connection = $self->__connection();

    return $connection->call('deposit_flush');
}


1;
__END__
