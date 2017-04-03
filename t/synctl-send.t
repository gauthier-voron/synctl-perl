#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 97;

use t::File;

use Synctl;


$ENV{PATH} = './script:' . $ENV{PATH};


my $box = mktroot(NOTMP => 1);
my ($ret, $snapshot);
my (%properties, $path, $props, $profile);
my (@snapshots);


sub readfile
{
    my ($path) = @_;
    my ($fh, $ret);

    if (!open($fh, '<', $path)) {
	return undef;
    }

    local $/ = undef;
    $ret = <$fh>;

    close($ret);
    return $ret;
}

sub readrep
{
    my ($path) = @_;
    my ($dh, $ret);

    if (!opendir($dh, $path)) {
	return undef;
    }

    $ret = [ sort { $a cmp $b } grep { ! /^\.\.?$/ } readdir($dh) ];
    closedir($dh);

    return $ret;
}

sub snapshot
{
    my ($server, @snapshots) = @_;
    my @printed = split("\n", `synctl list --server=$server`);
    my $ret = $?;
    my $line;

    if ($ret != 0){
	return undef;
    }

    foreach $line (@printed){
	if ($line =~ /^([0-9a-f]{32})\s+.*$/) {
	    $line = $1;
	    if (!grep { $line eq $_ } @snapshots) {
		return $line;
	    }
	}
    }

    return undef;
}


mktdir($box . '/server');
mktdir($box . '/restored');

# Create origin version 1
mktdir($box . '/client1', MODE => 0755, TIME => 1);
mktfile($box . '/client1/file0', MODE => 0644, TIME => 1, CONTENT => '');
mktfile($box . '/client1/file1', MODE => 0644, TIME => 1, CONTENT => 'file1');
mktfile($box . '/client1/file2', MODE => 0755, TIME => 2, CONTENT => '');
mktdir ($box . '/client1/dir0',  MODE => 0755);
mktfile($box . '/client1/dir0/file0', MODE => 0644, TIME => 3, CONTENT => '');
mktlink($box . '/client1/dir0/link0', '../file1', TIME => 3);
mktlink($box . '/client1/link0', $box . '/client1/dir0', TIME => 4);
mktlink($box . '/client1/link1', $box . '/client1/unknown', TIME => 1);

# Create origin version 2
mktdir($box . '/client2', MODE => 0755, TIME => 1);
mktfile($box . '/client2/file1', MODE => 0644, TIME => 1, CONTENT => 'file1');
mktfile($box . '/client2/file2', MODE => 0755, TIME => 2, CONTENT => 'file2');
mktfile($box . '/client2/file3', MODE => 0666, TIME => 3, CONTENT => '');
mktdir ($box . '/client2/dir1',  MODE => 0755);
mktfile($box . '/client2/dir1/file0', MODE => 0644, TIME => 3, CONTENT => '');
mktlink($box . '/client2/dir1/link0', '../file1', TIME => 3);
mktlink($box . '/client2/link0', $box . '/client2/dir1', TIME => 4);
mktlink($box . '/client2/link1', $box . '/client2/unknown', TIME => 1);

