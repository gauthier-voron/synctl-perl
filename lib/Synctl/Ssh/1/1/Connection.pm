package Synctl::Ssh::1::1::Connection;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Synctl qw(:error);
use Synctl::Ssh::1::1::Codec qw(encode decode);


sub __in
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__in'} = $value;
    }

    return $self->{'__in'};
}

sub __out
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__out'} = $value;
    }

    return $self->{'__out'};
}

sub __vector
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__vector'} = $value;
    }

    return $self->{'__vector'};
}

sub __newtag
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__newtag'} = $value;
    } else {
	$value = $self->{'__newtag'};
	$self->{'__newtag'} = $value + 1;
    }

    return $value;
}


sub _new
{
    my ($self, $in, $out, @err) = @_;

    if (!defined($in) || !defined($out)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($in) ne 'GLOB' &&
	     !(blessed($in) && $in->isa('IO::Handle'))) {
	return throw(EINVLD, $in);
    } elsif (ref($out) ne 'GLOB' &&
	     !(blessed($out) && $out->isa('IO::Handle'))) {
	return throw(EINVLD, $out);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->__in($in);
    $self->__out($out);
    $self->__vector({});
    $self->__newtag(0);

    return $self;
}

sub new
{
    my ($class, @args) = @_;
    my $self = bless({}, $class);

    return $self->_new(@args);
}


sub in
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__in();
}

sub out
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__out();
}


sub _vector
{
    my ($self) = @_;
    return $self->__vector();
}

sub _newtag
{
    my ($self) = @_;
    return $self->__newtag();
}

sub _fetch
{
    my ($self, @err) = @_;
    my ($in, $packet, $length);
    
    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $in = $self->in();

    local $/ = ':';
    if (!defined($length = <$in>)) {
	return undef;
    }
    if (!($length =~ /^(\d+):$/)) {
	return undef;
    }
    chop($length);

    local $/ = \$length;
    $packet = <$in>;
    $packet = decode($packet);
    if (ref($packet) ne 'ARRAY') {
	return undef;
    }
    
    return $packet;
}


sub call
{
    my ($self, $tag, @args) = @_;
    my ($scal, @arr, $handler, $rtag);

    if (!defined($tag)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($tag) ne '') {
	return throw(EINVLD, $tag);
    }

    $handler = sub { ($_, $_, @arr) = @_; return 0; };

    $rtag = $self->talk($tag, $handler, @args);
    if (!defined($rtag)) {
	return undef;
    }

    $self->wait($rtag);

    if (wantarray()) {
	return @arr;
    } else {
	return shift(@arr);
    }
}

sub talk
{
    my ($self, $stag, $handler, @args) = @_;
    my $rtag = $self->_newtag();

    if (!defined($stag) || !defined($handler)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($stag) ne '') {
	return throw(EINVLD, $stag);
    } if (ref($handler) ne 'CODE') {
	return throw(EINVLD, $handler);
    }
    
    if (!defined($self->send($stag, $rtag, @args))) {
	return undef;
    }

    if (!defined($self->recv($rtag, $handler))) {
	return undef;
    }
    
    return $rtag;
}

sub wait
{
    my ($self, $wtag) = @_;
    my ($packet, $stag, $rtag, $payload);
    my $vector = $self->_vector();
    my ($handler, $ret, $run);

    if (defined($wtag)) {
	if (ref($wtag) ne '') {
	    return throw(EINVLD, $wtag);
	}

	if (!defined($vector->{$wtag})) {
	    return 0;
	}
    }

    $run = 1;
    while ($run) {
	$packet = $self->_fetch();
	if (!defined($packet)) {
	    return 0;
	}

	($stag, $rtag, $payload) = @$packet;
	
	$handler = $vector->{$stag};
	if (!defined($handler)) {
	    next;
	}

	$ret = $handler->($stag, $rtag, @$payload);
	if (!$ret) {
	    delete($vector->{$stag});
	}

	if (!defined($wtag) || ($stag eq $wtag)) {
	    $run = 0;
	}
    }

    return 1;
}

sub send
{
    my ($self, $stag, $rtag, @args) = @_;
    my $out = $self->out();
    my $packet = encode([ $stag, $rtag, \@args ]);
    my ($prev, $length);

    $length = length($packet);
    printf($out "%d:%s", $length, $packet);

    $prev = select($out);
    local $| = 1;
    printf($out "");
    local $| = 0;

    select($prev);
    return 1;
}

sub recv
{
    my ($self, $tag, $handler, @err) = @_;
    my $vector = $self->_vector();
    my $prev = $vector->{$tag};

    if (!defined($tag)) {
	return throw(ESYNTAX, undef);
    } elsif (defined($handler) && ref($handler) ne 'CODE') {
	return throw(EINVLD, $handler);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!defined($prev)) {
	$prev = 0;
    }

    if (defined($handler)) {
	$vector->{$tag} = $handler;
    } else {
	delete($vector->{$tag});
    }
    
    return $prev;
}


1;
__END__
