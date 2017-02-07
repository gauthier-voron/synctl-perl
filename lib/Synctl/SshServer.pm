package Synctl::SshServer;

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
    }

    return $self;
}

sub new
{
    my ($class, @args) = @_;
    my $self = bless({}, $class);

    return $self->_new(@args);
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
