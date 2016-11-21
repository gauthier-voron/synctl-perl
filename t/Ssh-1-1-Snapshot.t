#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::MockDeposit;
use Synctl::FileControler;


# Fake ssh server creation
# Using an actual ssh link is difficult to achieve in a portable way. Instead,
# use a subprocess with a bidirectional link (two pipes) to emulate an
# ssh connection and run a ssh server inside.

my $pid;
my ($parent_in, $child_out);
my ($parent_out, $child_in);

if (!pipe($parent_in, $child_out)) { die ($!); }
if (!pipe($child_in, $parent_out)) { die ($!); }

if (($pid = fork()) == 0) {
    close($child_in);
    close($child_out);

    exit (serve($parent_in, $parent_out));
} else {
    close($parent_in);
    close($parent_out);
}


# Now the child process is launched, we can setup the test environment and
# import test only packages.

use t::Snapshot;

use Test::More tests => 4 + test_snapshot_count();

BEGIN
{
    use_ok('Synctl::Ssh::1::1::Controler');
    use_ok('Synctl::Ssh::1::1::Server');
    use_ok('Synctl::Ssh::1::1::Snapshot');
}


sub serve
{
    my ($in, $out) = @_;
    my $box = mktroot();
    my $deposit = t::MockDeposit->new('', {}, {}, {});
    my $controler = Synctl::FileControler->new($deposit, $box);
    my $server = Synctl::Ssh::1::1::Server->new($in, $out, $controler);

    $server->serve();
    return 0;
}

local $SIG{ALRM} = sub {
    diag("Timeout fired. All remaining tests fail.");
    kill('KILL', $pid);
    die (255);
};

alarm(3);


my $controler = Synctl::Ssh::1::1::Controler->new($child_in, $child_out);
my $snapshot = $controler->create();

ok($snapshot, 'snapshot instanciation');

test_snapshot($snapshot);

$controler = undef;
waitpid($pid, 0);


1;
__END__
