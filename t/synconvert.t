#!/usr/bin/perl -l

use strict;
use warnings;

use POSIX qw(getuid getgid);
use Test::More tests => 168;

use t::File;

use Synctl;


$ENV{PATH} = './script:' . $ENV{PATH};


my $box = mktroot(NOTMP => 1);
my ($ret, $controler, $deposit, $snapshot);
my $uid = getuid();
my $gid = getgid();
my (%properties, $path, $props);
my (%contents, $hash, $content);

mktdir($box . '/rsync');

# Create origin version 1
mktdir($box . '/origin', MODE => 0755, TIME => 1);
mktfile($box . '/origin/file0', MODE => 0644, TIME => 1, CONTENT => '');
mktfile($box . '/origin/file1', MODE => 0644, TIME => 1, CONTENT => 'file1');
mktfile($box . '/origin/file2', MODE => 0755, TIME => 2, CONTENT => '');
mktdir ($box . '/origin/dir0',  MODE => 0755);
mktfile($box . '/origin/dir0/file0', MODE => 0644, TIME => 3, CONTENT => '');
mktlink($box . '/origin/dir0/link0', '../file1', TIME => 3);
mktlink($box . '/origin/link0', $box . '/origin/dir0', TIME => 4);
mktlink($box . '/origin/link1', $box . '/origin/unknown', TIME => 1);

# System specific operations
system('ln', $box . '/origin/file2', $box . '/origin/hlink0');
system('ln', $box . '/origin/file2', $box . '/origin/hlink1');
system('mkfifo', $box . '/origin/fifo0');
utime(0, 2, $box . '/origin/fifo0');

# Fix modification time of directories
utime(0, 3, $box . '/origin/dir0');
utime(0, 4, $box . '/origin');

# Create old rsync format - backup version 1
system('rsync', '-aAHXc', '--fake-super', $box . '/origin/',
       $box . '/rsync/2015-07-02-13-58-01');

# Create fake rsync xattrs
system('setfattr', $box . '/rsync/2015-07-02-13-58-01/file1',
       '-n', 'user.rsync.%stat', '-v', "100700 0,0 0:10");
system('setfattr', $box . '/rsync/2015-07-02-13-58-01/dir0',
       '-n', 'user.rsync.%stat', '-v', "40755 0,0 0:0");

# Create origin version 2
system('rm', $box . '/origin/hlink0');
system('rm', $box . '/origin/link0');
mktfile($box . '/origin/hlink0', MODE => 0644, TIME => 3, CONTENT => 'hlink0');
mktdir($box . '/origin/dir1',    MODE => 0755, TIME => 4);

# Fix modification time of directories
utime(0, 7, $box . '/origin');

# Create old rsync format - backup version 2
system('rsync', '-aAHXc', '--fake-super',
       '--link-dest=../2015-07-02-13-58-01',
       $box . '/origin/', $box . '/rsync/2015-09-25-04-21-13');


$ret = system('synconvert', '-p', $box . '/rsync', $box . '/synctl');
is($ret, 0, 'complete synconvert exit code');

$controler = Synctl::controler($box . '/synctl');
ok($controler, 'controler');

$deposit = $controler->deposit();
ok($deposit, 'deposit');

is(scalar($controler->snapshot()), 2, 'amount of snapshots converted');
$snapshot = (sort { $a->date() cmp $b->date() } $controler->snapshot())[0];
is($snapshot->date(), '2015-07-02-13-58-01', 'date of first snapshot');

# - test over file properties
%properties = (
    '/'       => { USER => $uid, GROUP => $gid, MTIME => 4, MODE =>  040755 },
    '/file0'  => { USER => $uid, GROUP => $gid, MTIME => 1, MODE => 0100644,
		   SIZE => 0},
    '/file1'  => { USER =>    0, GROUP =>   10, MTIME => 1, MODE => 0100700,
		   SIZE => 5 },
    '/file2'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/dir0'   => { USER =>    0, GROUP =>    0, MTIME => 3, MODE =>  040755 },
    '/dir0/file0' => { USER => $uid, GROUP => $gid, MTIME => 3,
		       MODE => 0100644, SIZE => 0 },
    '/dir0/link0' => { USER => $uid, GROUP => $gid, MODE => 0120777,
		       SIZE => 8 },
    '/link0'  => { USER => $uid, GROUP => $gid, MODE => 0120777,
		   SIZE => length($box . '/origin/dir0') },
    '/link1'  => { USER => $uid, GROUP => $gid, MODE => 0120777,
	 	   SIZE => length($box . '/origin/unknown') },
    '/hlink0' => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/hlink1' => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/fifo0'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 010644,
		   SIZE => 0 },
    );
