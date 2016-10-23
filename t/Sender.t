#!/usr/bin/perl -l

use strict;
use warnings;

use POSIX qw(getgid getuid);
use Test::More tests => 22;

use t::File;
use t::MockDeposit;
use t::MockSnapshot;

BEGIN
{
    use_ok('Synctl');
    use_ok('Synctl::Seeker');
    use_ok('Synctl::Sender');
}


Synctl::Configure(ERROR => sub {});


my $box = mktroot();
my $client = mktdir($box . '/client');
mktfile($box . '/client/file0', MODE => 0644, CONTENT => "file\ncontent\n");
mktfile($box . '/client/file1', MODE => 0644, CONTENT => "");
mktfile($box . '/client/file2', MODE => 0755, CONTENT => "a\nfile");
mktfile($box . '/client/file4', MODE => 0644, CONTENT => "");
mktdir($box . '/client/dir0', MODE => 0755);
mktfile($box . '/client/dir0/file3', MODE => 0644, CONTENT => "\n\n");
mktlink($box . '/client/dir0/link0', '../file0');

my $deposit_mapper = {
    "file\ncontent\n" => '4e43a41dcab082afbce01680372b8f6c',
    ""                => 'd41d8cd98f00b204e9800998ecf8427e',
    "a\nfile"         => '5955f38582c63cc85ec480632a8c7455',
    "\n\n"            => 'e1c06d85ae7b8b032bef47e42e4c08f9',
    "../file0"        => '63cc546fe95567856b4a920de1d5adcf',
    "new content\n"   => 'f8a6701de14ec3fcfd9f2fe595e9c9ed'
};

my $deposit = t::MockDeposit->new('', {}, {}, $deposit_mapper);
my $snapshot = t::MockSnapshot->new({}, {});
my $seeker = Synctl::Seeker->new($client);
my ($sender, %hash, $path);
my $gid = getgid();
my $uid = getuid();


is(Synctl::Sender->new(undef, $snapshot, $seeker), undef,
   'new with no deposit');
is(Synctl::Sender->new('foo', $snapshot, $seeker), undef,
   'new with invalid deposit');
is(Synctl::Sender->new($deposit, undef, $seeker), undef,
   'new with no deposit');
is(Synctl::Sender->new($deposit, 'foo', $seeker), undef,
   'new with invalid deposit');
is(Synctl::Sender->new($deposit, $snapshot), undef,
   'new with no deposit');
is(Synctl::Sender->new($deposit, $snapshot, 'foo'), undef,
   'new with invalid deposit');
is(Synctl::Sender->new($deposit, $snapshot, $seeker, 'foo'), undef,
   'new with unexpected arguments');
ok($sender = Synctl::Sender->new($deposit, $snapshot, $seeker),
   'new with valid arguments');


is($sender->send(), 0, 'send complete snapshot');


is_deeply($deposit->{'content'}, {
    $deposit_mapper->{"file\ncontent\n"} => "file\ncontent\n",
    $deposit_mapper->{""}                => "",
    $deposit_mapper->{"a\nfile"}         => "a\nfile",
    $deposit_mapper->{"\n\n"}            => "\n\n",
    $deposit_mapper->{"../file0"}        => "../file0" },
	  'send complete snapshot deposit content');

is_deeply($deposit->{'reference'}, {
    $deposit_mapper->{"file\ncontent\n"} => 1,
    $deposit_mapper->{""}                => 2,
    $deposit_mapper->{"a\nfile"}         => 1,
    $deposit_mapper->{"\n\n"}            => 1,
    $deposit_mapper->{"../file0"}        => 1 },
	  'send complete snapshot deposit reference');

is_deeply($snapshot->{'content'}, {
    '/'           => [],
    '/file0'      => $deposit_mapper->{"file\ncontent\n"},
    '/file1'      => $deposit_mapper->{""},
    '/file2'      => $deposit_mapper->{"a\nfile"},
    '/file4'      => $deposit_mapper->{""},
    '/dir0'       => [],
    '/dir0/file3' => $deposit_mapper->{"\n\n"},
    '/dir0/link0' => $deposit_mapper->{"../file0"}
	  }, 'send complete snapshot path content');

