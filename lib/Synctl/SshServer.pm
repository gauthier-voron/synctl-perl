package Synctl::SshServer;

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


sub _serve   { confess('abstract method'); }
sub _report  { confess('abstract method'); }


sub report
{
    my ($self, $code, @hints) = @_;

    if (!defined($code)) {
	return throw(ESYNTAX, undef);
    }

    return $self->_report($code, @hints);
}

sub serve
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_serve();
}


1;
__END__
