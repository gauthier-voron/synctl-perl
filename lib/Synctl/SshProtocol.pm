package Synctl::SshProtocol;

use strict;
use warnings;

use Carp;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(encode decode);


sub __encode_scalar
{
    my ($arg) = @_;
    my $length = length($arg);
    return sprintf("%d:%s", $length, $arg);
}

sub __encode_array
{
    my (@args) = @_;
    my $length = scalar(@args);
    my $acc = $length . ':';

    foreach (@args) {
	$acc .= encode($_);
    }

    return $acc;
}

sub encode
{
    my ($arg, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    
    if (ref($arg) eq '') {
	if (defined($arg)) {
	    return 'S' . __encode_scalar($arg);
	} else {
	    return 'U';
	}
    }

    if (ref($arg) eq 'SCALAR') {
	if (defined($$arg)) {
	    return 's' . __encode_scalar($$arg);
	} else {
	    return 'u';
	}
    }

    if (ref($arg) eq 'ARRAY') {
	return 'a' . __encode_array(@$arg);
    }

    if (ref($arg) eq 'HASH') {
	return 'h' . __encode_array(%$arg);
    }

    return undef;
}


sub __decode_scalar
{
    my ($text) = @_;
    my ($length, $scalar);

    if (!($text =~ /^(\d+):(.*)$/s)) {
	return undef;
    }

    ($length, $text) = ($1, $2);
    $scalar = substr($text, 0, $length);
    $text = substr($text, $length);

    return ($text, $scalar);
}

sub __decode_array
{
    my ($text) = @_;
    my ($length, $elem, @array);

    if (!($text =~ /^(\d+):(.*)$/s)) {
	return undef;
    }

    ($length, $text) = ($1, $2);
    while ($length-- > 0) {
	($text, $elem) = __decode($text);
	push(@array, $elem);
    }

    return ($text, \@array);
}

sub __decode
{
    my ($text) = @_;
    my $type = substr($text, 0, 1);
    my $var;

    $text = substr($text, 1);

    if ($type eq 'U') {
	return ($text, undef);
    } elsif ($type eq 'u') {
	$var = undef;
	return ($text, \$var);
    }

    if ($type eq 'S') {
	return __decode_scalar($text);
    } elsif ($type eq 's') {
	($text, $var) = __decode_scalar($text);
	return ($text, \$var);
    }

    if ($type eq 'a') {
	return __decode_array($text);
    } elsif ($type eq 'h') {
	($text, $var) = __decode_array($text);
	return ($text, { @$var });
    }

    return (undef, undef);
}

sub decode
{
    my ($text) = @_;
    my ($rem, $var) = __decode($text);
    return $var;
}


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


sub connect
{
    my ($class, $in, $out, @err) = @_;
    my $self;

    if (@err) { confess('unexpected argument'); }
    if (!defined($in) || !defined($out)) { confess('missing argument'); }
    if (ref($in) ne 'GLOB' || ref($out) ne 'GLOB') {
	confess('invalid argument');
    }

    $self = bless({}, $class);
    $self->__in($in);
    $self->__out($out);

    return $self;
}


sub in
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->__in();
}

sub out
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->__out();
}


sub send
{
    my ($self, @args) = @_;
    my $out = $self->out();
    my $packet = encode(\@args);
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
    my ($self, @err) = @_;
    my ($in, $packet, $length);

    if (@err) { confess('unexpected argument'); }

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

    if (wantarray()) {
	return @$packet;
    } else {
	return pop(@$packet);
    }
}


1;
__END__
