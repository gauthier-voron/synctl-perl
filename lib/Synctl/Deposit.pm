package Synctl::Deposit;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;
use IO::Handle;

use Synctl qw(:error :verbose);


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


sub _init  { confess('abstract method'); }
sub _hash  { confess('abstract method'); }
sub _size  { confess('abstract method'); }
sub _get   { confess('abstract method'); }
sub _put   { confess('abstract method'); }
sub _send  { confess('abstract method'); }
sub _recv  { confess('abstract method'); }
sub _flush { confess('abstract method'); }


sub init
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->_init();
}

sub size
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_size();
}

sub hash
{
    my ($self, $output, @err) = @_;
    my ($handler);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($handler = $self->_normalize_output($output, "\n"))) {
	return undef;
    }

    return $self->_hash($handler);
}

sub get
{
    my ($self, $hash, @err) = @_;

    if (!defined($hash)) {
	return throw(ESYNTAX, undef);
    } elsif (!($hash =~ /^[0-9a-f]{32}$/)) {
	return throw(EINVLD, $hash);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    notify(DEBUG, IRGET, $hash);
    return $self->_get($hash);
}

sub put
{
    my ($self, $hash, @err) = @_;

    if (!defined($hash)) {
	return throw(ESYNTAX, undef);
    } elsif (!($hash =~ /^[0-9a-f]{32}$/)) {
	return throw(EINVLD, $hash);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    notify(DEBUG, IRPUT, $hash);
    return $self->_put($hash);
}

sub send
{
    my ($self, $input, @err) = @_;
    my ($provider);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($provider = $self->_normalize_input($input))) {
	return undef;
    }

    return $self->_send($provider);
}

sub recv
{
    my ($self, $hash, $output, @err) = @_;
    my ($handler);

    if (!defined($hash)) {
	return throw(ESYNTAX, undef);
    } elsif (!($hash =~ /^[0-9a-f]{32}$/)) {
	return throw(EINVLD, $hash);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($handler = $self->_normalize_output($output))) {
	return undef;
    }

    return $self->_recv($hash, $handler);
}

sub flush
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->_flush();
}


sub _normalize_input
{
    my ($self, $input) = @_;
    my ($code, $tmp);

    if (ref($input) eq 'GLOB') {
	$input = IO::Handle->new_from_fd($input, '<');
    } elsif (ref($input) eq '') {
	$tmp = $input;
	$input = \$tmp;
    }

    if (ref($input) eq 'ARRAY') {
	$code = sub { return shift(@$input) };
    } elsif (ref($input) eq 'SCALAR') {
	$code = sub { my $tmp = $$input; $$input = undef; return $tmp; };
    } elsif (ref($input) eq 'IO::Handle') {
	$code = sub { my $b; $input->read($b, 8192) or $b = undef; return $b };
    } elsif (ref($input) eq 'CODE') {
	$code = $input;
    } else {
	return throw(EINVLD, $input);
    }

    return sub {
	my $tmp = $code->(@_);

	notify(DEBUG, ICSEND, length($tmp));

	return $tmp;
    };
}

sub _normalize_output
{
    my ($self, $output, $sep) = @_;
    my $code;

    if (!defined($sep)) {
	$sep = '';
    }

    if (ref($output) eq 'GLOB') {
        $output = IO::Handle->new_from_fd($output, '>');
    }

    if (ref($output) eq 'ARRAY') {
	@$output = ();
        $code = sub { push(@$output, $_[0]) };
    } elsif (ref($output) eq 'SCALAR') {
	$$output = '';
        $code = sub { $$output .= $_[0] . $sep };
    } elsif (ref($output) eq 'IO::Handle') {
        $code = sub { $output->printf("%s%s", $_[0], $sep) };
    } elsif (ref($output) eq 'CODE') {
        $code = $output;
    } else {
	return throw(EINVLD, $output);
    }

    return sub {
	my ($tmp) = @_;
	
	notify(DEBUG, ICRECV, length($tmp));
	
	return $code->($tmp);
    };
}


1;
__END__
