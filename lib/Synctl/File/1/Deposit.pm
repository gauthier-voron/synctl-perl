package Synctl::File::1::Deposit;

use parent qw(Synctl::Deposit);
use strict;
use warnings;

use Digest::MD5;
use Synctl qw(:error :verbose);


sub __path { return shift()->_rw('__path', @_); }

sub path { return shift()->_ro('__path', @_); }


sub _new
{
    my ($self, $path, @err) = @_;

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__path($path);
    return $self;
}


sub _init
{
    my ($self) = @_;
    my ($fh);

    if (mkdir($self->__path())) {
	notify(INFO, IFCREAT, $self->__path());
    } else {
	return 0;
    }
    
    if (mkdir($self->__path_object())) {
	notify(INFO, IFCREAT, $self->__path_object());
    } else {
	return 0;
    }
    
    if (mkdir($self->__path_refcount())) {
	notify(INFO, IFCREAT, $self->__path_refcount());
    } else {
	return 0;
    }

    if (open($fh, '>', $self->__path() . '/version')) {
	notify(INFO, IFCREAT, $self->__path() . '/version');
	printf($fh "1\n");
	close($fh);
    } else {
	return 0;
    }

    return 1;
}


sub __path_object
{
    my ($self) = @_;
    my $path = $self->__path();
    return $path . '/object';
}

sub __path_refcount
{
    my ($self) = @_;
    my $path = $self->__path();
    return $path . '/refcount';
}


sub _size
{
    my ($self) = @_;
    my ($path, $size, $dh);

    $path = $self->__path_object();
    if (!opendir($dh, $path)) {
	return throw(ESYS, $!);
    }

    $size = scalar(grep { /^[0-9a-f]{32}$/ } readdir($dh));

    closedir($dh);
    return $size;
}

sub _hash
{
    my ($self, $handler) = @_;
    my ($path, $entry, $dh);

    $path = $self->__path_object();
    if (!opendir($dh, $path)) {
	return throw(ESYS, $!);
    }

    foreach $entry (grep { /^[0-9a-f]{32}$/ } readdir($dh)) {
	$handler->($entry);
    }

    closedir($dh);
    return 1;
}


sub __get
{
    my ($self, $hash, $force) = @_;
    my ($fh, $count, $path);

    $path = $self->__path_refcount() . '/' . $hash;

    if (open($fh, '<', $path)) {
	chomp($count = <$fh>);
	close($fh);
    } elsif ($force) {
	$count = 0;
    } else {
	return undef;
    }

    $count++;

    if (!open($fh, '>', $path)) {
	return throw(ESYS, $!);
    }
    printf($fh "%d\n", $count);
    close($fh);

    return $count;
}

sub _get
{
    my ($self, $hash) = @_;
    return $self->__get($hash, 0);
}

sub _put
{
    my ($self, $hash) = @_;
    my ($fh, $count, $path);

    $path = $self->__path_refcount() . '/' . $hash;
    
    if (!open($fh, '<', $path)) {
	return undef;
    }
    chomp($count = <$fh>);
    close($fh);

    $count--;

    if ($count == 0) {
	unlink($path);
	unlink($self->__path_object() . '/' . $hash);
    } else {
	if (!open($fh, '>', $path)) {
	    return throw(ESYS, $!);
	}
	printf($fh "%d\n", $count);
	close($fh);
    }

    return $count;
}


sub _send
{
    my ($self, $provider) = @_;
    my ($path, $fh, $chunk);
    my ($hash, $context, $ret);

    $path = $self->__path_object() . '/new';
    if (!open($fh, '>', $path)) {
	return throw(ESYS, $!);
    }

    $context = Digest::MD5->new();

    while (defined($chunk = $provider->())) {
	printf($fh "%s", $chunk);
	$context->add($chunk);
    }

    close($fh);

    $hash = $context->hexdigest();
    
    $ret = $self->__get($hash, 1);
    if (!defined($ret)) {
	return undef;
    }
    
    if (!rename($path, $self->__path_object() . '/' . $hash)) {
	$self->put($hash);
	return throw(ESYS, $!);
    }

    return $hash;
}

sub _recv
{
    my ($self, $hash, $handler, @err) = @_;
    my ($path, $fh, $chunk);

    $path = $self->__path_object() . '/' . $hash;
    if (!open($fh, '<', $path)) {
	return undef;
    }

    local $/ = \8192;
    while (defined($chunk = <$fh>)) {
	$handler->($chunk);
    }

    close($fh);
    return 1;
}

sub _flush
{
    my ($self) = @_;

    # nothing to do

    return 1;
}


1;
__END__
