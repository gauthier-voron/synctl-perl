package Synctl::FileControler;

use parent qw(Synctl::Controler);
use strict;
use warnings;

use Carp;
use Digest::MD5 qw(md5_hex);

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
    my ($root, @ret, $snapshot, $dh, $elem);

    if (@err) { confess('unexpected argument'); }

    $root = $self->__snaproot();
    
    if (!opendir($dh, $root)) {
	return undef;
    }

    foreach $elem (readdir($dh)) {
	$snapshot = Synctl::FileSnapshot->new($root . '/' . $elem);
	
	next if (!defined($snapshot->date()));
	
	push(@ret, $snapshot);
    }

    closedir($dh);
    return @ret;
}

sub create
{
    my ($self, @err) = @_;
    my ($date, $path, $root, $snapshot);

    if (@err) { confess('unexpected argument'); }

    $path = md5_hex(rand(1 << 32));

    $root = $self->__snaproot();
    $snapshot = Synctl::FileSnapshot->new($root . '/' . $path);
    $snapshot->init();

    $date = $snapshot->date();
    if (!rename($root . '/' . $path, $root . '/' . $date)) {
	return undef;
    } else {
	return Synctl::FileSnapshot->new($root . '/' . $date);
    }
}

sub delete
{
    my ($self, $date, @err) = @_;
    my ($root, $snapshot);

    if (@err) { confess('unexpected argument'); }
    if (!defined($date)) { confess('missing argument'); }

    confess('not yet implemented');
}


1;
__END__
