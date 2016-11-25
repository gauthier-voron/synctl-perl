#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use Synctl;
use Synctl::FileControler;
use Synctl::FileDeposit;
use Synctl::Ssh::1::1::Controler;
use Synctl::Ssh::1::1::Server;

use t::Deposit;

use Test::More tests => 5 + test_deposit_count();


my @pids;
my @deposits;


# Fake ssh server creation
# Using an actual ssh link is difficult to achieve in a portable way. Instead,
# use a subprocess with a bidirectional link (two pipes) to emulate an
# ssh connection and run a ssh server inside.

sub mkserver
{
    my ($parent_in, $child_out);
    my ($parent_out, $child_in);
    my ($pid, $server, $controler);
    my $box = mktroot();
    my $path = $box . '/deposit';
    my $deposit = Synctl::FileDeposit->new($path);

    if (!pipe($parent_in, $child_out)) { die ($!); }
    if (!pipe($child_in, $parent_out)) { die ($!); }

    if (($pid = fork()) == 0) {
	close($child_in);
	close($child_out);

	# Disable the testing for the child process so we aren't annoyed by
	# unwanted output or warning for unexpected termination

	Test::More->builder()->no_ending(1);

	$controler = Synctl::FileControler->new($deposit, $box);
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
	push(@deposits, $deposit);

	return $controler;
    }
}

sub waitservers
{
    my $pid;

    foreach $pid (@pids) {
	waitpid($pid, 0);
    }
}


sub alloc
{
    my (@contents) = @_;
    my $controler = mkserver();
    my ($deposit, $content, @refs, $fdeposit);

    $fdeposit = pop(@deposits);
    $fdeposit->init();

    foreach $content (@contents) {
	push(@refs, $fdeposit->send($content));
    }

    push(@deposits, $fdeposit);
    $deposit = $controler->deposit();

    if (wantarray()) {
	return ($deposit, @refs);
    } else {
	return $deposit;
    }
}

sub check
{
    my ($deposit, %refs) = @_;
    my ($ref, $count, $ok, $hash);

    $deposit = pop(@deposits);

    $ok = 1;
    foreach $ref (keys(%refs)) {
	$count = $refs{$ref} + 1;
	$hash = $deposit->send($ref);

	while (defined($deposit->put($hash))) {
	    $count--;
	}

	if ($count != 0) {
	    is($refs{$ref} - $count, $refs{$ref}, 'deposit content');
	    return 0;
	}
    }

    ok(1, 'deposit content');

    return 1;
}


my $controler = mkserver();
my $deposit = $controler->deposit();
my $eviltwin = $controler->deposit();

alarm(3);  # Terminate testing after 3 seconds

ok($deposit, 'deposit instanciation');
ok($eviltwin, 'eviltwin instanciation');

ok($deposit->init(), 'init from nothing');
ok(!$deposit->init(), 'init on existing (same object)');
ok(!$eviltwin->init(), 'init on existing (different object)');

pop(@deposits);
$deposit = undef;
$eviltwin = undef;
$controler = undef;


test_deposit(\&alloc, \&check);

waitservers();

1;
__END__
