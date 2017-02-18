package Synctl::Controler;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error);


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    return $self;
}


sub _deposit  { confess('abstract method'); }
sub _snapshot { confess('abstract method'); }
sub _create   { confess('abstract method'); }
sub _delete   { confess('abstract method'); }


sub deposit
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_deposit();
}

sub snapshot
{
    my ($self, $date, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_snapshot();
}

sub create
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_create();
}

sub delete
{
    my ($self, $snapshot, @err) = @_;

    if (!defined($snapshot)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($snapshot) || !$snapshot->isa('Synctl::Snapshot')) {
	return throw(EINVLD, $snapshot);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_delete($snapshot);
}


1;
__END__
