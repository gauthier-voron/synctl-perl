package Synctl::Fsck;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error :verbose);


sub partial      { return shift()->_rw('__partial', @_); }
sub reset        { return shift()->_rw('__reset', @_); }

sub _interrupted { return shift()->_rw('__interrupted', @_); }


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->partial(1);
    $self->reset(0);
    $self->_interrupted(0);

    return $self;
}


sub _checkup { confess('abstract method'); }


sub interrupt
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->_interrupted(1);
    return 1;
}


sub checkup
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_checkup();
}


1;
__END__
