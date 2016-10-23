#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::Snapshot;

use Test::More tests => 6 + test_snapshot_count();;

BEGIN
{
    use_ok('Synctl::FileSnapshot');
}


my $box = mktroot();
my $path = $box . '/snapshot';
my $snapshot = Synctl::FileSnapshot->new($path);
my $eviltwin = Synctl::FileSnapshot->new($path);


ok($snapshot, 'snapshot instantiation');
ok($eviltwin, 'eviltwin instantiation');

is($snapshot->date(), undef, 'date on nothing');

ok($snapshot->init(), 'init from nothing');
ok(!$eviltwin->init(), 'init on existing (different object)');


test_snapshot($snapshot);


1;
__END__
