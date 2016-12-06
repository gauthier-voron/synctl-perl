#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::MockDeposit;
use t::Snapshot;
use Synctl::File;
use Synctl::FileControler;

use Test::More tests => 3 + test_snapshot_count() * 2;

BEGIN
{
    use_ok('Synctl::Ssh::1::1::Controler');
    use_ok('Synctl::Ssh::1::1::Server');
    use_ok('Synctl::Ssh::1::1::Snapshot');
}


my (@pids);
my (@snapshots);
my (@pipes);


sub mkserver
{
    my ($parent_in, $child_out);
    my ($parent_out, $child_in);
    my ($pid, $server, $controler);
    my $box = mktroot();
    my $path = $box . '/deposit';
    my $deposit = Synctl::File->deposit($path);
    my $snapshot;

    $controler = Synctl::FileControler->new($deposit, $box);
    $snapshot = $controler->create();

    if (!pipe($parent_in, $child_out)) { die ($!); }
    if (!pipe($child_in, $parent_out)) { die ($!); }

    if (($pid = fork()) == 0) {
	close($child_in);
	close($child_out);

	# Disable the testing for the child process so we aren't annoyed by
	# unwanted output or warning for unexpected termination

	Test::More->builder()->no_ending(1);

	$server = Synctl::Ssh::1::1::Server->new
	    ($parent_in, $parent_out, $controler);
	$server->serve();
	exit (0);
    } else {
	close($parent_in);
	close($parent_out);

	# Set a handler to avoid the test script to be blocked indefinitely
	# on communication

	$SIG{ALRM} = sub {
	    diag("Timeout fired. All remaining tests fail.");
	    kill('KILL', $pid);
	    die (255);
	};

	$controler = Synctl::Ssh::1::1::Controler->new($child_in, $child_out);

	push(@pids, $pid);
	push(@snapshots, $snapshot);
	push(@pipes, $child_in, $child_out);

	return $controler;
    }
}

sub waitservers
{
    my ($pid, $fh);

    foreach $fh (@pipes) {
	close($fh);
    }

    foreach $pid (@pids) {
	waitpid($pid, 0);
    }

    @pids = ();
    @pipes = ();
}


sub alloc
{
    my (@specs) = @_;
    my ($box, $snapshot, $spec);
    my ($path, $type, $content, $props, @rem);
    my $controler;

    $controler = mkserver();
    $snapshot = pop(@snapshots);
    $snapshot->init();

    foreach $spec (@specs) {
	($path, $type, @rem) = @$spec;

	if ($type eq 'f') {
	    ($content, $props) = @rem;
	    $snapshot->set_file($path, $content, %$props);
	} elsif ($type eq 'd') {
	    ($props) = @rem;
	    $snapshot->set_directory($path, %$props);
	}
    }

    $snapshot->flush();
    push(@snapshots, $snapshot);

    $snapshot = ($controler->snapshot())[0];
    return $snapshot;
}

sub check_properties
{
    my ($a, $b) = @_;
    my ($key, $value);

    if (!defined($a) || !defined($b) ||
	ref($a) ne 'HASH' || ref($b) ne 'HASH') {
	return 0;
    }

    if (scalar(keys(%$a)) != scalar(keys(%$b))) {
	return 0;
    }

    foreach $key (keys(%$a)) {
	$value = $b->{$key};

	if (!defined($value)) {
	    return 0;
	}

	if ($value ne $a->{$key}) {
	    return 0;
	}
    }

    return 1;
}

sub check_entry_count
{
    my ($snapshot, $root) = @_;
    my ($count, $list, $elem, $sep);

    if (!defined($root)) {
	$root = '/';
    }

    if ($root eq '/') {
	$sep  = '';
    } else {
	$sep = '/';
    }

    if ($snapshot->get_properties($root)) {
	$count = 1;
    } else {
	return 0;
    }

    $list = $snapshot->get_directory($root);
    if (defined($list)) {
	foreach $elem (@$list) {
	    $count += check_entry_count($snapshot, $root . $sep . $elem);
	}
    }

    return $count;
}

sub check
{
    my ($snapshot, @specs) = @_;
    my ($spec, $path, $type, $content, $props, @rem);
    my (@checked, $sprops, $size);

    $snapshot->flush();
    $snapshot = pop(@snapshots);

    foreach $spec (@specs) {
	($path, $type, @rem) = @$spec;
	push(@checked, $path);

	if ($type eq 'f') {
	    ($content, $props) = @rem;

	    if ($snapshot->get_file($path) ne $content) {
		is($snapshot->get_file($path), $content, 'snapshot content');
		return;
	    }
	} elsif ($type eq 'd') {
	    ($props) = @rem;

	    $sprops = $snapshot->get_properties($path);
	    if (!check_properties($props, $sprops)) {
		is_deeply($props, $sprops, 'snapshot content');
		return;
	    }
	}
    }

    $size = check_entry_count($snapshot);
    if (scalar(@checked) != $size) {
	is(scalar(@checked), $size, 'snapshot content');
	return;
    }

    is(1, 1, 'snapshot content');
}


alarm(3);

test_snapshot(\&alloc, \&check);

test_snapshot(sub { my $t = alloc(@_); $t->load(); return $t; }, \&check);

waitservers();


1;
__END__
