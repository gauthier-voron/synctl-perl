package t::Deposit;

use strict;
use warnings;

use t::File;

use Test::More;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(test_deposit_count test_deposit);


sub test_deposit_count
{
    return 21;
}

sub test_deposit
{
    my ($deposit, $eviltwin) = @_;
    my $box = mktroot();
    my $file0 = mktfile($box . '/file0', CONTENT => "file\ncontent\n");
    my $file1 = mktfile($box . '/file1');
    my (@hashes, $hash0, $hash1);
    my ($content, $fh, %cmphash);


    ok($deposit->init(), 'init from nothing');

    ok(!$deposit->init(), 'init on existing (same object)');
    ok(!$eviltwin->init(), 'init on existing (different object)');


    ok($deposit->hash(\@hashes), 'get hash on list ref when empty');
    is(scalar(@hashes), 0, 'no hash returned when empty');


    $hash0 = $deposit->send("some\nlines");
    like($hash0, qr/^[0-9a-f]{32}$/, 'send from scalar');

    open($fh, '<', $file0);
    $hash1 = $deposit->send($fh);
    close($fh);
    like($hash1, qr/^[0-9a-f]{32}$/, 'send from filehandle');


    ok($deposit->hash(\@hashes), 'get hash on list ref');
    %cmphash = map { $_, 1 } @hashes;
    is_deeply(\%cmphash, { $hash0 => 1,
			   $hash1 => 1 }, 'hash on list ref are corrects');


    ok($deposit->recv($hash0, \$content), 'recv on scalar ref');
    is($content, "some\nlines", 'recv on scalar ref is correct');

    open($fh, '>', $file1);
    ok($deposit->recv($hash1, $fh), 'recv on filehandle');
    close($fh);
    is(`diff $file0 $file1`, '', 'recv on filehandle ref is correct');

    is($deposit->recv('0' x 32, \$content), undef, 'recv unexisting');


    is($deposit->get($hash0), 2, 'get increment ref count (same object)');
    is($eviltwin->get($hash0), 3,'get increment ref count (different object)');
    is($deposit->get('0' x 32), undef, 'get on unexisting');

    is($deposit->put($hash0), 2, 'put decrement ref count (same object)');
    is($eviltwin->put($hash0), 1,'put decrement ref count (different object)');

    $deposit->put($hash0);
    $deposit->hash(\@hashes);
    is(scalar(@hashes), 1, 'put erase the object when no ref');

    is($deposit->put($hash0), undef, 'put on unexisting');
}


1;
__END__