%hash = %{$snapshot->{'properties'}};
foreach $path (keys(%hash)) {
    delete($hash{$path}->{MTIME});
    delete($hash{$path}->{INODE});
}

is_deeply(\%hash, {
    '/'           => { MODE => 040755,  USER => $uid, GROUP => $gid },
    '/file0'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/file1'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/file2'      => { MODE => 0100755, USER => $uid, GROUP => $gid },
    '/file4'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/dir0'       => { MODE => 040755,  USER => $uid, GROUP => $gid },
    '/dir0/file3' => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/dir0/link0' => { MODE => 0120777, USER => $uid, GROUP => $gid },
	  }, 'send complete snapshot path content');


$deposit = t::MockDeposit->new('', {
    $deposit_mapper->{"new content\n"} => "new content\n",
    $deposit_mapper->{"a\nfile"}       => "a\nfile",
    $deposit_mapper->{""}              => "" }, {
	$deposit_mapper->{"new content\n"} => 2,
	$deposit_mapper->{"a\nfile"}       => 1,
	$deposit_mapper->{""}              => 3 }, $deposit_mapper);

$snapshot = t::MockSnapshot->new({}, {});

$sender = Synctl::Sender->new($deposit, $snapshot, $seeker);
is($sender->send(), 0, 'send incremental snapshot done all files');

is_deeply($deposit->{'content'}, {
    $deposit_mapper->{"file\ncontent\n"} => "file\ncontent\n",
    $deposit_mapper->{""}                => "",
    $deposit_mapper->{"a\nfile"}         => "a\nfile",
    $deposit_mapper->{"\n\n"}            => "\n\n",
    $deposit_mapper->{"new content\n"}   => "new content\n",
    $deposit_mapper->{"../file0"}        => "../file0" },
	  'send incremental snapshot deposit content');

is_deeply($deposit->{'reference'}, {
    $deposit_mapper->{"file\ncontent\n"} => 1,
    $deposit_mapper->{""}                => 5,
    $deposit_mapper->{"a\nfile"}         => 2,
    $deposit_mapper->{"\n\n"}            => 1,
    $deposit_mapper->{"new content\n"}   => 2,
    $deposit_mapper->{"../file0"}        => 1 },
	  'send incremental snapshot deposit reference');

is_deeply($snapshot->{'content'}, {
    '/'           => [],
    '/file0'      => $deposit_mapper->{"file\ncontent\n"},
    '/file1'      => $deposit_mapper->{""},
    '/file2'      => $deposit_mapper->{"a\nfile"},
    '/file4'      => $deposit_mapper->{""},
    '/dir0'       => [],
    '/dir0/file3' => $deposit_mapper->{"\n\n"},
    '/dir0/link0' => $deposit_mapper->{"../file0"}
	  }, 'send complete snapshot path content');

is_deeply($snapshot->{'content'}, {
    '/'           => [],
    '/file0'      => $deposit_mapper->{"file\ncontent\n"},
    '/file1'      => $deposit_mapper->{""},
    '/file2'      => $deposit_mapper->{"a\nfile"},
    '/file4'      => $deposit_mapper->{""},
    '/dir0'       => [],
    '/dir0/file3' => $deposit_mapper->{"\n\n"},
    '/dir0/link0' => $deposit_mapper->{"../file0"}
	  }, 'send complete snapshot path content');

%hash = %{$snapshot->{'properties'}};
foreach $path (keys(%hash)) {
    delete($hash{$path}->{MTIME});
    delete($hash{$path}->{INODE});
}

is_deeply(\%hash, {
    '/'           => { MODE => 040755,  USER => $uid, GROUP => $gid },
    '/file0'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/file1'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/file2'      => { MODE => 0100755, USER => $uid, GROUP => $gid },
    '/file4'      => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/dir0'       => { MODE => 040755,  USER => $uid, GROUP => $gid },
    '/dir0/file3' => { MODE => 0100644, USER => $uid, GROUP => $gid },
    '/dir0/link0' => { MODE => 0120777, USER => $uid, GROUP => $gid },
	  }, 'send complete snapshot path content');


1;
__END__
