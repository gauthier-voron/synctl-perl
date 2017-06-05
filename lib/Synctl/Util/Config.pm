package Synctl::Util::Config;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Text::ParseWords;

use Synctl qw(:error :verbose);
use Synctl::Receiver;
use Synctl::Seeker;
use Synctl::Sender;
use Synctl::Util::Profile;


sub __option
{
    my ($self, $name, $value) = @_;
    my $count;

    if (defined($value)) {
	$count = $self->__setcount()->{$name};
	if (!defined($count)) {
	    $count = 0;
	}

	if ($count > 0) {
	    $value = $self->__multiset()->($self->_rw($name), $value);
	}

	$self->__setcount()->{$name} = $count + 1;
    }

    return $self->_rw($name, $value);
}

sub server          { return shift()->__option('__server',    @_); }
sub sshlocal        { return shift()->__option('__sshlocal',  @_); }
sub sshremote       { return shift()->__option('__sshremote', @_); }
sub client          { return shift()->__option('__client',    @_); }
sub older           { return shift()->__option('__older',     @_); }
sub newer           { return shift()->__option('__newer',     @_); }
sub date            { return shift()->__option('__date',      @_); }
sub reversed        { return shift()->__option('__reversed',  @_); }
sub snapshotid      { return shift()->__option('__snapshot',  @_); }

sub __directory     { return shift()->_rw('__directory', @_); }
sub __filters       { return shift()->_rw('__filters',   @_); }
sub __controler     { return shift()->_rw('__controler', @_); }
sub __multiset      { return shift()->_rw('__multiset',  @_); }
sub __setcount      { return shift()->_rw('__setcount',  @_); }


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->__directory([]);
    $self->__filters([]);
    $self->__setcount({});
    $self->__multiset(sub {
	my ($old, $new) = @_;
	return $new;
    });

    return $self;
}


sub directory
{
    my ($self, @values) = @_;
    my ($value, $list);

    $list = $self->__directory();

    foreach $value (@values) {
	push(@$list, split(':', $value));
    }

    return [ @$list ];
}

sub filters
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return [ @{$self->__filters()} ];
}

