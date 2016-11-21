#!/usr/bin/perl -l

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Test::More tests => 25;

use Synctl::FileControler;

use t::File;
use t::MockDeposit;


BEGIN
{
    use_ok('Synctl::Ssh');
}


my ($ain, $aout, $bin, $bout);
my ($server, $box, $msg, $controler);


$box = mktroot();

if (!pipe($ain, $bout)) { die ($!); }
$bout->autoflush(1);


local $SIG{ALRM} = sub {
    diag("Timeout fired. All remaining tests fail.");
    die (255);
};

alarm(3);


# Client side

if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '1.1     ');
$controler = Synctl::Ssh->controler($ain, $aout);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*1\.1\s*$/, 'controler negociation with 1.1');
is(length($msg), 16, 'controler negociation length with 1.1');
ok(defined($controler) && blessed($controler) &&
   $controler->isa('Synctl::Controler'), 'controler instance with 1.1');
$controler = undef;

if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '1.99    ');
$controler = Synctl::Ssh->controler($ain, $aout);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*1\.(\d+)\s*$/,
     'controler negociation with 1.99');
is(length($msg), 16, 'controler negociation length with 1.99');
ok(defined($controler) && blessed($controler) &&
   $controler->isa('Synctl::Controler'), 'controler instance with 1.99');
$controler = undef;

if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '99.1    ');
$controler = Synctl::Ssh->controler($ain, $aout);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'controler negociation with 99.1');
is(length($msg), 8, 'controler negociation length with 99.1');
is($controler, undef, 'controler instance with 99.1');
$controler = undef;


# Server side

$controler = Synctl::FileControler->new(t::MockDeposit->new(), $box);

if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '1.1     1.1     ');
$server = Synctl::Ssh->server($ain, $aout, $controler);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'server negociation with 1.1 + 1.1');
is(length($msg), 8, 'server negociation length with 1.1 + 1.1');
ok(defined($server) && blessed($server) && $server->isa('Synctl::SshServer'),
   'server instance with 1.1 + 1.1');


if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '1.99    1.1     ');
$server = Synctl::Ssh->server($ain, $aout, $controler);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'server negociation with 1.99 + 1.1');
is(length($msg), 8, 'server negociation length with 1.99 + 1.1');
ok(defined($server) && blessed($server) && $server->isa('Synctl::SshServer'),
   'server instance with 1.99 + 1.1');


if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '99.1    1.1     ');
$server = Synctl::Ssh->server($ain, $aout, $controler);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'server negociation with 99.1 + 1.1');
is(length($msg), 8, 'server negociation length with 99.1 + 1.1');
ok(defined($server) && blessed($server) && $server->isa('Synctl::SshServer'),
   'server instance with 99.1 + 1.1');


if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '99.1    99.1    ');
$server = Synctl::Ssh->server($ain, $aout, $controler);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'server negociation with 99.1 + 99.1');
is(length($msg), 8, 'server negociation length with 99.1 + 99.1');
is($server, undef, 'server instance with 99.1 + 99.1');


if (!open($aout, '>', $box . 'output')) { die ($!); }
if (!open($bin, '<', $box . 'output')) { die ($!); }
printf($bout '99.1    ');
close($bout);
$server = Synctl::Ssh->server($ain, $aout, $controler);
$msg = <$bin>;
like($msg, qr/^(\d+)\.(\d+)\s*$/, 'server negociation with 99.1');
is(length($msg), 8, 'server negociation length with 99.1');
is($server, undef, 'server instance with 99.1');


1;
__END__
