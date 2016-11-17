#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 30;


BEGIN
{
    use_ok('Synctl::SshConnection');
}


my ($ascal, $asub, $bscal, $ret, @arr);
my ($stag, $rtag, @args);
my ($ain, $aout, $bin, $bout);
my ($acon, $bcon, $pid);

if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }


ok($acon = Synctl::SshConnection->new($ain, $aout), 'create connection');


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

$acon = Synctl::SshConnection->new($ain, $aout);

$asub = sub { 1; };
$ret = $acon->recv('taga', $asub);
ok(defined($ret) && !$ret, 'recv taga');

$ret = $acon->recv('tagb', sub { 2; });
ok(defined($ret) && !$ret, 'recv tagb');

$ret = $acon->recv('taga', sub { 3; });
is($ret, $asub, 'recv taga (replace)');

$ret = $acon->recv('tagc', undef);
ok(defined($ret) && !$ret, 'recv tagc (erase none)');

$asub = sub { 4; };
$ret = $acon->recv('tagc', $asub);
ok(defined($ret) && !$ret, 'recv tagc');

$ret = $acon->recv('tagc', undef);
is($ret, $asub, 'recv tagc (erase)');


local $SIG{ALRM} = sub {
    diag("Timeout fired. All remaining tests fail.");
    die (255);
};

alarm(3);


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

$acon = Synctl::SshConnection->new($ain, $aout);
$bcon = Synctl::SshConnection->new($bin, $bout);

$acon->recv('taga', sub { $ascal = 1; return 0; });

$ascal = 0;  $bcon->send('taga');  $acon->wait('taga');
is($ascal, 1, 'taga reception (once)');

$ascal = 0;  $bcon->send('taga');  $acon->wait('taga');
is($ascal, 0, 'taga self deletion');

$acon->recv('taga', sub { $ascal = 1; return 1; });

$ascal = 0;  $bcon->send('taga');  $acon->wait('taga');
is($ascal, 1, 'taga first reception');

$ascal = 0;  $bcon->send('taga');  $acon->wait('taga');
is($ascal, 1, 'taga second reception');

$ascal = 0;  $bcon->send('tagb'); $bcon->send('taga');  $acon->wait('taga');
is($ascal, 1, 'unwanted tags ignored');


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

$acon = Synctl::SshConnection->new($ain, $aout);
$bcon = Synctl::SshConnection->new($bin, $bout);

$acon->recv('taga', sub { ($stag, $rtag, @args) = @_; return 0; });
$bcon->send('taga', 'tagb', 'scal', [ 'arr', 'ay' ]);  $acon->wait('taga');
is($stag, 'taga', 'reception stag');
is($rtag, 'tagb', 'reception rtag');
is_deeply(\@args, [ 'scal', [ 'arr', 'ay' ] ], 'reception payload');


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

$acon = Synctl::SshConnection->new($ain, $aout);
$bcon = Synctl::SshConnection->new($bin, $bout);

$acon->recv('taga', sub { $ascal++; return 1; });
$acon->recv('tagb', sub { $bscal++; return 1; });
$acon->recv('tagc', sub {           return 1; });

$ascal = 0;
$bcon->send('taga');
$acon->wait('taga');
is($ascal, 1, 'wait on specific tag');

$ascal = 0;
$bcon->send('taga'); $bcon->send('tagc');
$acon->wait('tagc');
is($ascal, 1, 'wait on other tag');

$ascal = 0;
$bcon->send('taga'); $bcon->send('taga'); $bcon->send('tagc');
$acon->wait('tagc');
is($ascal, 2, 'wait on other tag several times');

$ascal = 0;
$bcon->send('taga'); $bcon->send('taga'); $bcon->send('tagc');
$acon->wait('taga');
is($ascal, 1, 'wait on specific tag several times (time 1)');
$acon->wait('taga'); $acon->wait('tagc');
is($ascal, 2, 'wait on specific tag several times (time 2)');

$ascal = 0;
$bcon->send('taga'); $bcon->send('tagc'); $bcon->send('taga');
$acon->wait();
is($ascal, 1, 'wait on any tag (time 1)');
$acon->wait();
is($ascal, 1, 'wait on any tag (time 2)');
$acon->wait();
is($ascal, 2, 'wait on any tag (time 3)');

$ascal = 0;
$bscal = 0;
$bcon->send('taga'); $bcon->send('taga');
$bcon->send('tagb');
$bcon->send('taga');
$bcon->send('tagc');
$acon->wait('tagc');
is($ascal, 3, 'wait on other tag flush a');
is($bscal, 1, 'wait on other tag flush b');


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

$acon = Synctl::SshConnection->new($ain, $aout);
$bcon = Synctl::SshConnection->new($bin, $bout);

$bcon->recv('taga', sub {
    my ($st, $rt, $scal) = @_;
    $bcon->send($rt, undef, $scal + 1);
    $bcon->send($rt, undef, $scal + 2);
    $bcon->send($rt, undef, $scal + 3);
    return 1;
});

@arr = ();
$asub = sub {
    my ($st, $rt, $scal) = @_;
    push(@arr, $scal);
    return 1;
};

$acon->talk('taga', $asub, 42);
$bcon->wait();
$acon->wait() foreach (1, 2, 3);

is_deeply(\@arr, [ 43, 44, 45 ], 'talk several replies');


close($ain); close($aout); close($bin); close($bout);
if (!pipe($ain, $bout)) { die ($!); }
if (!pipe($bin, $aout)) { die ($!); }

if (($pid = fork()) == 0) {
    Test::More->builder()->no_ending(1);
    close($ain); close($aout);
    
    $bcon = Synctl::SshConnection->new($bin, $bout);

    $bcon->recv('taga', sub {
	my ($st, $rt, $scal) = @_;
	$bcon->send($rt, undef, $scal + 1);
	return 1;
    });

    $bcon->recv('tagb', sub {
	my ($st, $rt, $scal) = @_;
	$bcon->send('tagc', undef, 42);
	$bcon->send($rt, undef, $scal + 2);
	return 1;
    });

    $bcon->wait('tagb');
    exit (0);
}

$acon = Synctl::SshConnection->new($ain, $aout);

$asub = sub {
    ($_, $_, @arr) = @_;
};

$acon->recv('tagc', $asub);

$ascal = $acon->call('taga', 23);
is($ascal, 24, 'call taga return');

@arr = ();
$ascal = $acon->call('tagb', 23);
is($ascal, 25, 'call tagb return');
is_deeply(\@arr, [ 42 ], 'call tagb side effect');


waitpid($pid, 0);


1;
__END__
