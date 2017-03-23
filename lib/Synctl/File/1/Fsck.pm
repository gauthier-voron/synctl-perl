package Synctl::File::1::Fsck;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Scalar::Util qw(blessed);

use Synctl qw(:error :verbose);


sub _deposit   { return shift()->_rw('__deposit', @_); }
sub _snapshots { return shift()->_rw('__snapshots', @_); }


sub _new
{
    my ($self, $deposit, @snapshots) = @_;
    my ($snapshot);

    if (!defined($deposit)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($deposit) ||
	     !$deposit->isa('Synctl::File::1::Deposit')) {
	return throw(EINVLD, $deposit);
    } elsif (!defined($self->SUPER::_new())) {
	return undef;
    }

    foreach $snapshot (@snapshots) {
	if (!blessed($snapshot) ||
	    !$snapshot->isa('Synctl::File::1::Snapshot')) {
	    return throw(EINVLD, $snapshot);
	}
    }

    $self->_deposit($deposit);
    $self->_snapshots([ @snapshots ]);

    return $self;
}


sub checkup
{
    my ($self, @err) = @_;
    my (%references, %refcounts, %backrefs, $snapshot, $hash, $invalidate);
    my ($ret, $unfixed);

    $unfixed = 0;

    foreach $snapshot (@{$self->_snapshots()}) {
	%references = ();

	$ret = $snapshot->checkup(\%references);
	if (!defined($ret)) {
	    return undef;
	}

	if (@$ret) {
	    $unfixed = 1;
	    $snapshot->sane(0);
	} else {
	    $snapshot->sane(1);
	}

	foreach $hash (keys(%references)) {
	    push(@{$backrefs{$hash}}, $snapshot);
	    $refcounts{$hash} += $references{$hash};
	}
    }

    $ret = $self->_deposit()->checkup(\%refcounts);
    if (!defined($ret)) {
	return undef;
    }

    if (@$ret) {
	$unfixed = 1;
    }

    foreach $hash (@$ret) {
	$invalidate = $backrefs{$hash};
	if (!defined($invalidate)) {
	    next;
	}

	foreach $snapshot (@$invalidate) {
	    $snapshot->sane(0);
	}
    }

    return $unfixed;
}


1;
__END__
