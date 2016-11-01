package Synctl::Profile;

use strict;
use warnings;

use IO::Handle;
use Synctl qw(:error :verbose);


sub __rw
{
    my ($self, $name, $value) = @_;

    if (defined($value)) {
	$self->{$name} = $value;
    }

    return $self->{$name};
}

sub __client  { return shift()->__rw('__client',  @_); }
sub __server  { return shift()->__rw('__server',  @_); }
sub __filters { return shift()->__rw('__filters', @_); }


sub new
{
    my ($class, @err) = @_;
    my $self;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self = bless({}, $class);
    $self->__filters([]);

    return $self;
}


sub client
{
    my ($self, $value, @err) = @_;

    if (defined($value) && ref($value) ne '') {
	return throw(EINVLD, $value);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__client($value);
}

sub server
{
    my ($self, $value, @err) = @_;

    if (defined($value) && ref($value) ne '') {
	return throw(EINVLD, $value);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__server($value);
}

sub filters
{
    my ($self, $value, @err) = @_;
    my ($elem, $type);

    if (defined($value)) {
	if (ref($value) ne 'ARRAY') {
	    return throw(EINVLD, $value);
	}
	
	foreach $elem (@$value) {
	    if (ref($elem) ne '') {
		return throw(EINVLD, $elem);
	    }

	    $type = substr($elem, 0, 1);
	    if ($type ne '+' && $type ne '-') {
		return throw(EINVLD, $elem);
	    }
	}

	$self->__filters($value);
    }

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__filters();
}

sub __add_filters
{
    my ($self, $type, @values) = @_;
    my ($value, @arr, @done);

    foreach $value (@values) {
	if (ref($value) ne '') {
	    return throw(EINVLD, $value);
	}

	@arr = (@{$self->__filters()}, $type . $value);

	if (defined($self->filters([ @arr ]))) {
	    push(@done, $value);
	}
    }

    return @done;
}

sub include { return shift()->__add_filters('+', @_); }
sub exclude { return shift()->__add_filters('-', @_); }


sub __regexify
{
    my ($elem) = @_;
    my @splited;

    if ($elem =~ m|^/|) {
	$elem = 'X' . $elem . 'X';
	@splited = split(/\*\*/, $elem);
	map { s|\*|[^/]*|g } @splited;
	$elem = join('.*', @splited);
	$elem =~ s|^X(.*)X$|$1|;
	$elem =~ s|\?|[^/]|g;
	$elem =~ s|\$|\$|g;
	$elem = '^' . $elem . '$';
    }

    return qr:$elem:;
}

# sub __unmatch
# {
#     my ($path, $includes, $excludes) = @_;
#     my ($regex, @imatched, @ematched, $subpath);

#     foreach $regex (@$includes) {
# 	if (!($path =~ $regex)) {
# 	    return 1;
# 	}
#     }

#     foreach $regex (@$excludes) {
# 	if (!($path =~ $regex)) {
# 	    return 0;
# 	}
#     }

#     $subpath = substr($path, 0, length($path) - 1);
#     return __unmatch($subpath, $includes, $excludes);
# }

# sub __match
# {
#     my ($path, $includes, $excludes) = @_;
#     my ($regex, @imatched, @ematched, $subpath);

#     foreach $regex (@$excludes) {
# 	if ($path =~ $regex) {
# 	    push(@ematched, $regex);
# 	}
#     }

#     if (!@ematched) {
# 	return 1;
#     }

#     foreach $regex (@$includes) {
# 	if ($path =~ $regex) {
# 	    push(@imatched, $regex);
# 	}
#     }

#     if (!@imatched) {
# 	return 0;
#     }

#     $subpath = substr($path, 0, length($path) - 1);
#     return __unmatch($subpath, \@imatched, \@ematched);
# }

sub filter
{
    my ($self, @err) = @_;
    my ($elem, $type, $value, $ret, @filters);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    foreach $elem (@{$self->__filters()}) {
	$type = substr($elem, 0, 1);
	$value = substr($elem, 1);
	$ret = __regexify($value);
	if ($type eq '+') {
	    notify(DEBUG, IREGEX, 'include', $value, $ret);
	    push(@filters, [ 1, $ret ]);
	} elsif ($type eq '-') {
	    notify(DEBUG, IREGEX, 'exclude', $value, $ret);
	    push(@filters, [ 0, $ret ]);
	}
    }

    return sub {
	my ($path) = @_;
	my ($filter, $type, $regex);

	foreach $filter (@filters) {
	    ($type, $regex) = @$filter;
	    if ($path =~ $regex) {
		return $type;
	    }
	}
	
	return 1;
    };
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

sub read
{
    my ($self, $input, @err) = @_;
    my ($provider, $ln, $line, $data);
    my ($key, $value, $setter);
    my %setters = (
	'server'  => \&server,
	'client'  => \&client,
	'include' => \&include,
	'exclude' => \&exclude
	);

    if (!defined($input)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($provider = __normalize_input($input))) {
	return undef;
    }

    $self->filters([]);

    $ln = 0;
    while (defined($line = $provider->())) {
	$ln++;

	$data = $line;
	$data =~ s/#.*//;
	$data =~ s/^\s*//;
	$data =~ s/\s*$//;
	next if ($data eq '');

	if (!($data =~ m|^([^=]+?)\s*=\s*(.*)$|)) {
	    goto err;
	}

	($key, $value) = ($1, $2);

	if (!defined($setter = $setters{$key})) {
	    goto err;
	}

	if (!defined($setter->($self, $value))) {
	    return undef;
	}
    }

    return 1;
  err:
    return throw(ECONFIG, $ln, $line);
}


1;
__END__
