#!/usr/bin/perl -l

use strict;
use warnings;

use t::Controler;
use t::File;
use t::MockDeposit;

use Test::More tests => 2 + test_controler_count();


BEGIN
{
    use_ok('Synctl::FileControler');
}


my $box = mktroot();
my $deposit = t::MockDeposit->new('', {}, {}, {});
my $controler = Synctl::FileControler->new($deposit, $box);


ok($controler, 'controler initialization');


test_controler($controler);


1;
__END__
