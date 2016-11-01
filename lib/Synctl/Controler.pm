package Synctl::Controler;

use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use Synctl qw(:error);


sub _init
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self;
}

sub new
{
    my ($class, @args) = @_;
    my $self;

    $self = bless({}, $class);
    $self = $self->_init(@args);
    
    return $self;
}


sub deposit
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    confess('abstract method');
}

sub snapshot
{
    my ($self, $date, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    confess('abstract method');
}

sub create
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    confess('abstract method');
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

    confess('abstract method');
}


1;
__END__
