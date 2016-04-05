package Synctl::FileBackend;

use parent qw(Synctl::Backend);
use strict;
use warnings;

use Carp;


sub _target { shift()->_rw('_target', @_); }


sub init
{
    my ($self, $target, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    if (!defined($self->SUPER::init())) {
	return undef;
    }

    if (ref($target) ne '') { confess('target should be a scalar'); }
    
    if ($target =~ m|^(.*)://(.*)$|) {
	if ($1 ne 'file') { confess('target should be a file scheme'); }
	$target = $2;
    }

    if (!$target =~ m|^/|) { confess('target should be an absolute path'); }

    $self->_target($target);
    return $self;
}


sub target
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected parameters'); }

    return 'file://' . $self->_target();
}


sub list
{
    my ($self, @err) = @_;
    my ($dh, @entries);

    if (@err) { confess('unexpected parameters'); }
    
    if (!opendir($dh, $self->_target())) {
	carp("cannot opend '" . $self->_target() . "' : $!");
	return undef;
    } else {
	@entries = readdir($dh);
	closedir($dh);
    }

    return $self->_filter_entries(@entries);
}

sub send
{
    my ($self, @err) = @_;
    my @command = $self->_compose_rsync_send($self->_target);

    if (@err) { confess('unexpected parameters'); }

    return system(@command);
}

sub recv
{
    my ($self, $when, @err) = @_;
    my @command = $self->_compose_rsync_recv($self->_target, $when);

    if (@err) { confess('unexpected parameters'); }
    if (!@command) { return undef; }

    return system(@command);
}


1;
__END__
