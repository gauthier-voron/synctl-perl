package Synctl::SshServer;

use strict;
use warnings;

use Carp;


sub __connection
{
    my ($self, $connection) = @_;

    if (defined($connection)) {
	$self->{'__connection'} = $connection;
    }

    return $self->{'__connection'};
}

sub __controler
{
    my ($self, $controler) = @_;

    if (defined($controler)) {
	$self->{'__controler'} = $controler;
    }

    return $self->{'__controler'};
}


sub new
{
    my ($class, $connection, $controler, @err) = @_;
    my $self;

    if (@err) { confess('unexpected argument'); }
    if (!defined($connection)) { confess('missing argument'); }
    if (!defined($controler)) { confess('missing argument'); }

    $self = bless({}, $class);
    $self->__connection($connection);
    $self->__controler($controler);

    return $self;
}


sub __deposit_init
{
    my ($self) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();

    $connection->send($deposit->init());
}

sub __deposit_hash
{
    my ($self) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my $ret;

    $ret = $deposit->hash(sub { $connection->send('output', shift(@_)); });
    $connection->send('ret', $ret);
}

sub __deposit_get
{
    my ($self, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();

    $connection->send($deposit->get($hash));
}

sub __deposit_put
{
    my ($self, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();

    $connection->send($deposit->put($hash));
}

sub __deposit_send
{
    my ($self) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my ($ret, $data);

    $ret = $deposit->send(sub { return $connection->recv() });
    $connection->send($ret);
}

sub __deposit_recv
{
    my ($self, $hash) = @_;
    my $deposit = $self->__controler()->deposit();
    my $connection = $self->__connection();
    my $ret;

    $ret = $deposit->recv($hash, sub {$connection->send('output', shift(@_))});
    $connection->send('ret', $ret);
}


sub __get_snapshot
{
    my ($self, $date) = @_;
    my @snapshots = $self->__controler()->snapshot();

    @snapshots = grep { $_->date() eq $date } @snapshots;

    if (scalar(@snapshots) == 0) { return undef; }
    return shift(@snapshots);
}

sub __snapshot_set_file
{
    my ($self, $date, $path, $content, %args) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $connection = $self->__connection();
    my $ret;

    if (!defined($snapshot)) {
	$connection->send(undef);
    } else {
	$connection->send($snapshot->set_file($path, $content, %args));
    }
}

sub __snapshot_set_directory
{
    my ($self, $date, $path, %args) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $connection = $self->__connection();
    my $ret;

    if (!defined($snapshot)) {
	$connection->send(undef);
    } else {
	$connection->send($snapshot->set_directory($path, %args));
    }
}

sub __snapshot_get_file
{
    my ($self, $date, $path) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $connection = $self->__connection();
    my $ret;

    if (!defined($snapshot)) {
	$connection->send(undef);
    } else {
	$connection->send($snapshot->get_file($path));
    }
}

sub __snapshot_get_directory
{
    my ($self, $date, $path) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $connection = $self->__connection();
    my $ret;

    if (!defined($snapshot)) {
	$connection->send(undef);
    } else {
	$connection->send($snapshot->get_directory($path));
    }
}

sub __snapshot_get_properties
{
    my ($self, $date, $path) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $connection = $self->__connection();
    my $ret;

    if (!defined($snapshot)) {
	$connection->send(undef);
    } else {
	$connection->send($snapshot->get_properties($path));
    }
}


sub __snapshot
{
    my ($self) = @_;
    my $controler = $self->__controler();
    my $connection = $self->__connection();
    my @dates = map { $_->date() } $controler->snapshot();

    $connection->send(@dates);
}

sub __create
{
    my ($self) = @_;
    my $controler = $self->__controler();
    my $connection = $self->__connection();
    my $snapshot = $controler->create();

    $connection->send($snapshot->date());
}

sub __delete
{
    my ($self, $date) = @_;
    my $snapshot = $self->__get_snapshot($date);
    my $controler = $self->__controler();
    my $connection = $self->__connection();

    $connection->send($controler->delete($snapshot));
}


sub serve
{
    my ($self, @err) = @_;
    my $connection = $self->__connection();
    my ($running, @args, $handler);
    my %handlers = (
	'deposit_init'            => \&__deposit_init,
	'deposit_hash'            => \&__deposit_hash,
	'deposit_get'             => \&__deposit_get,
	'deposit_put'             => \&__deposit_put,
	'deposit_send'            => \&__deposit_send,
	'deposit_recv'            => \&__deposit_recv,
	'snapshot_set_file'       => \&__snapshot_set_file,
	'snapshot_set_directory'  => \&__snapshot_set_directory,
	'snapshot_get_file'       => \&__snapshot_get_file,
	'snapshot_get_directory'  => \&__snapshot_get_directory,
	'snapshot_get_properties' => \&__snapshot_get_properties,
	'snapshot'                => \&__snapshot,
	'create'                  => \&__create,
	'delete'                  => \&__delete,
	'syn'                     => sub {$self->__connection()->send('ack')},
	'exit'                    => sub { $running = 0 }
	);

    if (@err) { confess('unexpected argument'); }

    $running = 1;
    while ($running) {
	@args = $connection->recv();
	last if (!@args);
	last if (!defined($handler = shift(@args)));
	last if (!defined($handler = $handlers{$handler}));
	$handler->($self, @args);
    }

    return 1;
}


1;
__END__
