#!/usr/bin/perl -l
# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Synctl.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use File::Remove qw(remove);
use File::Temp qw(tempdir);
use Test::More tests => 3;

use t::File;

BEGIN
{
    use_ok('Synctl')
}


sub make_sandbox_0
{
    my $root = mktroot();

    mktfile($root . '/file', MODE => 0644, CONTENT => "");
    mktdir($root . '/dir', MODE => 0755);
    mktfile($root . '/dir/file', MODE => 0755, CONTENT => "#!/bin/sh\n");
    mktlink($root . '/alink', $root . '/dir/file');
    mktlink($root . '/rlink', 'dir/file');

    return $root
}

sub make_sandbox_1
{
    my $root = mktroot();

    mktfile($root . '/file-0', MODE => 0644, CONTENT => "");
    mktfile($root . '/file-1', MODE => 0644, CONTENT => "\n");
    mktfile($root . '/file-2', MODE => 0644, CONTENT => "line 0");
    mktfile($root . '/file-3', MODE => 0644, CONTENT => "line 0\n");
    mktfile($root . '/file-4', MODE => 0644, CONTENT => "line 0\nline 1");
    mktfile($root . '/file-5', MODE => 0644, CONTENT => "line 0\nline 1\n");
    mktfile($root . '/file-6', MODE => 0644, CONTENT => "line 0\nline 1\n\n");

    return $root
}


my $source;
my $target;
my $server;
my $backend;

subtest('sandbox 0 local send/recv' => sub {
    $source = make_sandbox_0();
    $server = mktroot();
    $target = mktroot();

    ok($backend = Synctl::backend($server), 'create file backend');
    is($backend->client($source), $source, 'attach client');
    is($backend->send(), 0, 'send from client');

    is($backend->client($target), $target, 'change client');
    is($backend->recv(), 0, 'receive to client');
    is(rdtroot($target), rdtroot($source), 'compare source/target');
});

subtest('sandbox 1 local send/recv' => sub {
    $source = make_sandbox_1();
    $server = mktroot();
    $target = mktroot();

    ok($backend = Synctl::backend($server), 'create file backend');
    is($backend->client($source), $source, 'attach client');
    is($backend->send(), 0, 'send from client');

    is($backend->client($target), $target, 'change client');
    is($backend->recv(), 0, 'receive to client');
    is(rdtroot($target), rdtroot($source), 'compare source/target');
});


1;
__END__
