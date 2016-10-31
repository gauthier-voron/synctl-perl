package Synctl::FileControler;

use parent qw(Synctl::Controler);
use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:mode);
use Scalar::Util qw(blessed);

use Synctl qw(:error :verbose);
use Synctl::FileSnapshot;


sub __deposit
{
    my ($self, $deposit) = @_;

    if (defined($deposit)) {
	$self->{'__deposit'} = $deposit;
    }

    return $self->{'__deposit'};
}

sub __snaproot
{
    my ($self, $snaproot) = @_;

    if (defined($snaproot)) {
	$self->{'__snaproot'} = $snaproot;
    }

    return $self->{'__snaproot'};
}


sub _init
{
    my ($self, $deposit, $snaproot, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    if (!defined($self->SUPER::_init())) {
	return undef;
    }

    $self->__deposit($deposit);
    $self->__snaproot($snaproot);

    return $self;
}


sub deposit
{
    my ($self, @err) = @_;

    if (@err) { confess('unexpected argument'); }
    return $self->__deposit();
}

sub snapshot
{
    my ($self, @err) = @_;
    my ($root, @ret, $snapshot, $dh, $id);

    if (@err) { confess('unexpected argument'); }

    $root = $self->__snaproot();
    
    if (!opendir($dh, $root)) {
	return undef;
    }

    foreach $id (grep { /^[0-9a-f]{32}$/ } readdir($dh)) {
	$snapshot = Synctl::FileSnapshot->new($root . '/' . $id, $id);
	
	next if (!defined($snapshot->date()));
	
	push(@ret, $snapshot);
    }

    closedir($dh);
    return @ret;
}

sub create
{
    my ($self, @err) = @_;
    my ($date, $id, $root, $snapshot);

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $id = md5_hex(rand(1 << 32));

    $root = $self->__snaproot();
    $snapshot = Synctl::FileSnapshot->new($root . '/' . $id, $id);
    $snapshot->init();

    return $snapshot;
}


sub __delete_ref_file
{
    my ($self, $snapshot, $name) = @_;
    my ($ref, $deposit);

    $ref = $snapshot->get_file($name);
    if (!defined($ref)) {
	notify(WARN, IUCONT, $self->__snaproot() . '/' . $snapshot->path()
	       . '->' . $name, undef);
	return 0;
    }

    $deposit = $self->deposit();
    $deposit->put($ref);

    return 1;
}

sub __delete_ref_directory
{
    my ($self, $snapshot, $name) = @_;
    my $sep = ($name eq '/') ? '' : '/';
    my ($entries, $sum, $entry);

    $sum = 0;
    $entries = $snapshot->get_directory($name);
    foreach $entry (@$entries) {
	$sum += $self->__delete_ref($snapshot, $name . $sep . $entry);
    }

    return $sum;
}

sub __delete_ref
{
    my ($self, $snapshot, $name) = @_;
    my ($properties, $mode, $entries);

    $properties = $snapshot->get_properties($name);
    if (!defined($properties)) {
	return 0;
    }

    $mode = $properties->{MODE};
    if (S_ISREG($mode) || S_ISLNK($mode)) {
	return $self->__delete_ref_file($snapshot, $name);
    } elsif (S_ISDIR($mode)) {
	return $self->__delete_ref_directory($snapshot, $name);
    } else {
	notify(WARN, IUMODE, $self->__snaproot() . '/'
	       . $snapshot->path() . '->' . $name, $mode);
	return 0;
    }
}

sub __delete
{
    my ($self, $path) = @_;
    my ($dh, $entry);

    if (-d $path && !(-l $path)) {
	if (!opendir($dh, $path)) {
	    return 0;
	}

	foreach $entry (grep { ! /^\.\.?$/ } readdir($dh)) {
	    $self->__delete($path . '/' . $entry);
	}

	closedir($dh);
	if (!rmdir($path)) {
	    return 0;
	}
    } else {
	if (!unlink($path)) {
	    return 0;
	}
    }

    return 1;
}

sub delete
{
    my ($self, $snapshot, @err) = @_;

    if (!defined($snapshot)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($snapshot) || !$snapshot->isa('Synctl::FileSnapshot')) {
	return throw(EINVLD, $snapshot);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    notify(INFO, IRDELET);
    $self->__delete_ref($snapshot, '/');

    notify(INFO, IFDELET, $snapshot->path());
    return $self->__delete($snapshot->path());
}


1;
__END__