foreach $path (sort { $a cmp $b } keys(%properties)) {
    $props = $snapshot->get_properties($path);
    ok($props, "file '$path' exists");

    $props = { %$props };
    delete($props->{INODE});
    if ($path =~ m|/link|) {
	delete($props->{MTIME});
    }
    
    is_deeply($props, $properties{$path}, "properties of '$path'");
    ok(-e $box . '/rsync/2015-07-02-13-58-01' . $path,
       "snapshot preserved for '$path'");
}

is($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink0')->{INODE},
   "files '/file2' and '/hlink0' have same inode");
is($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink1')->{INODE},
   "files '/file2' and '/hlink1' have same inode");

# - test over file contents
%contents = (
    '/file0'      => '',
    '/file1'      => 'file1',
    '/file2'      => '',
    '/dir0/file0' => '',
    '/dir0/link0' => '../file1',
    '/link0'      => $box . '/origin/dir0',
    '/link1'      => $box . '/origin/unknown',
    '/hlink0'     => '',
    '/hlink1'     => '',
    '/fifo0'      => ''
    );
foreach $path (sort { $a cmp $b } keys(%contents)) {
    $hash = $snapshot->get_file($path);
    ok($hash, "file '$path' has content");

    $deposit->recv($hash, \$content);
    is($content, $contents{$path}, "file '$path' has correct content");
}


$snapshot = (sort { $a->date() cmp $b->date() } $controler->snapshot())[1];
is($snapshot->date(), '2015-09-25-04-21-13', 'date of second snapshot');

# - test over file properties
%properties = (
    '/'       => { USER => $uid, GROUP => $gid, MTIME => 7, MODE =>  040755 },
    '/file0'  => { USER => $uid, GROUP => $gid, MTIME => 1, MODE => 0100644,
		   SIZE => 0},
    '/file1'  => { USER => $uid, GROUP => $gid, MTIME => 1, MODE => 0100644,
		   SIZE => 5 },
    '/file2'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/dir0'   => { USER => $uid, GROUP => $gid, MTIME => 3, MODE =>  040755 },
    '/dir0/file0' => { USER => $uid, GROUP => $gid, MTIME => 3,
		       MODE => 0100644, SIZE => 0 },
    '/dir0/link0' => { USER => $uid, GROUP => $gid, MODE => 0120777,
		       SIZE => 8 },
    '/dir1'   => { USER => $uid, GROUP => $gid, MTIME => 4, MODE =>  040755 },
    '/link1'  => { USER => $uid, GROUP => $gid, MODE => 0120777,
	 	   SIZE => length($box . '/origin/unknown') },
    '/hlink0' => { USER => $uid, GROUP => $gid, MTIME => 3, MODE => 0100644,
		   SIZE => 6 },
    '/hlink1' => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/fifo0'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 010644,
		   SIZE => 0 },
    );
foreach $path (sort { $a cmp $b } keys(%properties)) {
    $props = { %{$snapshot->get_properties($path)} };
    ok($props, "file '$path' exists");

    delete($props->{INODE});
    if ($path =~ m|/link|) {
	delete($props->{MTIME});
    }
    
    is_deeply($props, $properties{$path}, "properties of '$path'");
    ok(-e $box . '/rsync/2015-09-25-04-21-13' . $path,
       "snapshot preserved for '$path'");
}

isnt($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink0')->{INODE},
   "files '/file2' and '/hlink0' have different inode");
is($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink1')->{INODE},
   "files '/file2' and '/hlink1' have same inode");

