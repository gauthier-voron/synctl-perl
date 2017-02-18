package Synctl::Ssh::1::1::Snapshot;

use parent qw(Synctl::Snapshot);
use strict;
use warnings;

use constant {
    SBUFFER => 128
};

use Carp;
use Scalar::Util qw(blessed);
use Synctl qw(:error);


sub __connection { return shift()->_rw('__connection', @_); }
sub __id         { return shift()->_rw('__id',         @_); }
sub __writeback  { return shift()->_rw('__writeback',  @_); }
sub __dcontent   { return shift()->_rw('__dcontent',   @_); }
sub __fcontent   { return shift()->_rw('__fcontent',   @_); }
sub __property   { return shift()->_rw('__property',   @_); }
sub __buffer     { return shift()->_rw('__buffer',     @_); }
sub __bufsize    { return shift()->_rw('__bufsize',    @_); }


sub _new
{
    my ($self, $connection, $id, @err) = @_;

    if (!defined($connection) || !defined($id)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!blessed($connection) ||
	     !$connection->isa('Synctl::Ssh::1::1::Connection')) {
	return throw(EINVLD, $connection);
    } elsif (ref($id) ne '') {
	return throw(EINVLD, $id);
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    $self->__connection($connection);
    $self->__id($id);

    $self->__writeback(0);
    $self->__fcontent({});
    $self->__dcontent({});
    $self->__property({});

    $self->__buffer([]);
    $self->__bufsize(0);
    
    return $self;
}


sub __load_file
{
    my ($self, $path) = @_;
    my $content = $self->get_file($path);
    my $props = $self->get_properties($path);

    $self->__fcontent()->{$path} = $content;
    $self->__property()->{$path} = $props;
}

sub __load_directory
{
    my ($self, $path) = @_;
    my ($children, $child, $sep);
    my $props = $self->get_properties($path);

    $children = $self->get_directory($path);
    if (!defined($children)) {
	return;
    }

    $self->__dcontent()->{$path} = $children;
    $self->__property()->{$path} = $props;

    if ($path ne '/') {
	$sep = '/';
    } else {
	$sep = '';
    }

    foreach $child (@$children) {
	$self->__load_file($path . $sep . $child);
	$self->__load_directory($path . $sep . $child);
    }
}

sub load
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->__writeback(1);
    $self->__load_directory('/');
}


sub _flush_buffer
{
    my ($self) = @_;
    my $buffer = $self->__buffer();
    my $id = $self->__id();
    my $connection = $self->__connection();

    $connection->send('snapshot_set_buffer', undef, $id, $buffer);

    $self->__buffer([]);
    $self->__bufsize(0);
}

sub _send_bufferized
{
    my ($self, @args) = @_;
    my $buffer = $self->__buffer();
    my $size = $self->__bufsize();

    push(@$buffer, \@args);
    $size = $size + 1;

    if ($size >= SBUFFER) {
	$self->_flush_buffer();
    } else {
	$self->__bufsize($size);
    }

    return 1;
}

sub _send_file_bufferized
{
    my ($self, @args) = @_;
    return $self->_send_bufferized('f', @args);
}

sub _send_directory_bufferized
{
    my ($self, @args) = @_;
    return $self->_send_bufferized('d', @args);
}


sub _init
{
    return undef;
}

sub _id
{
    my ($self) = @_;
    return $self->__id();
}

sub _date
{
    my ($self) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();

    return $connection->call('snapshot_date', $id);
}

sub _set_file
{
    my ($self, $path, $content, %args) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();
    my $wb = $self->__writeback();
    my ($parent, $child, $children);

    if ($wb) {
	if (defined($self->__fcontent()->{$path})) {
	    return undef;
	} elsif (defined($self->__dcontent()->{$path})) {
	    return undef;
	}

	$path =~ m|^(.*)/([^/]+)$|;
	($parent, $child) = ($1, $2);
	if ($parent eq '') {
	    $parent = '/';
	}

	if (!defined($self->__dcontent()->{$parent})) {
	    return undef;
	}

	$self->_send_file_bufferized($path, $content, %args);

	$self->__fcontent()->{$path} = $content;
	$self->__property()->{$path} = { %args };

	$children = $self->__dcontent()->{$parent};
	push(@$children, $child);

	return 1;
    }

    return $connection->call('snapshot_set_file', $id, $path, $content, %args);
}

sub _set_directory
{
    my ($self, $path, %args) = @_;
    my $connection = $self->__connection();
    my $id = $self->__id();
    my $wb = $self->__writeback();
    my ($parent, $child, $children);

    if ($wb) {
	if (defined($self->__fcontent()->{$path})) {
	    return undef;
	} elsif (defined($self->__dcontent()->{$path})) {
	    return undef;
	}

	if ($path ne '/') {
	    $path =~ m|^(.*)/([^/]+)$|;
	    ($parent, $child) = ($1, $2);
	    if ($parent eq '') {
		$parent = '/';
	    }

	    if (!defined($self->__dcontent()->{$parent})) {
		return undef;
	    }
	}

	$self->_send_directory_bufferized($path, %args);

	$self->__dcontent()->{$path} = [];
	$self->__property()->{$path} = { %args };

	if ($path ne '/') {
	    $children = $self->__dcontent()->{$parent};
	    push(@$children, $child);
	}

	return 1;
    }

    return $connection->call('snapshot_set_directory', $id, $path, %args);
}

sub _get_file
{
    my ($self, $path) = @_;
    my $id = $self->__id();
    my $wb = $self->__writeback();
    my ($ret, $connection);

    if ($wb) {
	$ret = $self->__fcontent()->{$path};
    }

    if (!defined($ret)) {
	$connection = $self->__connection();
	$ret = $connection->call('snapshot_get_file', $id, $path);
	if (defined($ret) && $wb) {
	    $self->__fcontent()->{$path} = $ret;
	}
    }

    return $ret;
}

sub _get_directory
{
    my ($self, $path) = @_;
    my $id = $self->__id();
    my $wb = $self->__writeback();
    my ($ret, $connection);

    if ($wb) {
	$ret = $self->__dcontent()->{$path};
    }

    if (!defined($ret)) {
	$connection = $self->__connection();
	$ret = $connection->call('snapshot_get_directory', $id, $path);
	if (defined($ret) && $wb) {
	    $self->__dcontent()->{$path} = $ret;
	}
    }

    return $ret;
}

sub _get_properties
{
    my ($self, $path) = @_;
    my $id = $self->__id();
    my $wb = $self->__writeback();
    my ($connection, $ret);

    if ($wb) {
	$ret = $self->__property()->{$path};
    }

    if (!defined($ret)) {
	$connection = $self->__connection();
	$ret = $connection->call('snapshot_get_properties', $id, $path);
	if (defined($ret) && $wb) {
	    $self->__property()->{$path} = $ret;
	}
    }

    return $ret;
}

sub _flush
{
    my ($self) = @_;
    my $id = $self->__id();
    my $connection = $self->__connection();
    my $size = $self->__bufsize();

    if ($size > 0) {
	$self->_flush_buffer();
    }

    return $connection->call('snapshot_flush', $id);
}


1;
__END__
