#!/usr/bin/perl -l

use strict;
use warnings;

use t::Deposit;
use t::File;

use Test::More tests => 3 + test_deposit_count();


BEGIN
{
    use_ok('Synctl::FileDeposit');
}


my $box = mktroot();
my $path = $box . '/deposit';
my $deposit = Synctl::FileDeposit->new($path);
my $eviltwin = Synctl::FileDeposit->new($path);


ok($deposit, 'deposit instanciation');
ok($eviltwin, 'eviltwin instanciation');


test_deposit($deposit, $eviltwin);


1;
__END__
