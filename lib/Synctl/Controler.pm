package Synctl::Controler;

use strict;
use warnings;

use Carp;


sub _init
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
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

    if (@err) { confess('unexpected argument'); }
    confess('abstract method');
}

sub snapshot
{
    my ($self, $date, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    confess('abstract method');
}

sub create
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    confess('abstract method');
}

sub delete
{
    my ($self, $date, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    if (!defined($date)) { confess('missing argument'); }
    confess('abstract method');
}


1;
__END__
