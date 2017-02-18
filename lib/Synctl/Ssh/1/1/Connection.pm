package Synctl::Ssh::1::1::Connection;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Scalar::Util qw(blessed);

use Synctl qw(:error);
use Synctl::Ssh::1::1::Codec qw(encode decode);


sub __in     { return shift()->_rw('__in',     @_); }
sub __out    { return shift()->_rw('__out',    @_); }
sub __vector { return shift()->_rw('__vector', @_); }
sub __newtag { return shift()->_rw('__newtag', @_); }

sub _vector { return shift()->_ro('__vector', @_); }
sub _newtag { return shift()->_ro('__newtag', @_); }

sub in  { return shift()->_ro('__in',     @_); }
sub out { return shift()->_ro('__out',    @_); }


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
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__in($in);
    $self->__out($out);
    $self->__vector({});
    $self->__newtag(0);

    return $self;
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
