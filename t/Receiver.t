#!/usr/bin/perl -l

use strict;
use warnings;

use POSIX qw(getgid getuid);
use Test::More tests => 65;

use t::File;
use t::MockDeposit;
use t::MockSnapshot;


BEGIN
{
    use_ok('Synctl::Receiver');
}


my $box0 = mktroot();
mktfile($box0 . '/same-all', MODE => 0644, CONTENT => "A");
mktfile($box0 . '/different-mode', MODE => 0755, CONTENT => "A");
mktfile($box0 . '/different-content', MODE => 0644, CONTENT => "B");
mktdir( $box0 . '/different-type', MODE => 0755);
mktfile($box0 . '/removed', MODE => 0644, CONTENT => "A");
mktfile($box0 . '/restricted-same-all', MODE => 0000, CONTENT => "A");
mktfile($box0 . '/restricted-different-mode', MODE => 0000, CONTENT => "A");
mktfile($box0 . '/restricted-different-nmode', MODE => 0644, CONTENT => "A");
mktfile($box0 . '/restricted-different-content', MODE => 0000, CONTENT => "B");
mktdir( $box0 . '/restricted-different-type', MODE => 0000);
mktfile($box0 . '/restricted-removed', MODE => 0000, CONTENT => "A");


my $uid = getuid();
my $gid = getgid();
my $deposit_mapper = {
    'A' => '7fc56270e7a70fa81a5935b72eacbe29',
    'B' => '9d5ed678fe57bcca610140957afab571'
};


my ($deposit, $snapshot);
my ($receiver, $done, $err);
my ($mode, $user, $group);
my ($fh, $content, $entry, $props);

$deposit = t::MockDeposit->new('', {
    $deposit_mapper->{"A"} => "A",
    $deposit_mapper->{"B"} => "B" }, {
    $deposit_mapper->{"A"} => 100,
    $deposit_mapper->{"B"} => 100 },
    $deposit_mapper);

$snapshot = t::MockSnapshot->new({
    '/'                             => [],
    '/same-all'                     => $deposit_mapper->{"A"},
    '/different-mode'               => $deposit_mapper->{"A"},
    '/different-content'            => $deposit_mapper->{"A"},
    '/different-type'               => $deposit_mapper->{"A"},
    '/added'                        => $deposit_mapper->{"A"},
    '/restricted-same-all'          => $deposit_mapper->{"A"},
    '/restricted-different-mode'    => $deposit_mapper->{"A"},
    '/restricted-different-nmode'   => $deposit_mapper->{"A"},
    '/restricted-different-content' => $deposit_mapper->{"A"},
    '/restricted-different-type'    => $deposit_mapper->{"A"},
    '/restricted-added'             => $deposit_mapper->{"A"} }, {
    '/'                             => {
	MODE =>  040700, USER => $uid, GROUP => $gid },
    '/same-all'                     => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/different-mode'               => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/different-content'            => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/different-type'               => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/added'                        => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/restricted-same-all'          => {
	MODE => 0100000, USER => $uid, GROUP => $gid },
    '/restricted-different-mode'    => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/restricted-different-nmode'   => {
	MODE => 0100000, USER => $uid, GROUP => $gid },
    '/restricted-different-content' => {
	MODE => 0100000, USER => $uid, GROUP => $gid },
    '/restricted-different-type'    => {
	MODE => 0100000, USER => $uid, GROUP => $gid },
    '/restricted-added'             => {
	MODE => 0100000, USER => $uid, GROUP => $gid } });

$receiver = Synctl::Receiver->new('/', $box0, $snapshot, $deposit);
($done, $err) = $receiver->receive();

is($done, 11, 'receive files right amount');
is($err, 0, 'receive files no error');