sub multiset
{
    my ($self, $value, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (defined($value)) {
	if (ref($value) ne 'CODE') {
	    return throw(EINVLD, $value);
	}
	$self->__multiset($value);
    }

    return $self->__multiset();
}


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


sub __add_filter
{
    my ($self, $prefix, @values) = @_;
    my ($filters);

    if (!@values) {
	return throw(ESYNTAX, undef);
    }

    $filters = $self->__filters();
    push(@$filters, map { $prefix . $_ } @values);
}

sub include { shift()->__add_filter('+', @_); }
sub exclude { shift()->__add_filter('-', @_); }


sub __find_profile
{
    my ($self, $pname) = @_;
    my ($directory, $path);

    foreach $directory (@{$self->directory()}) {
	$path = $directory . '/' . $pname;
	if (-f $path && -r $path) {
	    return $path;
	}
    }

    return undef;
}

sub profile
{
    my ($self, $pname, @err) = @_;
    my ($path, $fh, $content);

    if (!defined($pname)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $path = $self->__find_profile($pname);

    if (!defined($path)) {
	return throw(ECONFIG, 'cannot find profile', $pname);
    } else {
	notify(DEBUG, ICONFIG, 'profile', $path);
    }

    if (!open($fh, '<', $path)) {
	return throw(ESYS, $!, $path);
    } else {
	local $/ = undef;
	$content = <$fh>;
	close($fh);
    }

    return Synctl::Util::Profile->new($content);
}

sub controler
{
    my ($self, @err) = @_;
    my ($server, $sshopt, %opts, $controler);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (defined($controler = $self->__controler())) {
	return $controler;
    }

    $server = $self->server();

    if (!defined($server)) {
	return throw(ECONFIG, 'missing server location');
    } else {
	notify(DEBUG, ICONFIG, 'server', $server);
    }

    $sshopt = $self->sshlocal();
    if (defined($sshopt)) {
	$opts{COMMAND} = [ shellwords($sshopt) ];
    }

    $sshopt = $self->sshremote();
    if (defined($sshopt)) {
	$opts{RCOMMAND} = [ shellwords($sshopt) ];
    }

    $controler = Synctl::controler($server, %opts);
    $self->__controler($controler);
    return $controler;
}

sub seeker
{
    my ($self, @err) = @_;
    my ($client, $seeker);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!defined($client = $self->client())) {
	return throw(ECONFIG, 'missing client location');
    } elsif (!defined($seeker = Synctl::Seeker->new($client))) {
	return undef;
    } elsif (!defined($seeker->filter($self->filter()))) {
	return undef;
    }

    return $seeker;
}


sub snapshots
{
    my ($self, @err) = @_;
    my ($controler, @snapshots, $date, $ndate, $id);
    my ($snapshot, @tmp);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $controler = $self->controler();
    if (!defined($controler)) {
	return undef;
    }

    @snapshots = $controler->snapshot();

    $id = $self->snapshotid();
    if (defined($id)) {
	if (ref($id) eq '') {
	    $id = [ $id ];
	}

	@tmp = ();
	foreach $snapshot (@snapshots) {
	    if (grep { $snapshot->id() =~ /^$_/ } @$id) {
		push(@tmp, $snapshot);
	    }
	}

	@snapshots = @tmp;
    }

    $date = $self->older();
    if (defined($date)) {
	$ndate = $date;
	if (length($ndate) < 19) {
	    $ndate .= substr('0000-00-00-00-00-00', length($date));
	}
	if (!($ndate =~ /^\d{4}(-\d\d){5}$/)) {
	    return throw(ECONFIG, 'invalid date format', $date);
	}
	@snapshots = grep { $_->date() lt $ndate } @snapshots;
    }

    $date = $self->newer();
    if (defined($date)) {
	$ndate = $date;
	if (length($ndate) < 19) {
	    $ndate .= substr('9999-99-99-99-99-99', length($date));
	}
	if (!($ndate =~ /^\d{4}(-\d\d){5}$/)) {
	    return throw(ECONFIG, 'invalid date format', $date);
	}
	@snapshots = grep { $_->date() gt $ndate } @snapshots;
    }

    if (defined($self->reversed())) {
        @snapshots = sort { $b->date() cmp $a->date() } @snapshots;
    } else {
        @snapshots = sort { $a->date() cmp $b->date() } @snapshots;
    }

    return @snapshots;
}

sub send
{
    my ($self, @err) = @_;
    my ($controler, $seeker, $snapshot, $sender);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!defined($controler = $self->controler())) {
	return undef;
    } elsif (!defined($seeker = $self->seeker())) {
	return undef;
    }

    if (!defined($snapshot = $controler->create())) {
	return undef;
    }

    $sender = Synctl::Sender->new($controler->deposit(), $snapshot, $seeker);
    if (!defined($sender)) {
	$controler->delete($snapshot);
	return undef;
    }

    return $sender->send();
}

sub recv
{
    my ($self, @err) = @_;
    my ($id, $controler, @snapshots, $snapshot);
    my ($deposit, $receiver, $client);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!defined($controler = $self->controler())) {
	return undef;
    } elsif (!defined($client = $self->client())) {
	return throw(ECONFIG, 'missing client location');
    }

    @snapshots = $self->snapshots();
    @snapshots = reverse(@snapshots);

    if (scalar(@snapshots) == 0) {
	return throw(ECONFIG, 'no matching snapshot');
    }

    if (defined($id = $self->snapshotid()) && scalar(@snapshots) > 1) {
	return throw(ECONFIG, 'more than one snapshot for id', $id);
    }

    $snapshot = shift(@snapshots);
    notify(DEBUG, ICONFIG, 'snapshot', $snapshot->id());

    $deposit = $controler->deposit();
    $receiver = Synctl::Receiver->new('/', $client, $snapshot, $deposit);
    if (!defined($receiver)) {
	return undef;
    }

    $receiver->filter($self->filter());

    if (!(-e $client)) {
	notify(INFO, IFCREAT, $client);
	if (!mkdir($client)) {
	    return throw(ESYS, $!);
	}
    }

    return $receiver->receive();
}


1;
__END__
