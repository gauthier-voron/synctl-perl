#!/usr/bin/perl -l
# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Synctl.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 68;

use t::File;


BEGIN
{
    use_ok('Synctl');
}


my $box;
my $controler;
my ($props, $snapshot);
my ($pid, $ssh, @cmd);


# Synctl::Configure(ERROR => sub { print join(', ', map { if (!defined($_)) { '<undef>' } else { $_ } } @_); });
Synctl::Configure(ERROR => sub {});

if (($pid = fork()) == 0) {
    open(STDERR, '>', '/dev/null');
    exec ('ssh', '-o', 'PasswordAuthentication=no', 'localhost', 'exit');
    exit (1);
} else {
    waitpid($pid, 0);
    if ($? >> 8) {
	$ssh = 0;
    } else {
	$ssh = 1;
    }
}


$box = mktroot();
mktdir($box . '/empty');
mktdir($box . '/prefixed-empty');
mktdir($box . '/not-empty');
mktfile($box . '/not-empty/foo');
mktdir($box . '/prefixed-not-empty');
mktfile($box . '/prefixed-not-empty/foo');

is(Synctl::init(), undef, 'init with no argument');
is(Synctl::init(undef), undef, 'init with undef location');
is(Synctl::init($box . '/not', 'toto'), undef, 'init with too many arguments');
is(Synctl::init(''), undef, 'init with no location');
ok(Synctl::init($box . '/new'), 'init with new location');
ok(Synctl::init($box . '/empty'), 'init with empty location');
is(Synctl::init($box . '/not-empty'), undef, 'init with not empty location');

is(Synctl::init('file://'), undef, 'init with prefixed no location');
ok(Synctl::init('file://' . $box . '/prefixed-new'),
    'init with prefixed new location');
ok(Synctl::init('file://' . $box . '/prefixed-empty'),
    'init with prefixed empty location');
is(Synctl::init($box . '/prefixed-not-empty'), undef,
   'init with prefixed not empty location');


$box = mktroot();
mktdir($box . '/empty');
mktdir($box . '/prefixed-empty');
mktdir($box . '/not-empty');
mktfile($box . '/not-empty/foo');
mktdir($box . '/initialized');
Synctl::init($box . '/initialized');

is(Synctl::controler(), undef, 'controler with no argument');
is(Synctl::controler(undef), undef, 'controler with undef location');
is(Synctl::controler($box . '/not', 'toto'), undef,
   'controler with too many arguments');
is(Synctl::controler(''), undef,
   'controler with no location');
is(Synctl::controler($box . '/new'), undef, 'controler with new location');
is(Synctl::controler($box . '/empty'), undef, 'controler with empty location');
is(Synctl::controler($box . '/not-empty'), undef,
   'controler with not empty location');
ok(Synctl::controler($box . '/initialized'),
   'controler with initialized location');

is(Synctl::controler('foo://' . $box . '/initialized'), undef,
   'controler with wrong type location');

is(Synctl::controler('file://'), undef,
   'controler with file no location');
is(Synctl::controler('file://' . $box . '/new'), undef,
   'controler with file new location');
is(Synctl::controler('file://' . $box . '/empty'), undef,
   'controler with file empty location');
is(Synctl::controler('file://' . $box . '/not-empty'), undef,
   'controler with file not empty location');
ok(Synctl::controler('file://' . $box . '/initialized'),
   'controler with file initialized location');

 SKIP: {
     skip 'no local ssh server', 7 if !$ssh;

     @cmd = ('perl', ( map { "-I$_" } @INC ), '-MSynctl', '-e',
	     "'exit Synctl::serve(Synctl::controler(shift(@ARGV)))'");

     is(Synctl::controler('ssh://', RCOMMAND => \@cmd), undef,
	'controler with ssh no host');
     is(Synctl::controler('ssh://localhost', RCOMMAND => \@cmd), undef,
	'controler with ssh no location');
     is(Synctl::controler('ssh://localhost:', RCOMMAND => \@cmd), undef,
	'controler with ssh empty location');
     is(Synctl::controler('ssh://localhost:' . $box . '/new',
			  RCOMMAND => \@cmd), undef,
	'controler with ssh new location');
     is(Synctl::controler('ssh://localhost:' . $box . '/empty',
			  RCOMMAND => \@cmd), undef,
	'controler with ssh empty location');
     is(Synctl::controler('ssh://localhost:' . $box . '/not-empty',
			  RCOMMAND => \@cmd), undef,
	'controler with ssh not empty location');
     ok(Synctl::controler('ssh://localhost:' . $box . '/initialized',
			  RCOMMAND => \@cmd),
	'controler with ssh initialized location');
}


$box = mktroot();
mktdir($box . '/controler');
mktdir($box . '/files');
mktdir($box . '/files/dir');
mktfile($box . '/files/file');
mktlink($box . '/files/link', 'file');
$controler = Synctl::init($box . '/controler');