foreach $entry (keys(%{$snapshot->{'content'}})) {
    ($mode, $user, $group) = (lstat($box0 . $entry))[2, 4, 5];
    
    is($mode, $snapshot->{'properties'}->{$entry}->{MODE},
       "receive files '$entry' correct mode");
    # is($user, $snapshot->{'properties'}->{$entry}->{USER},
    #    "receive files '$entry' correct user");
    # is($group, $snapshot->{'properties'}->{$entry}->{GROUP},
    #    "receive files '$entry' correct group");

    next if ($entry eq '/');

    chmod(0777, $box0 . $entry) or die ($!);
    open($fh, '<', $box0 . $entry) or die ($!);
    local $/ = undef;
    $content = <$fh>;
    close($fh);

    is($content, "A", "receive files '$entry' correct content");
}


my $box1 = mktroot();
mktdir( $box1 . '/empty-same', MODE => 0755);
mktdir( $box1 . '/empty-different-mode', MODE => 0700);
mktdir( $box1 . '/restricted-empty-same', MODE => 0000);
mktdir( $box1 . '/restricted-empty-different-mode', MODE => 0000);
mktdir( $box1 . '/restricted-empty-different-nmode', MODE => 0755);

mktdir( $box1 . '/full-same', MODE => 0755);
mktfile($box1 . '/full-same/file0', MODE => 0644, CONTENT => "A");
mktdir( $box1 . '/full-same/dir0', MODE => 0755);

mktdir( $box1 . '/rx-full-different-content', MODE => 0700);
mktfile($box1 . '/rx-full-different-content/f0', MODE => 0644, CONTENT => "B");
mktfile($box1 . '/rx-full-different-content/f1', MODE => 0600, CONTENT => "A");
mktfile($box1 . '/rx-full-different-content/f2', MODE => 0644, CONTENT => "A");
mktdir( $box1 . '/rx-full-different-content/dir0', MODE => 0700);
chmod(0500, $box1 . '/rx-full-different-content');

mktdir( $box1 . '/wo-full-same', MODE => 0700);
mktfile($box1 . '/wo-full-same/file0', MODE => 0644, CONTENT => "A");
mktdir( $box1 . '/wo-full-same/dir0', MODE => 0755);
chmod(0200, $box1 . '/wo-full-same');


$snapshot = t::MockSnapshot->new({
    '/'                                 => [],
    '/empty-same'                       => [],
    '/empty-different-mode'             => [],
    '/restricted-empty-same'            => [],
    '/restricted-empty-different-mode'  => [],
    '/restricted-empty-different-nmode' => [],
    '/full-same'                        => [],
    '/full-same/file0'                  => $deposit_mapper->{"A"},
    '/full-same/dir0'                   => [],
    '/rx-full-different-content'        => [],
    '/rx-full-different-content/f0'     => $deposit_mapper->{"A"},
    '/rx-full-different-content/f1'     => $deposit_mapper->{"A"},
    '/rx-full-different-content/f3'     => $deposit_mapper->{"A"},
    '/rx-full-different-content/dir0'   => [],
    '/wo-full-same'                     => [],
    '/wo-full-same/file0'               => $deposit_mapper->{"A"},
    '/wo-full-same/dir0'                => [] }, {
    '/'                                 => {
	MODE =>  040700, USER => $uid, GROUP => $gid },
    '/empty-same'                       => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/empty-different-mode'             => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/restricted-empty-same'            => {
	MODE =>  040000, USER => $uid, GROUP => $gid },
    '/restricted-empty-different-mode'  => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/restricted-empty-different-nmode' => {
	MODE =>  040000, USER => $uid, GROUP => $gid },
    '/full-same'                        => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/full-same/file0'                  => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/full-same/dir0'                   => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/rx-full-different-content'        => {
	MODE =>  040500, USER => $uid, GROUP => $gid },
    '/rx-full-different-content/f0'     => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/rx-full-different-content/f1'     => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/rx-full-different-content/f3'     => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/rx-full-different-content/dir0'   => {
	MODE =>  040755, USER => $uid, GROUP => $gid },
    '/wo-full-same'                     => {
	MODE =>  040200, USER => $uid, GROUP => $gid },
    '/wo-full-same/file0'               => {
	MODE => 0100644, USER => $uid, GROUP => $gid },
    '/wo-full-same/dir0'                => {
	MODE =>  040755, USER => $uid, GROUP => $gid } });