%contents = (
    '/file0'      => '',
    '/file1'      => 'file1',
    '/file2'      => '',
    '/dir0/file0' => '',
    '/dir0/link0' => '../file1',
    '/link1'      => $box . '/origin/unknown',
    '/hlink0'     => 'hlink0',
    '/hlink1'     => '',
    '/fifo0'      => ''
    );
foreach $path (sort { $a cmp $b } keys(%contents)) {
    $hash = $snapshot->get_file($path);
    ok($hash, "file '$path' has content");

    $deposit->recv($hash, \$content);
    is($content, $contents{$path}, "file '$path' has correct content");
}


# Create old rsync format - backup version 3
system('rsync', '-aAHXc', '--fake-super',
       '--link-dest=../2015-09-25-04-21-13',
       $box . '/origin/', $box . '/rsync/2016-01-14-17-42-42');

$ret = system('synconvert', $box . '/rsync', $box . '/synctl');
is($ret, 0, 'additional synconvert exit code');


$controler = Synctl::controler($box . '/synctl');
$deposit = $controler->deposit();

is(scalar($controler->snapshot()), 3,
   'amount of additional snapshots converted');
$snapshot = (sort { $a->date() cmp $b->date() } $controler->snapshot())[2];
is($snapshot->date(), '2016-01-14-17-42-42', 'date of third snapshot');


# - test over file properties
%properties = (
    '/'       => { USER => $uid, GROUP => $gid, MTIME => 7, MODE =>  040755 },
    '/file0'  => { USER => $uid, GROUP => $gid, MTIME => 1, MODE => 0100644,
		   SIZE => 0},
    '/file1'  => { USER => $uid, GROUP => $gid, MTIME => 1, MODE => 0100644,
		   SIZE => 5 },
    '/file2'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/dir0'   => { USER => $uid, GROUP => $gid, MTIME => 3, MODE =>  040755 },
    '/dir0/file0' => { USER => $uid, GROUP => $gid, MTIME => 3,
		       MODE => 0100644, SIZE => 0 },
    '/dir0/link0' => { USER => $uid, GROUP => $gid, MODE => 0120777,
		       SIZE => 8 },
    '/dir1'   => { USER => $uid, GROUP => $gid, MTIME => 4, MODE =>  040755 },
    '/link1'  => { USER => $uid, GROUP => $gid, MODE => 0120777,
	 	   SIZE => length($box . '/origin/unknown') },
    '/hlink0' => { USER => $uid, GROUP => $gid, MTIME => 3, MODE => 0100644,
		   SIZE => 6 },
    '/hlink1' => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 0100755,
		   SIZE => 0 },
    '/fifo0'  => { USER => $uid, GROUP => $gid, MTIME => 2, MODE => 010644,
		   SIZE => 0 },
    );
foreach $path (sort { $a cmp $b } keys(%properties)) {
    $props = { %{$snapshot->get_properties($path)} };
    ok($props, "file '$path' exists");

    delete($props->{INODE});
    if ($path =~ m|/link|) {
	delete($props->{MTIME});
    }
    
    is_deeply($props, $properties{$path}, "properties of '$path'");
}

ok(!(-e $box . '/rsync/2016-01-14-17-42-42'), 'third snapshot erased');


isnt($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink0')->{INODE},
   "files '/file2' and '/hlink0' have different inode");
is($snapshot->get_properties('/file2')->{INODE},
   $snapshot->get_properties('/hlink1')->{INODE},
   "files '/file2' and '/hlink1' have same inode");

%contents = (
    '/file0'      => '',
    '/file1'      => 'file1',
    '/file2'      => '',
    '/dir0/file0' => '',
    '/dir0/link0' => '../file1',
    '/link1'      => $box . '/origin/unknown',
    '/hlink0'     => 'hlink0',
    '/hlink1'     => '',
    '/fifo0'      => ''
    );
foreach $path (sort { $a cmp $b } keys(%contents)) {
    $hash = $snapshot->get_file($path);
    ok($hash, "file '$path' has content");

    $deposit->recv($hash, \$content);
    is($content, $contents{$path}, "file '$path' has correct content");
}


1;
__END__
