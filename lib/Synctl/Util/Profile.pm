package Synctl::Util::Profile;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Synctl qw(:error :verbose);


sub __provider { return shift()->_rw('__provider', @_); }


sub _new
{
    my ($self, $input, @err) = @_;
    my ($provider);

    if (!defined($input)) {
	return throw(ESYNTAX, undef);
    } elsif (!defined($provider = __normalize_input($input))) {
	return undef;
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->__provider($provider);

    return $self;
}

sub __normalize_input
{
    my ($input) = @_;
    my ($code, $tmp);

    if (ref($input) eq 'GLOB') {
	$input = IO::Handle->new_from_fd($input, '<');
    } elsif (ref($input) eq '') {
	$tmp = $input;
	$input = [ split("\n", $tmp) ];
    } elsif (ref($input) eq 'SCALAR') {
	$tmp = $$input;
	$input = [ split("\n", $tmp) ];
    }

    if (ref($input) eq 'ARRAY') {
	$code = sub { return shift(@$input) };
    } elsif (ref($input) eq 'SCALAR') {
	$code = sub { my $tmp = $$input; $$input = undef; return $tmp; };
    } elsif (ref($input) eq 'IO::Handle') {
	$code = sub { return $input->getline() };
    } elsif (ref($input) eq 'CODE') {
	$code = $input;
    } else {
	return throw(EINVLD, $input);
    }

    return $code;
}


sub __type_bool
{
    my ($value) = @_;

    if (grep { lc($value) eq $_ } qw(0 1 true false yes no)) {
	return 1;
    } else {
	return 0;
    }
}

sub __type_string
{
    return 1;
}


sub __prepare
{
    my ($self, $options) = @_;
    my ($option, $long, $action, $type);
    my (%noptions, %ntypes);

    foreach $option (keys(%$options)) {
	if ($option =~ /^.\|(.*)$/) {
	    $long = $1;
	} elsif (length($option) == 1) {
	    return throw(EINVLD, $option);
	} else {
	    $long = $option;
	}

	$type = \&__type_bool;
	if ($long =~ /(.*)=(.)$/) {
	    $long = $1;
	    if ($2 eq 's') {
		$type = \&__type_string;
	    } else {
		return throw(EINVLD, $option);
	    }
	}

	$action = $options->{$option};
	if (ref($action) ne 'CODE') {
	    return throw(EINVLD, $action);
	}

	$noptions{$long} = $action;
	$ntypes{$long} = $type;
    }

    return (\%noptions, \%ntypes);
}

sub __parse
{
    my ($self, $actions, $types) = @_;
    my ($provider, $ln, $line, $data);
    my ($key, $value, $action, $type);

    $ln = 0;
    $provider = $self->__provider();

    while (defined($line = $provider->())) {
	$ln++;
	chomp($line);

	$data = $line;
	$data =~ s/#.*//;
	$data =~ s/^\s*//;
	$data =~ s/\s*$//;
	next if ($data eq '');

	notify(DEBUG, ICONFIG, "profile line", "'$line'");

	if (!($data =~ m|^([^=]+?)\s*=\s*(.*)$|)) {
	    goto err;
	}

	($key, $value) = ($1, $2);

	if (!defined($action = $actions->{$key})) {
	    goto err;
	}

	if (!$types->{$key}->($value)) {
	    goto err;
	}

	if (!defined($action->($key, $value))) {
	    return undef;
	}
    }

    return 1;
  err:
    return throw(ECONFIG, $ln, $line);
}

sub parse
{
    my ($self, %options) = @_;
    my ($actions, $types);

    ($actions, $types) = $self->__prepare(\%options);
    if (!defined($actions)) {
	return undef;
    }

    return $self->__parse($actions, $types);
}


1;
__END__
