package Synctl::Sender;

use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);
use Fcntl qw(SEEK_SET);
use Scalar::Util qw(blessed);

use Synctl qw(:error :verbose);


sub __deposit
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__deposit'} = $value;
    }

    return $self->{'__deposit'};
}

sub __snapshot
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__snapshot'} = $value;
    }

    return $self->{'__snapshot'};
}

sub __seeker
{
    my ($self, $value) = @_;

    if (defined($value)) {
	$self->{'__seeker'} = $value;
    }

    return $self->{'__seeker'};
}


sub new
{
    my ($class, $deposit, $snapshot, $seeker, @err) = @_;
    my $self;

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
    }

    $self = bless({}, $class);
    $self->__deposit($deposit);
    $self->__snapshot($snapshot);
    $self->__seeker($seeker);

    return $self;
}


sub deposit
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__deposit();
}

sub snapshot
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__snapshot();
}

sub seeker
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }
    
    return $self->__seeker();
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
	notify(INFO, IWSEND, $args{SIZE});
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

	notify(INFO, IWSEND, $args{SIZE});

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

sub send
{
    my ($self, @err) = @_;
    my ($ret, %hashlist, $err);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    notify(INFO, IRLOAD);
    $ret = $self->deposit()->hash(sub { $hashlist{shift()} = 1 });
    if (!$ret) { return $ret; }

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

    return $err;
}


1;
__END__
