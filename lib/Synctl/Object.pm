package Synctl::Object;

use strict;
use warnings;

use Carp;


sub _rw
{
    my ($self, $name, $value, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    if (defined($value)) {
	$self->{$name} = $value;
    }

    return $self->{$name};
}

sub _ro
{
    my ($self, $name, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    return $self->{$name};
}


sub init
{
    my ($self, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    
    return 0;
}

sub new
{
    my ($class, @args) = @_;
    my $self = bless({}, $class);

    if (!defined($self->init(@args))) {
	return undef;
    } else {
	return $self;
    }
}


1;
__END__
