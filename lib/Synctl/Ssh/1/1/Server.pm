package Synctl::Ssh::1::1::Server;

use parent qw(Synctl::SshServer);
use strict;
use warnings;

use constant {
    HBUFFER => 256
};

use Scalar::Util qw(blessed);

use Synctl qw(:error);
use Synctl::Ssh::1::1::Connection;


sub __connection
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__connection'} = $value;
    }

    return $self->{'__connection'};
}

sub __controler
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__controler'} = $value;
    }

    return $self->{'__controler'};
}

sub __running
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__running'} = $value;
    }

    return $self->{'__running'};
}


sub _new
{
    my ($self, $in, $out, $controler, @err) = @_;
    my $connection;

    if (!defined($in) || !defined($out) || !defined($controler)) {
	return throw(ESYNTAX, undef);
    } elsif (!(blessed($controler) && $controler->isa('Synctl::Controler'))) {
	return throw(EINVLD, $controler);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $connection = Synctl::Ssh::1::1::Connection->new($in, $out);
    if (!defined($connection)) {
	return undef;
    }

    $self->__connection($connection);
    $self->__controler($controler);
    $self->__running(0);

    return $self;
}


sub __deposit_init
{
    my ($self, $rtag) = @_;
    my $deposit = $self->__controler()->deposit();
    my $ret;

    $ret = $deposit->init();
    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __deposit_size
{
    my ($self, $rtag) = @_;
    my $deposit = $self->__controler()->deposit();
    my $ret;

    $ret = $deposit->size();
    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __deposit_hash
{
    my ($self, $rtag) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my (@buffer, $size, $ret);

    $size = 0;
    $ret = $deposit->hash(sub {
	push(@buffer, shift(@_));
	$size = $size + 1;

	if ($size == HBUFFER) {
	    $connection->send($rtag, undef, 'data', @buffer);
	    @buffer = ();
	    $size = 0;
	}
    });

    if ($size > 0) {
	$connection->send($rtag, undef, 'data', @buffer);
    }

    $connection->send($rtag, undef, 'stop', $ret);
}

sub __deposit_get
{
    my ($self, $rtag, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $ret;

    $ret = $deposit->get($hash);
    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __deposit_put
{
    my ($self, $rtag, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $ret;

    $ret = $deposit->put($hash);
    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __deposit_send
{
    my ($self, $rtag) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my ($callback, $calltag, $buffer, $ret);

    $callback = sub {
	my ($stag, $rrtag, $type, $data) = @_;

	if ($type eq 'data') {
	    $buffer = $data;
	    return 1;
	} elsif ($type eq 'stop') {
	    $buffer = undef;
	    return 0;
	}
    };

    $calltag = $connection->talk($rtag, $callback, 'accept');

    $ret = $deposit->send(sub {
	$connection->wait($calltag);
	return $buffer;
    });

    $connection->send($rtag, undef, 'hash', $ret);
}

sub __deposit_recv
{
    my ($self, $rtag, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my $ret;

    $ret = $deposit->recv($hash, sub {
	$connection->send($rtag, undef, 'data', shift(@_));
    });

    $connection->send($rtag, undef, 'stop', $ret);
}

sub __deposit_flush
{
    my ($self, $rtag, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my $ret;

    $ret = $deposit->flush();

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}


sub __get_snapshot
{
    my ($self, $id) = @_;
    my @snapshots = $self->__controler()->snapshot();

    @snapshots = grep { $_->id() eq $id } @snapshots;

    if (scalar(@snapshots) == 0) {
	return undef;
    } else {
	return shift(@snapshots);
    }
}

sub __snapshot_date
{
    my ($self, $rtag, $id) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->date();
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}

sub __snapshot_sane
{
    my ($self, $rtag, $id, $value) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->sane($value);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}

sub __snapshot_set_file
{
    my ($self, $rtag, $id, $path, $content, %args) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->set_file($path, $content, %args);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __snapshot_set_directory
{
    my ($self, $rtag, $id, $path, %args) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->set_directory($path, %args);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}

sub __snapshot_set_buffer
{
    my ($self, $rtag, $id, $buffer) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my ($entry, $type, @args);

    if (!defined($snapshot)) {
	return undef;
    }

    foreach $entry (@$buffer) {
	($type, @args) = @$entry;
	if ($type eq 'f') {
	    $snapshot->set_file(@args);
	} elsif ($type eq 'd') {
	    $snapshot->set_directory(@args);
	}
    }
}

sub __snapshot_get_file
{
    my ($self, $rtag, $id, $path) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->get_file($path);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}

sub __snapshot_get_directory
{
    my ($self, $rtag, $id, $path) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->get_directory($path);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}

sub __snapshot_get_properties
{
    my ($self, $rtag, $id, $path) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->get_properties($path);
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}

sub __snapshot_flush
{
    my ($self, $rtag, $id) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $connection = $self->__connection();
    my $ret;

    if (defined($snapshot)) {
	$ret = $snapshot->flush();
    } else {
	$ret = undef;
    }

    if (defined($rtag)) {
	$connection->send($rtag, undef, $ret);
    }
}


sub __snapshot
{
    my ($self, $rtag) = @_;
    my $controler = $self->__controler();
    my $connection = $self->__connection();
    my @ids = map { $_->id() } $controler->snapshot();

    if (defined($rtag)) {
	$connection->send($rtag, undef, @ids);
    }
}

sub __create
{
    my ($self, $rtag) = @_;
    my $controler = $self->__controler();
    my $snapshot = $controler->create();

    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $snapshot->id());
    }
}

sub __delete
{
    my ($self, $rtag, $id) = @_;
    my $snapshot = $self->__get_snapshot($id);
    my $controler = $self->__controler();
    my $ret;

    if (defined($snapshot)) {
	$ret = $controler->delete($snapshot);
    } else {
	$ret = undef;
    }
    
    if (defined($rtag)) {
	$self->__connection()->send($rtag, undef, $ret);
    }
}


sub __exit
{
    my ($self, $rtag) = @_;
    $self->__running(0);
}


sub __hook
{
    my ($self, $tag, $handler) = @_;
    my $connection = $self->__connection();

    $connection->recv($tag, sub {
	my ($stag, $rtag, @args) = @_;

	$self->$handler($rtag, @args);
	return 1;
    });
}


sub _report
{
    my ($self, $code, @hints) = @_;
    my $connection = $self->__connection();

    $connection->send('report', undef, $code, @hints);
}

sub _notify
{
    my ($self, $code, @hints) = @_;
    my $connection = $self->__connection();

    $connection->send('notify', undef, $code, @hints);
}

sub _serve
{
    my ($self) = @_;
    my $connection = $self->__connection();

    $self->__hook('deposit_init',            \&__deposit_init);
    $self->__hook('deposit_size',            \&__deposit_size);
    $self->__hook('deposit_hash',            \&__deposit_hash);
    $self->__hook('deposit_get',             \&__deposit_get);
    $self->__hook('deposit_put',             \&__deposit_put);
    $self->__hook('deposit_send',            \&__deposit_send);
    $self->__hook('deposit_recv',            \&__deposit_recv);
    $self->__hook('deposit_flush',           \&__deposit_flush);

    $self->__hook('snapshot_date',           \&__snapshot_date);
    $self->__hook('snapshot_sane',           \&__snapshot_sane);
    $self->__hook('snapshot_set_file',       \&__snapshot_set_file);
    $self->__hook('snapshot_set_buffer',     \&__snapshot_set_buffer);
    $self->__hook('snapshot_set_directory',  \&__snapshot_set_directory);
    $self->__hook('snapshot_get_file',       \&__snapshot_get_file);
    $self->__hook('snapshot_get_directory',  \&__snapshot_get_directory);
    $self->__hook('snapshot_get_properties', \&__snapshot_get_properties);
    $self->__hook('snapshot_flush',          \&__snapshot_flush);

    $self->__hook('snapshot',                \&__snapshot);
    $self->__hook('create',                  \&__create);
    $self->__hook('delete',                  \&__delete);

    $self->__hook('exit',                    \&__exit);

    $self->__running(1);
    while ($self->__running()) {
	if ($connection->wait('exit') == 0) {
	    return 0;
	}
    }

    return 0;
}


1;
__END__
