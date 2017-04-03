#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 117;

use t::File;

use Synctl;


$ENV{PATH} = './script:' . $ENV{PATH};


my $box = mktroot(NOTMP => 1);
my ($ret, $snapshot1, $snapshot2);
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

sub is_version_1
{
    my ($box, $root, $msg) = @_;

    is_deeply(readrep($root), [ 'dir0', 'file0', 'file1', 'file2',
				'link0', 'link1' ],
	      $msg . ' / content');
    is_deeply(readrep($root . '/dir0'), [ 'file0', 'link0' ],
	      $msg . ' /dir0 content');
    is(readfile($root . '/file0'), '',
       $msg . ' /file0 content');
    is(readfile($root . '/file1'), 'file1',
       $msg . ' /file1 content');
    is(readfile($root . '/file2'), '',
       $msg . ' /file2 content');
    is(readfile($root . '/dir0/file0'), '',
       $msg . ' /dir0/file0 content');
    is(readlink($root . '/link0'), $box . '/client1/dir0',
       $msg . ' /link0 content');
    is(readlink($root . '/link1'), $box . '/client1/unknown',
       $msg . ' /link1 content');
    is(readlink($root . '/dir0/link0'), '../file1',
       $msg . ' /dir0/link0 content');
    is_deeply([ (lstat($root))[2, 9] ], [ 040755, 1 ],
	      $msg . ' / properties');
    is_deeply([ (lstat($root . '/dir0'))[2, 9] ], [ 040755, 5 ],
	      $msg . ' /dir0 properties');
    is_deeply([ (lstat($root . '/file0'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' /file0 properties');
    is_deeply([ (lstat($root . '/file1'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' /file1 properties');
    is_deeply([ (lstat($root . '/file2'))[2, 9] ], [ 0100755, 2 ],
	      $msg . ' /file2 properties');
    is_deeply([ (lstat($root . '/dir0/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' /dir0/file0 properties');
    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' /link0 properties');
    is_deeply([ (lstat($root . '/link1'))[2] ], [ 0120777 ],
	      $msg . ' /link1 properties');
    is_deeply([ (lstat($root . '/dir0/link0'))[2] ], [ 0120777 ],
	      $msg . ' /dir0/link0 properties');
}

sub is_version_2
{
    my ($box, $root, $msg) = @_;

    is_deeply(readrep($root), [ 'dir1', 'file1', 'file2', 'file3',
				'link0', 'link1' ],
	      $msg . ' / content');
    is_deeply(readrep($root . '/dir1'), [ 'file0', 'link0' ],
	      $msg . ' /dir1 content');
    is(readfile($root . '/file1'), 'file1',
       $msg . ' /file1 content');
    is(readfile($root . '/file2'), 'file2',
       $msg . ' /file2 content');
    is(readfile($root . '/file3'), '',
       $msg . ' /file3 content');
    is(readfile($root . '/dir1/file0'), '',
       $msg . ' /dir1/file0 content');
    is(readlink($root . '/link0'), $box . '/client2/dir1',
       $msg . ' /link0 content');
    is(readlink($root . '/link1'), $box . '/client2/unknown',
       $msg . ' /link1 content');
    is(readlink($root . '/dir1/link0'), '../file1',
       $msg . ' /dir1/link0 content');
    is_deeply([ (lstat($root))[2, 9] ], [ 040755, 1 ],
	      $msg . ' / properties');
    is_deeply([ (lstat($root . '/dir1'))[2, 9] ], [ 040755, 4 ],
	      $msg . ' /dir1 properties');
    is_deeply([ (lstat($root . '/file1'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' /file1 properties');
    is_deeply([ (lstat($root . '/file2'))[2, 9] ], [ 0100750, 3 ],
	      $msg . ' /file2 properties');
    is_deeply([ (lstat($root . '/file3'))[2, 9] ], [ 0100666, 3 ],
	      $msg . ' /file3 properties');
    is_deeply([ (lstat($root . '/dir1/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' /dir1/file0 properties');
    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' /link0 properties');
    is_deeply([ (lstat($root . '/link1'))[2] ], [ 0120777 ],
	      $msg . ' /link1 properties');
    is_deeply([ (lstat($root . '/dir1/link0'))[2] ], [ 0120777 ],
	      $msg . ' /dir1/link0 properties');
}

sub is_version_2_restored_file2
{
    my ($box, $root, $msg) = @_;

    is_deeply(readrep($root), [ 'dir1', 'file1', 'file2', 'file3',
				'link0', 'link1' ],
	      $msg . ' / content');
    is_deeply(readrep($root . '/dir1'), [ 'file0', 'link0' ],
	      $msg . ' /dir1 content');
    is(readfile($root . '/file1'), 'file1',
       $msg . ' /file1 content');
    is(readfile($root . '/file2'), '',
       $msg . ' /file2 content');
    is(readfile($root . '/file3'), '',
       $msg . ' /file3 content');
    is(readfile($root . '/dir1/file0'), '',
       $msg . ' /dir1/file0 content');
    is(readlink($root . '/link0'), $box . '/client2/dir1',
       $msg . ' /link0 content');
    is(readlink($root . '/link1'), $box . '/client2/unknown',
       $msg . ' /link1 content');
    is(readlink($root . '/dir1/link0'), '../file1',
       $msg . ' /dir1/link0 content');
    is_deeply([ (lstat($root))[2, 9] ], [ 040755, 1 ],
	      $msg . ' / properties');
    is_deeply([ (lstat($root . '/dir1'))[2, 9] ], [ 040755, 4 ],
	      $msg . ' /dir1 properties');
    is_deeply([ (lstat($root . '/file1'))[2, 9] ], [ 0100644, 1 ],
	      $msg . ' /file1 properties');
    is_deeply([ (lstat($root . '/file2'))[2, 9] ], [ 0100755, 2 ],
	      $msg . ' /file2 properties');
    is_deeply([ (lstat($root . '/file3'))[2, 9] ], [ 0100666, 3 ],
	      $msg . ' /file3 properties');
    is_deeply([ (lstat($root . '/dir1/file0'))[2, 9] ], [ 0100644, 3 ],
	      $msg . ' /dir1/file0 properties');
    is_deeply([ (lstat($root . '/link0'))[2] ], [ 0120777 ],
	      $msg . ' /link0 properties');
    is_deeply([ (lstat($root . '/link1'))[2] ], [ 0120777 ],
	      $msg . ' /link1 properties');
    is_deeply([ (lstat($root . '/dir1/link0'))[2] ], [ 0120777 ],
	      $msg . ' /dir1/link0 properties');
}


# Create origin version 1
mktdir($box . '/client1', MODE => 0755);
mktfile($box . '/client1/file0', MODE => 0644, TIME => 1, CONTENT => '');
mktfile($box . '/client1/file1', MODE => 0644, TIME => 1, CONTENT => 'file1');
mktfile($box . '/client1/file2', MODE => 0755, TIME => 2, CONTENT => '');
mktdir ($box . '/client1/dir0',  MODE => 0755);
mktfile($box . '/client1/dir0/file0', MODE => 0644, TIME => 3, CONTENT => '');
mktlink($box . '/client1/dir0/link0', '../file1', TIME => 3);
mktlink($box . '/client1/link0', $box . '/client1/dir0', TIME => 4);
mktlink($box . '/client1/link1', $box . '/client1/unknown', TIME => 1);
utime(5, 5, $box . '/client1/dir0');
utime(1, 1, $box . '/client1');

# Create origin version 2
mktdir($box . '/client2', MODE => 0755, TIME => 1);
mktfile($box . '/client2/file1', MODE => 0644, TIME => 1, CONTENT => 'file1');
mktfile($box . '/client2/file2', MODE => 0750, TIME => 3, CONTENT => 'file2');
mktfile($box . '/client2/file3', MODE => 0666, TIME => 3, CONTENT => '');
mktdir ($box . '/client2/dir1',  MODE => 0755);
mktfile($box . '/client2/dir1/file0', MODE => 0644, TIME => 3, CONTENT => '');
mktlink($box . '/client2/dir1/link0', '../file1', TIME => 3);
mktlink($box . '/client2/link0', $box . '/client2/dir1', TIME => 4);
mktlink($box . '/client2/link1', $box . '/client2/unknown', TIME => 1);
utime(4, 4, $box . '/client2/dir1');
utime(1, 1, $box . '/client2');


# Initialize server and send snapshots v1 and v2
$ret = system('synctl', 'init', $box . '/server');
if ($ret != 0) {
    die ("cannot init server");
}

$ret = system('synctl', 'send', '--client=' . $box . '/client1',
	      '--server=' . $box . '/server');
is($ret, 0, 'send version 1 exit code');
$snapshot1 = snapshot($box . '/server', @snapshots);
push(@snapshots, $snapshot1);

$ret = system('synctl', 'send', '--client=' . $box . '/client2',
	      '--server=' . $box . '/server');
is($ret, 0, 'send version 2 exit code');
$snapshot2 = snapshot($box . '/server', @snapshots);
push(@snapshots, $snapshot2);


# Receive last on unexisting directory
$ret = system('synctl', 'recv', '--client=' . $box . '/receive1',
	      '--server=' . $box . '/server');
is($ret, 0, 'recv last on unexisting exit code');
is_version_2($box, $box . '/receive1', 'recv last on unexisting');

# Receive last on existing directory
mktdir($box . '/receive2');
$ret = system('synctl', 'recv', '--client=' . $box . '/receive2',
	      '--server=' . $box . '/server');
is($ret, 0, 'recv last on existing exit code');
is_version_2($box, $box . '/receive2', 'recv last on existing');

# Receive last on different directory
system('cp', '-R', $box . '/client1', $box . '/receive3');
$ret = system('synctl', 'recv', '--client=' . $box . '/receive3',
	      '--server=' . $box . '/server');
is($ret, 0, 'recv last on different exit code');
is_version_2($box, $box . '/receive3', 'recv last on different');

# Receive specified last
$ret = system('synctl', 'recv', '--client=' . $box . '/receive4',
	      '--server=' . $box . '/server', '', $snapshot2);
is($ret, 0, 'recv specified last exit code');
is_version_2($box, $box . '/receive4', 'recv specified last');

# Receive specified
$ret = system('synctl', 'recv', '--client=' . $box . '/receive5',
	      '--server=' . $box . '/server', '', $snapshot1);
is($ret, 0, 'recv specified exit code');
is_version_1($box, $box . '/receive5', 'recv specified');

# Receive specified for one file
$ret = system('synctl', 'recv', '--client=' . $box . '/receive6',
	      '--server=' . $box . '/server', '', $snapshot2);
is($ret, 0, 'recv specified last as base exit code');
$ret = system('synctl', 'recv', '--client=' . $box . '/receive6',
	      '--server=' . $box . '/server', '', $snapshot1,
	      '--include=/file2', '--include=/', '--exclude=/*');
is($ret, 0, 'recv specified for one file exit code');
is_version_2_restored_file2($box, $box . '/receive6',
			    'recv specified for one file');


1;
__END__
