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
    return 13  # deposit#0
	+   5  # deposit#1
	+   2  # deposit#2
	+   2  # deposit#3
	+   2  # deposit#4
	+   7  # deposit#5
	+   5  # deposit#6
	+   7  # deposit#7
	+   3  # deposit#8
	+   6  # deposit#9
	+   4; # deposit#10
}

sub test_deposit
{
    my ($alloc, $check) = @_;
    my ($deposit, @hashes, $hash0);

    # deposit#0
    $deposit = $alloc->();
    is($deposit->get('0' x 32), undef, 'deposit#0 get');
    is($deposit->put('0' x 32), undef, 'deposit#0 put');
    like(($hash0=$deposit->send('a')),qr/^[0-9a-f]{32}$/,'deposit#0 send');
    ok($deposit->get($hash0), 'deposit#0 get on exist 1');
    ok($deposit->get($hash0), 'deposit#0 get on exist 2');
    is($deposit->get('0' x 32), undef, 'deposit#0 get on unexist');
    is($deposit->send('a'), $hash0, 'deposit#0 send on exist 3');
    ok($deposit->put($hash0), 'deposit#0 put on exist 4');
    ok($deposit->put($hash0), 'deposit#0 put on exist 3');
    ok($deposit->put($hash0), 'deposit#0 put on exist 2');
    is($deposit->put($hash0), 0, 'deposit#0 put on exist 1');
    is($deposit->put($hash0), undef, 'deposit#0 put');
    $check->($deposit);

    # deposit#1
    $deposit = $alloc->();
    like(($hash0=$deposit->send('a')),qr/^[0-9a-f]{32}$/,'deposit#1 send');
    ok($deposit->get($hash0), 'deposit#1 get on exist 1');
    ok($deposit->get($hash0), 'deposit#1 get on exist 2');
    ok($deposit->put($hash0), 'deposit#1 put on exist 3');
    $check->($deposit, 'a' => 2);

    # deposit#2
    ($deposit, $hash0) = $alloc->('a');
    is($deposit->put($hash0), 0, 'deposit#2 put on exist 1');
    $check->($deposit);

    # deposit#3
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->get($hash0), 'deposit#3 get on exist 1');
    $check->($deposit, 'a' => 2);

    # deposit#4
    ($deposit, $hash0) = $alloc->('a');
    is($deposit->send('a'), $hash0, 'deposit#4 send on exist 1');
    $check->($deposit, 'a' => 2);

    # deposit#5
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->hash(\@hashes), 'deposit#5 hash');
    is(scalar(@hashes), 1, 'deposit#5 hashlist size');
    is($hashes[0], $hash0, 'deposit#5 hashlist content');
    ok($deposit->get($hash0), 'deposit#5 get on exist 1');
    ok($deposit->get($hash0), 'deposit#5 get on exist 2');
    ok($deposit->put($hash0), 'deposit#5 put on exist 3');
    $check->($deposit, 'a' => 2);

    # deposit#6
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->hash(\@hashes), 'deposit#6 hash');
    is(scalar(@hashes), 1, 'deposit#6 hashlist size');
    is($hashes[0], $hash0, 'deposit#6 hashlist content');
    is($deposit->put($hash0), 0, 'deposit#6 put on exist 1');
    $check->($deposit);

    # deposit#7
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->hash(\@hashes), 'deposit#7 hash');
    is(scalar(@hashes), 1, 'deposit#7 hashlist size');
    is($hashes[0], $hash0, 'deposit#7 hashlist content');
    ok($deposit->get($hash0), 'deposit#7 get on exist 1');
    ok($deposit->put($hash0), 'deposit#7 put on exist 2');
    is($deposit->put($hash0), 0, 'deposit#7 put on exist 1');
    $check->($deposit);

    # deposit#8
    ($deposit, $hash0) = $alloc->('a');
    is($deposit->put($hash0), 0, 'deposit#8 put on exist 1');
    is($deposit->send('a'), $hash0, 'deposit#8 send on unexist');
    $check->($deposit, 'a' => 1);

    # deposit#9
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->hash(\@hashes), 'deposit#9 hash');
    is(scalar(@hashes), 1, 'deposit#9 hashlist size');
    is($hashes[0], $hash0, 'deposit#9 hashlist content');
    is($deposit->put($hash0), 0, 'deposit#9 put on exist 1');
    is($deposit->send('a'), $hash0, 'deposit#9 send on unexist');
    $check->($deposit, 'a' => 1);

    # deposit#10
    ($deposit, $hash0) = $alloc->('a');
    ok($deposit->hash(\@hashes), 'deposit#10 hash');
    is(scalar(@hashes), 1, 'deposit#10 hashlist size');
    is($hashes[0], $hash0, 'deposit#10 hashlist content');
    $check->($deposit, 'a' => 1);
}


1;
__END__