sub is_version_1
{
    my ($box, $root, $msg) = @_;

    is_deeply([ (stat($root))[2] ], [ 040755 ],
	      $msg . ' version 1 / properties');
    is_deeply(readrep($root),
	      [ 'dir0', 'file0', 'file1', 'file2', 'link0', 'link1' ],
	      $msg . ' version 1 / content');

    is_deeply([ (stat($root . '/file0'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' version 1 /file0 properties');
    is(readfile($root . '/file0'), '', $msg . ' version 1 /file0 content');
    is_deeply([ (stat($root . '/file1'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' version 1 /file1 properties');
    is(readfile($root . '/file1'), 'file1',
       $msg . ' version 1 /file1 content');
    is_deeply([ (stat($root . '/file2'))[2, 9] ], [ 0100755, 2 ],
	      $msg . ' version 1 /file2 properties');
    is(readfile($root . '/file2'), '', $msg . ' version 1 /file2 content');

    is_deeply([ (stat($root . '/dir0'))[2] ], [ 040755 ],
	      $msg . ' version 1 /dir0 properties');
    is_deeply(readrep($root . '/dir0'),
	      [ 'file0', 'link0' ],
	      $msg . ' version 1 /dir0 content');

    is_deeply([ (stat($root . '/dir0/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' version 1 /dir0/file0 properties');
    is(readfile($root . '/dir0/file0'), '',
       $msg . ' version 1 /dir0/file0 content');
    is_deeply([ (lstat($root . '/dir0/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 1 /dir0/link0 properties');
    is(readlink($root . '/dir0/link0'), '../file1',
       $msg . ' version 1 /dir0/link0 content');

    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 1 /link0 properties');
    is(readlink($root . '/link0'), $box . '/client1/dir0',
       $msg . ' version 1 /link0 content');
    is_deeply([ (lstat($root . '/link1'))[2] ], [ 0120777 ],
	      $msg . ' version 1 /link1 properties');
    is(readlink($root . '/link1'), $box . '/client1/unknown',
       $msg . ' version 1 /link1 content');
}

sub is_version_2
{
    my ($box, $root, $msg) = @_;

    is_deeply([ (stat($root))[2] ], [ 040755 ],
	      $msg . ' version 2 / properties');
    is_deeply(readrep($root),
	      [ 'dir1', 'file1', 'file2', 'file3', 'link0', 'link1' ],
	      $msg . ' version 2 / content');

    is_deeply([ (stat($root . '/file1'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' version 2 /file1 properties');
    is(readfile($root . '/file1'), 'file1',
       $msg . ' version 2 /file1 content');
    is_deeply([ (stat($root . '/file2'))[2, 9] ], [ 0100755, 2 ],
	      $msg . ' version 2 /file2 properties');
    is(readfile($root . '/file2'), 'file2',
       $msg . ' version 2 /file2 content');
    is_deeply([ (stat($root . '/file3'))[2, 9] ], [ 0100666, 3 ],
	      $msg . ' version 2 /file3 properties');
    is(readfile($root . '/file3'), '', $msg . ' version 2 /file3 content');

    is_deeply([ (stat($root . '/dir1'))[2] ], [ 040755 ],
	      $msg . ' version 2 /dir1 properties');
    is_deeply(readrep($root . '/dir1'),
	      [ 'file0', 'link0' ],
	      $msg . ' version 2 /dir1 content');

    is_deeply([ (stat($root . '/dir1/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' version 2 /dir1/file0 properties');
    is(readfile($root . '/dir1/file0'), '',
       $msg . ' version 2 /dir1/file0 content');
    is_deeply([ (lstat($root . '/dir1/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 2 /dir1/link0 properties');
    is(readlink($root . '/dir1/link0'), '../file1',
       $msg . ' version 2 /dir1/link0 content');

    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 2 /link0 properties');
    is(readlink($root . '/link0'), $box . '/client2/dir1',
       $msg . ' version 2 /link0 content');
    is_deeply([ (lstat($root . '/link1'))[2] ], [ 0120777 ],
	      $msg . ' version 2 /link1 properties');
    is(readlink($root . '/link1'), $box . '/client2/unknown',
       $msg . ' version 2 /link1 content');
}

sub is_version_3
{
    my ($box, $root, $msg) = @_;

    is_deeply([ (stat($root))[2] ], [ 040755 ],
	      $msg . ' version 3 / properties');
    is_deeply(readrep($root),
	      [ 'dir0', 'link0' ],
	      $msg . ' version 3 / content');

    is_deeply([ (stat($root . '/dir0'))[2] ], [ 040755 ],
	      $msg . ' version 1 /dir0 properties');
    is_deeply(readrep($root . '/dir0'),
	      [ 'file0', 'link0' ],
	      $msg . ' version 1 /dir0 content');

    is_deeply([ (stat($root . '/dir0/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' version 1 /dir0/file0 properties');
    is(readfile($root . '/dir0/file0'), '',
       $msg . ' version 1 /dir0/file0 content');
    is_deeply([ (lstat($root . '/dir0/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 1 /dir0/link0 properties');
    is(readlink($root . '/dir0/link0'), '../file1',
       $msg . ' version 1 /dir0/link0 content');

    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' version 1 /link0 properties');
    is(readlink($root . '/link0'), $box . '/client1/dir0',
       $msg . ' version 1 /link0 content');
}


$ret = system('synctl', 'init', $box . '/server');
if ($ret != 0) {
    die ("cannot init server");
}


$ret = system('synctl', 'send', '--client=' . $box . '/client1',
	      '--server=' . $box . '/server');
is($ret, 0, 'complete manual send exit code');
$snapshot = snapshot($box . '/server', @snapshots);
ok($snapshot, 'complete manual send create new snapshot');
push(@snapshots, $snapshot);
$ret = system('synctl', 'recv', '--client=' . $box . '/restored-0',
	      '--server=' . $box . '/server', '', $snapshot);
is($ret, 0, 'complete manual send recv exit code');
is_version_1($box, $box . '/restored-0', 'complete manual send');


$ret = system('synctl', 'send', '--client=' . $box . '/client1',
	      '--server=' . $box . '/server');
is($ret, 0, 'unchanged manual send exit code');
$snapshot = snapshot($box . '/server', @snapshots);
ok($snapshot, 'unchanged manual send create new snapshot');
push(@snapshots, $snapshot);
$ret = system('synctl', 'recv', '--client=' . $box . '/restored-1',
	      '--server=' . $box . '/server', '', $snapshot);
is($ret, 0, 'unchanged manual send recv exit code');
is_version_1($box, $box . '/restored-1', 'unchanged manual send');


$ret = system('synctl', 'send', '--client=' . $box . '/client2',
	      '--server=' . $box . '/server');
is($ret, 0, 'changed manual send exit code');
$snapshot = snapshot($box . '/server', @snapshots);
ok($snapshot, 'changed manual send create new snapshot');
push(@snapshots, $snapshot);
$ret = system('synctl', 'recv', '--client=' . $box . '/restored-2',
	      '--server=' . $box . '/server', '', $snapshot);
is($ret, 0, 'changed manual send recv exit code');
is_version_2($box, $box . '/restored-2', 'changed manual send');


$profile = mktfile($box . '/profile1', MODE => 0644, CONTENT => <<"EOF");
client = $box/client1
server = $box/server
EOF

$ret = system('synctl', 'send', $profile);
is($ret, 0, 'unchanged profile send exit code');
$snapshot = snapshot($box . '/server', @snapshots);
ok($snapshot, 'unchencged profile send create new snapshot');
push(@snapshots, $snapshot);
$ret = system('synctl', 'recv', '--client=' . $box . '/restored-3',
	      '--server=' . $box . '/server', '', $snapshot);
is($ret, 0, 'unchanged profile send recv exit code');
is_version_1($box, $box . '/restored-3', 'unchanged profile send');


$ret = system('synctl', 'send', $profile,
	      '--include=.*link0$',
	      '--include=/dir0/*',
	      '--include=^/dir0$',
	      '--include=^/$',
	      '--exclude=^/*');
is($ret, 0, 'unhanged manual send with regex exit code');
$snapshot = snapshot($box . '/server', @snapshots);
ok($snapshot, 'unhanged manual send with regex create new snapshot');
push(@snapshots, $snapshot);
$ret = system('synctl', 'recv', '--client=' . $box . '/restored-4',
	      '--server=' . $box . '/server', '', $snapshot);
is($ret, 0, 'unhanged manual send with regex recv exit code');
is_version_3($box, $box . '/restored-4', 'unhanged manual send with regex');


1;
__END__