is(Synctl::send(undef, $controler), undef, 'send with no path');
is(Synctl::send('', $controler), undef, 'send with empty path');
is(Synctl::send($box . '/files'), undef, 'send with no controler');
is(Synctl::send($box . '/files', $controler, ''), undef,
   'send with invalid filter');

is(Synctl::send($box . '/files', $controler), 0,
   'send complete with no filter');
is(scalar($controler->snapshot()), 1,
   'send complete with no filter - snapshot created');
is(scalar(@{($controler->snapshot())[0]->get_directory('/')}), 3,
   'send complete with no filter - snapshot content');

is(Synctl::send($box . '/files', $controler), 0,
   'send incremental with no filter');
is(scalar($controler->snapshot()), 2,
   'send incremental with no filter - snapshot created');

is(Synctl::send($box . '/files', $controler, sub { $_ ne '/link' }), 0,
   'send incremental with filter');
is(scalar($controler->snapshot()), 3,
   'send incremental with filter - snapshot created');
is(scalar(grep { $_->get_file('/link') } $controler->snapshot()), 2,
   'send incremental with filter - snapshot content');


$box = mktroot();
mktdir($box . '/controler');
$controler = Synctl::init($box . '/controler');
foreach $props (['2013', '01', '/file'], ['2015', '01'], ['2015', '02'],
		['2016', '01', '/file'], ['2016', '02']) {
    $snapshot = $controler->create();
    
    # implementation specific, may break
    $snapshot->_date($props->[0] . ('-' . $props->[1]) x 5 . '-' .
		     $props->[1] x 16);
    
    $snapshot->set_directory('/');
    
    if (defined($props->[2])) {
	$snapshot->set_file($props->[2], $props->[2]);
    }
}

is(Synctl::list(), undef, 'list with no controler');
is(Synctl::list('foo'), undef, 'list with bad controler');
is(scalar(Synctl::list($controler)), 5, 'list with no filter');
is(scalar(Synctl::list($controler, '2015')), 3, 'list with date filter');
is(scalar(Synctl::list($controler, '/file')), 2, 'list with file filter');
is(Synctl::list($controler, 'foo'), undef, 'list with bad filter');
is(Synctl::list($controler, '2015', '2015'), undef,
   'list with too many arguments');


$box = mktroot();
mktdir($box . '/controler');
mktdir($box . '/sent');
mktfile($box . '/sent/file');
mktdir($box . '/sent/dir');
mktlink($box . '/sent/link', 'file');
mktdir($box . '/recv0');
mktfile($box . '/recv0/nfile');
mktdir($box . '/recv1');
mktfile($box . '/recv1/nfile');
mktdir($box . '/recv2');
mktfile($box . '/recv2/nfile');
$controler = Synctl::init($box . '/controler');
Synctl::send($box . '/sent', $controler);
$snapshot = (Synctl::list($controler))[-1];


is(Synctl::recv(undef, $snapshot, $box . '/recv0'), undef,
   'recv with no controler');
is(Synctl::recv('foo', $snapshot, $box . '/recv0'), undef,
   'recv with bad controler');
is(Synctl::recv($controler, undef, $box . '/recv0'), undef,
   'recv with no snapshot');
is(Synctl::recv($controler, '', $box . '/recv0'), undef, 
   'recv with bad snapshot');
is(Synctl::recv($controler, $snapshot), undef, 'recv with no path');
is(Synctl::recv($controler, $snapshot, ''), undef,
   'recv with empty path');
is(Synctl::recv($controler, $snapshot, $box . '/recv0', 'foo'), undef,
   'recv with bad filter');
is(Synctl::recv($controler, $snapshot, $box . '/recv0', sub { 1; }, 'foo'),
   undef, 'recv with too many arguments');

is(Synctl::recv($controler, $snapshot, $box . '/recv0'), 0,
   'recv with no filter');
ok(-f $box . '/recv0/file' &&
   -d $box . '/recv0/dir'  &&
   -l $box . '/recv0/link' &&
   !(-e $box . '/recv0/nfile'), 'recv with no filter - content');

is(Synctl::recv($controler, $snapshot, $box . '/recv1',
		sub { $_ ne '/file' } ), 0, 'recv with filter on server');
ok(!(-e $box . '/recv1/file') &&
   -d $box . '/recv1/dir'  &&
   -l $box . '/recv1/link' &&
   !(-e $box . '/recv1/nfile'), 'recv with filter on server - content');

is(Synctl::recv($controler, $snapshot, $box . '/recv2',
		sub { $_ ne '/nfile' } ), 0, 'recv with filter on client');
ok(-f $box . '/recv2/file'  &&
   -d $box . '/recv2/dir'  &&
   -l $box . '/recv2/link' &&
   -f $box . '/recv2/nfile', 'recv with filter on client - content');

is(Synctl::recv($controler, $snapshot, $box . '/recv3'), 0,
   'recv on unexisting directory');
ok(-f $box . '/recv3/file' &&
   -d $box . '/recv3/dir'  &&
   -l $box . '/recv3/link' &&
   !(-e $box . '/recv3/nfile'), 'recv on unexisting directory - content');


1;
__END__
