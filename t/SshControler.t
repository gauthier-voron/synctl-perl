#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::MockDeposit;
use Synctl::FileControler;
use Synctl::SshProtocol;
use Synctl::SshServer;


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

use t::Controler;

use Test::More tests => 2 + test_controler_count();

BEGIN
{
    use_ok('Synctl::SshControler');
}


sub serve
{
    my ($in, $out) = @_;
    my $box = mktroot();
    my $deposit = t::MockDeposit->new('', {}, {}, {});
    my $connection = Synctl::SshProtocol->connect($in, $out);
    my $controler = Synctl::FileControler->new($deposit, $box);
    my $server = Synctl::SshServer->new($connection, $controler);

    $server->serve();
    return 0;
}


my $connection = Synctl::SshProtocol->connect($child_in, $child_out);
my $controler = Synctl::SshControler->new($connection);


ok($controler, 'controler initialization');


local $SIG{ALRM} = sub {
    diag("Timeout fired. All remaining tests fail.");
    kill('KILL', $pid);
    die (255);
};
alarm(3);

test_controler($controler);

$connection->send('exit');
waitpid($pid, 0);


1;
__END__
