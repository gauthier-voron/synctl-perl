package Synctl::Sender;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Fcntl qw(SEEK_SET);
use Scalar::Util qw(blessed);

use Synctl qw(:error :verbose);


sub __deposit  { return shift()->_rw('__deposit',  @_); }
sub __snapshot { return shift()->_rw('__snapshot', @_); }
sub __seeker   { return shift()->_rw('__seeker',   @_); }

sub deposit  { return shift()->_ro('__deposit',  @_); }
sub snapshot { return shift()->_ro('__snapshot', @_); }
sub seeker   { return shift()->_ro('__seeker',   @_); }


sub _new
{
    my ($self, $deposit, $snapshot, $seeker, @err) = @_;

    if (!defined($deposit) || !defined($snapshot) || !defined($seeker)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($deposit) || !$deposit->isa('Synctl::Deposit')) {
	return throw(EINVLD, $deposit);
    } elsif (!blessed($snapshot) || !$snapshot->isa('Synctl::Snapshot')) {
	return throw(EINVLD, $snapshot);
    } elsif (!blessed($seeker) || !$seeker->isa('Synctl::Seeker')) {
	return throw(EINVLD, $seeker);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__deposit($deposit);
    $self->__snapshot($snapshot);
    $self->__seeker($seeker);

    return $self;
}


sub __send_link
{
    my ($self, %args) = @_;
    my $content = readlink($args{PATH});
    my ($deposit, $hash, $ret, $snapshot);
    my %props;

    if (!defined($content)) { return undef; }
    $hash = md5_hex($content);

    $deposit = $self->deposit();

    $ret = $deposit->get($hash);
    if (!defined($ret)) {
	notify(DEBUG, IWSEND, $args{SIZE});
	$ret = $deposit->send($content);
	if ($ret ne $hash) {
	    $deposit->put($ret);
	    return undef;
	}
    }

    $snapshot = $self->snapshot();
    %props = map { $_, $args{$_} } qw(MODE USER GROUP MTIME INODE SIZE);

    if (!$snapshot->set_file($args{NAME}, $hash, %props)) {
	$deposit->put($hash);
	return undef;
    }

    return 1;
}

sub __send_file
{
    my ($self, %args) = @_;
    my ($deposit, $snapshot);
    my ($fh, $hash, $ret, %props);
    my ($ctx);

    if (!open($fh, '<', $args{PATH})) { return undef; }

    $ctx = Digest::MD5->new();
    $ctx->addfile($fh);
    $hash = $ctx->hexdigest();

    $deposit = $self->deposit();

    $ret = $deposit->get($hash);
    if (!defined($ret)) {
	if (!seek($fh, 0, SEEK_SET)) {
	    close($fh);
	    return undef;
	}

	notify(DEBUG, IWSEND, $args{SIZE});

	$ret = $deposit->send($fh);
	close($fh);
	
	if ($ret ne $hash) {
	    $deposit->put($ret);
	    return undef;
	}
    } else {
	close($fh);
    }

    $snapshot = $self->snapshot();
    %props = map { $_, $args{$_} } qw(MODE USER GROUP MTIME INODE SIZE);

    if (!$snapshot->set_file($args{NAME}, $hash, %props)) {
	$deposit->put($hash);
	return undef;
    }

    return 1;
}

sub __send_directory
{
    my ($self, %args) = @_;
    my ($snapshot, $ret, %props);

    $snapshot = $self->snapshot();
    %props = map { $_, $args{$_} } qw(MODE USER GROUP MTIME);

    if (!$snapshot->set_directory($args{NAME}, %props)) { return undef; }

    return 1;
}

sub __load_server_references
{
    my ($self, $hashlist) = @_;
    my $size;

    notify(INFO, IRLOAD);
    
    $size = $self->deposit()->size();
    notify(DEBUG, IWRECV, $size * 32);
    
    return $self->deposit()->hash(sub { $hashlist->{shift()} = 1 });
}

sub send
{
    my ($self, @err) = @_;
    my ($ret, %hashlist, $err);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (!($self->__load_server_references(\%hashlist))) {
	return undef;
    }

    $err = 0;
    $self->seeker()->seek(sub {
	my %props = @_;
	my $path = $props{PATH};

	notify(INFO, IFSEND, $props{NAME});

	if (-l $path) {
	    $ret = $self->__send_link(%props);
	} elsif (-f $path) {
	    $ret = $self->__send_file(%props);
	} elsif (-d $path) {
	    $ret = $self->__send_directory(%props);
	}

	if (!$ret) { $err++; }
    }, sub {
	$err++;
    });

    $self->deposit()->flush();
    $self->snapshot()->flush();

    return $err;
}


1;
__END__
