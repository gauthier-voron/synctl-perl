package Synctl::File::1::Fsck;

use parent qw(Synctl::Fsck);
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


sub __partial_dir
{
    my ($self) = @_;
    my $deposit = $self->_deposit();

    return $deposit->path() . '/fsck-partial';
}


sub __save_partial
{
    my ($self, $snapshot, $references) = @_;
    my ($fh, $hash, $count, $path);

    $path = $self->__partial_dir() . '/' . $snapshot->id();

    if (!open($fh, '>', $path)) {
	return throw(ESYS, $!, $path);
    }

    foreach $hash (keys(%$references)) {
	$count = $references->{$hash};
	printf($fh "%s%d\n", $hash, $count);
    }

    close($fh);
    return 1;
}

sub __exist_partial
{
    my ($self, $snapshot) = @_;
    my $path = $self->__partial_dir() . '/' . $snapshot->id();

    if (-e $path) {
	return 1;
    } else {
	return 0;
    }
}

sub __load_partials
{
    my ($self, $refcounts, $backrefs) = @_;
    my ($dh, $fh, $path, $id, $line, $hash, $count);
    my ($snapshot, %snapshots);

    $path = $self->__partial_dir();
    if (!opendir($dh, $path)) {
	return throw(ESYS, $!, $path);
    }

    foreach $snapshot (@{$self->_snapshots()}) {
	$snapshots{$snapshot->id()} = $snapshot;
    }

    foreach $id (grep { /^[0-9a-f]{32}$/ } readdir($dh)) {
	if (!open($fh, '<', $path . '/' . $id)) {
	    closedir($dh);
	    return throw(ESYS, $!, $path . '/' . $id);
	}

	while (defined($line = <$fh>)) {
	    chomp($line);
	    $hash = substr($line, 0, 32);
	    $count = substr($line, 32);

	    push(@{$backrefs->{$hash}}, $snapshots{$id});
	    $refcounts->{$hash} += $count;
	}

	close($fh);
    }

    closedir($dh);
    return 1;
}

sub __clean_partials
{
    my ($self) = @_;
    my ($dh, $path, $id);

    $path = $self->__partial_dir;
    if (!opendir($dh, $path)) {
	return throw(ESYS, $!, $path);
    }

    foreach $id (grep { /^[0-9a-f]{32}$/ } readdir($dh)) {
	if (!unlink($path . '/' . $id)) {
	    closedir($dh);
	    return throw(ESYS, $!, $path . '/' . $id);
	}
    }

    close($dh);

    if (!rmdir($path)) {
	return throw(ESYS, $!, $path);
    }

    return 1;
}


sub __checkup_snapshot
{
    my ($self, $snapshot, $references) = @_;
    my ($ret, $unfixed);

    notify(INFO, ISCHECK, $snapshot->id());
    $ret = $snapshot->checkup($references);
    if (!defined($ret)) {
	return undef;
    }

    if (@$ret) {
	notify(WARN, ISCORPT, $snapshot->id());
	$unfixed = 1;
	$snapshot->sane(0);
    } else {
	$unfixed = 0;
	$snapshot->sane(1);
    }

    return $unfixed;
}

sub __checkup_snapshots_partial
{
    my ($self, $refcounts, $backrefs) = @_;
    my ($snapshot, %references, $unfixed, $ret);

    $unfixed = 0;

    foreach $snapshot (@{$self->_snapshots()}) {
	if ($self->__exist_partial($snapshot)) {
	    next;
	}

	%references = ();
	$ret = $self->__checkup_snapshot($snapshot, \%references);

	if (!defined($ret)) {
	    return undef;
	} elsif ($ret == 1) {
	    $unfixed = 1;
	}

	if (!defined($self->__save_partial($snapshot, \%references))) {
	    return undef;
	}

	if ($self->_interrupted()) {
	    return $unfixed;
	}
    }

    if (!defined($self->__load_partials($refcounts, $backrefs))) {
	return undef;
    }

    return $unfixed
}

sub __checkup_snapshots_inmem
{
    my ($self, $refcounts, $backrefs) = @_;
    my ($snapshot, %references, $unfixed, $ret, $hash);

    $unfixed = 0;

    foreach $snapshot (@{$self->_snapshots()}) {
	%references = ();
	$ret = $self->__checkup_snapshot($snapshot, \%references);

	if (!defined($ret)) {
	    return undef;
	} elsif ($ret == 1) {
	    $unfixed = 1;
	}

	if ($self->_interrupted()) {
	    return $unfixed;
	}

	foreach $hash (keys(%references)) {
	    push(@{$backrefs->{$hash}}, $snapshot);
	    $refcounts->{$hash} += $references{$hash};
	}
    }

    return $unfixed;
}

sub _checkup
{
    my ($self) = @_;
    my (%refcounts, %backrefs, $snapshot, $hash, $invalidate);
    my ($ret, $unfixed, $partial, $partdir);

    $unfixed = 0;
    $partial = $self->partial();

    if ($partial) {
	if ($self->reset() && !defined($self->__clean_partials())) {
	    return undef;
	}

	$partdir = $self->__partial_dir();
	if (!(-e $partdir) && !mkdir($partdir)) {
	    return throw(ESYS, $!, $partdir);
	} elsif (!(-d $partdir) || !(-r $partdir) ||
		 !(-w $partdir) || !(-x $partdir)) {
	    return throw(EPERM, $partdir);
	}

	$unfixed = $self->__checkup_snapshots_partial(\%refcounts, \%backrefs);
    } else {
	$unfixed = $self->__checkup_snapshots_inmem(\%refcounts, \%backrefs);
    }

    if (!defined($unfixed)) {
	return undef;
    } elsif ($self->_interrupted()) {
	$self->_interrupted(0);
	return $unfixed;
    }

    notify(INFO, IDCHECK);
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
	    if ($snapshot->sane()) {
		notify(WARN, ISCORPT, $snapshot->id());
	    }
	    $snapshot->sane(0);
	}
    }

    if ($partial && !defined($self->__clean_partials())) {
	return undef;
    }

    return $unfixed;
}


1;
__END__
