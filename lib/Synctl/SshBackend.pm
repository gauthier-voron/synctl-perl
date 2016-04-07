package Synctl::SshBackend;

use parent qw(Synctl::Backend);
use strict;
use warnings;

use Carp;


sub _user    { shift()->_rw('_user',    @_); }
sub _port    { shift()->_rw('_port',    @_); }
sub _address { shift()->_rw('_address', @_); }
sub _path    { shift()->_rw('_path',    @_); }
sub _control { shift()->_rw('_control', @_); }
sub _ctrlpid { shift()->_rw('_ctrlpid', @_); }


sub _open
{
    my ($self) = @_;
    my ($control, $ctrlpid, $user, $uaddr);
    my @command = ('ssh', '-N', '-o', 'ControlMaster=yes');

    $ctrlpid = $self->_ctrlpid();
    if (defined($ctrlpid) && kill(0, $ctrlpid)) {
	return 1;
    }

    $control = '/tmp/synctl-' . $$ . '-ssh-';

    $user = $self->_user();
    $uaddr = $self->_address();
    if (defined($user)) { $uaddr = $user . '@' . $uaddr; }
    push(@command, $uaddr);

    $ctrlpid = fork();
    if ($ctrlpid == 0) {
	$control .= $$ . '.sock';
	push(@command, '-o', 'ControlPath=' . $control);
	exec (@command);
	exit (1);
    } else {
	$control .= $ctrlpid . '.sock';
	push(@command, '-o', 'ControlPath=' . $control);
    }

    while (!(-e $control) && kill(0, $ctrlpid)) {
	sleep(1);
    }

    if (-e $control) {
	$self->_control($control);
	$self->_ctrlpid($ctrlpid);
	return 1;
    }

    return undef;
}

sub _close
{
    my ($self) = @_;
    my ($ctrlpid);

    $ctrlpid = $self->_ctrlpid();
    if (defined($ctrlpid) && kill(0, $ctrlpid)) {
	kill('SIGTERM', $ctrlpid);
    }
}


sub init
{
    my ($self, $target, @err) = @_;
    my ($user, $address, $path);

    if (@err) { confess("unexpected parameters"); }
    if (!defined($self->SUPER::init())) {
	return undef;
    }

    if (ref($target) ne '') { confess('target should be a scalar'); }
    
    if ($target =~ m|^(.*)://(?:([^@]+)@)?([^:]+):(.*)$|) {
	if ($1 ne 'ssh') { confess('target should be a ssh scheme'); }
	($user, $address, $path) = ($2, $3, $4);
    } else {
	confess('target should be a ssh scheme');
    }

    if (defined($user)) {
	$self->_user($user);
    }
    
    $self->_address($address);
    $self->_path($path);

    return $self;
}

sub DESTROY
{
    my ($self) = @_;

    $self->_close();
}


sub target
{
    my ($self, @err) = @_;
    my ($user, $target);

    if (@err) { confess('unexpected parameters'); }

    $target = 'ssh://';

    $user = $self->_user();
    if (defined($user)) {
	$target .= $user . '@';
    }

    $target .= $self->_address() . ':';
    $target .= $self->_path();

    return $target;
}


sub list
{
    my ($self, @err) = @_;
    my @command = ('ssh');
    my ($user, $uaddr);
    my @entries;

    if (@err) { confess('unexpected parameters'); }

    $user = $self->_user();
    if (defined($user)) {
	$uaddr = $user . '@' . $self->_address();
    } else {
	$uaddr = $self->_address();
    }

    if ($self->_open()) {
	push(@command, '-o', 'ControlMaster=no', '-o', 'ControlPath='
	     . $self->_control());
    }

    push(@command, $uaddr, 'ls', $self->_path);
    @entries = split("\n", `@command`);

    return $self->_filter_entries(@entries);
}

sub send
{
    my ($self, @err) = @_;
    my ($user, $target);
    my @command;

    if (@err) { confess('unexpected parameters'); }

    $user = $self->_user();
    if (defined($user)) {
	$target = $user . '@' . $self->_address() . ':' . $self->_path();
    } else {
	$target = $self->_address() . ':' . $self->_path();
    }

    @command = $self->_compose_rsync_send($target);
    push(@command, '-z');

    if ($self->_open()) {
	push(@command, '-e', 'ssh -o ControlMaster=no -o ControlPath='
	     . $self->_control());
    }

    return system(@command);
}

sub recv
{
    my ($self, $when, @err) = @_;
    my ($user, $target);
    my @command;

    if (@err) { confess('unexpected parameters'); }

    $user = $self->_user();
    if (defined($user)) {
	$target = $user . '@' . $self->_address() . ':' . $self->_path();
    } else {
	$target = $self->_address() . ':' . $self->_path();
    }

    @command = $self->_compose_rsync_recv($target, $when);
    if (!@command) { return undef; }
    push(@command, '-z');

    if ($self->_open()) {
	push(@command, '-e', 'ssh -o ControlMaster=no -o ControlPath='
	     . $self->_control());
    }

    return system(@command);
}


1;
__END__
