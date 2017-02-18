package Synctl::Object;

use strict;
use warnings;

use Synctl qw(:error :verbose);


sub _ro
{
    my ($self, $name, @err) = @_;

    if (!defined($name)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->{$name};
}

sub _rw
{
    my ($self, $name, $value, @err) = @_;

    if (!defined($name)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (defined($value)) {
	$self->{$name} = $value;
    }

    return $self->{$name};
}


sub _new
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
    $self = $self->_new(@args);
    
    return $self;
}


1;
__END__