$receiver = Synctl::Receiver->new('/', $box1, $snapshot, $deposit);
($done, $err) = $receiver->receive();

is($done, 8, 'receive directories right amount');
is($err, 0, 'receive directories no error');

foreach $entry (sort { $a cmp $b } keys(%{$snapshot->{'content'}})) {
    ($mode, $user, $group) = (lstat($box1 . $entry))[2, 4, 5];
    
    is($mode, $snapshot->{'properties'}->{$entry}->{MODE},
       "receive directories '$entry' correct mode");
    # is($user, $snapshot->{'properties'}->{$entry}->{USER},
    #    "receive directories '$entry' correct user");
    # is($group, $snapshot->{'properties'}->{$entry}->{GROUP},
    #    "receive directories '$entry' correct group");

    if (-d $box1 . $entry) {
	chmod(0777, $box1 . $entry) or die ($!);
    } elsif (-f $box1 . $entry) {
	chmod(0777, $box1 . $entry) or die ($!);
	open($fh, '<', $box1 . $entry) or die ($!);
	local $/ = undef;
	$content = <$fh>;
	close($fh);
	is($content, "A", "receive directories '$entry' correct content");
    }
}


my $box2 = mktroot();
mktfile($box2 . '/A', MODE => 0644, CONTENT => "A");
mktdir( $box2 . '/B', MODE => 0755);
mktlink($box2 . '/link-to-file', "A");
mktlink($box2 . '/link-to-dir', "B");
mktfile($box2 . '/file-to-link', MODE => 0644, CONTENT => "A");
mktdir( $box2 . '/dir-to-link', MODE => 0755);
mktlink($box2 . '/old-link', "A");

$snapshot = t::MockSnapshot->new({
    '/'             => [],
    '/A'            => $deposit_mapper->{"A"},
    '/B'            => [],
    '/link-to-file' => $deposit_mapper->{"A"},
    '/link-to-dir'  => [],
    '/file-to-link' => $deposit_mapper->{"A"},
    '/dir-to-link'  => $deposit_mapper->{"B"},
    '/new-link'     => $deposit_mapper->{"A"} }, {
    '/'             => { MODE =>  040700, USER => $uid, GROUP => $gid },
    '/A'            => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/B'            => { MODE =>  040755, USER => $uid, GROUP => $gid },
    '/link-to-file' => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/link-to-dir'  => { MODE =>  040755, USER => $uid, GROUP => $gid },
    '/file-to-link' => { MODE => 0120777, USER => $uid, GROUP => $gid },
    '/dir-to-link'  => { MODE => 0120777, USER => $uid, GROUP => $gid },
    '/new-link'     => { MODE => 0120777, USER => $uid, GROUP => $gid } });

$receiver = Synctl::Receiver->new('/', $box2, $snapshot, $deposit);
($done, $err) = $receiver->receive();

is($done, 6, 'receive links right amount');
is($err, 0, 'receive links no error');

foreach $entry (keys(%{$snapshot->{'content'}})) {
    ($mode, $user, $group) = (lstat($box2 . $entry))[2, 4, 5];
    
    is($mode, $snapshot->{'properties'}->{$entry}->{MODE},
       "receive links '$entry' correct mode");
    # is($user, $snapshot->{'properties'}->{$entry}->{USER},
    #    "receive links '$entry' correct user");
    # is($group, $snapshot->{'properties'}->{$entry}->{GROUP},
    #    "receive links '$entry' correct group");

    if (-l $box2 . $entry) {
	if (!defined($content = readlink($box2 . $entry))) { die ($!); }
	if ($entry eq '/dir-to-link') {
	    is($content, "B", "receive links '$entry' correct content");
	} else {
	    is($content, "A", "receive links '$entry' correct content");
	}
    } elsif (-f $box2 . $entry) {
	chmod(0777, $box2 . $entry) or die ($!);
	open($fh, '<', $box2 . $entry) or die ($!);
	local $/ = undef;
	$content = <$fh>;
	close($fh);
	is($content, "A", "receive links '$entry' correct content");
    }
}


1;
__END__
