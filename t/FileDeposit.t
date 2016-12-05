#!/usr/bin/perl -l

use strict;
use warnings;

use t::Deposit;
use t::File;

use Test::More tests => 6 + test_deposit_count();


BEGIN
{
    use_ok('Synctl::FileDeposit');
}


sub alloc
{
    my (@contents) = @_;
    my $box = mktroot();
    my $path = $box . '/deposit';
    my ($content, @refs);
    my $deposit = Synctl::FileDeposit->new($path);

    $deposit->init();

    foreach $content (@contents) {
	push(@refs, $deposit->send($content));
    }

    if (wantarray()) {
	return ($deposit, @refs);
    } else {
	return $deposit;
    }
}

sub check
{
    my ($deposit, %refs) = @_;
    my ($ref, $count, $ok, $hash);

    $ok = 1;
    foreach $ref (keys(%refs)) {
	$count = $refs{$ref};
	$hash = $deposit->send($ref);
	while ($deposit->put($hash)) {
	    $count--;
	}

	if ($count > 0) {
	    is($refs{$ref} - $count, $refs{$ref}, 'deposit content');
	    return 0;
	}
    }

    ok(1, 'deposit content');

    return 1;
}



my $box = mktroot();
my $path = $box . '/deposit';
my $deposit = Synctl::FileDeposit->new($path);
my $eviltwin = Synctl::FileDeposit->new($path);


ok($deposit, 'deposit instanciation');
ok($eviltwin, 'eviltwin instanciation');

ok($deposit->init(), 'init from nothing');
ok(!$deposit->init(), 'init on existing (same object)');
ok(!$eviltwin->init(), 'init on existing (different object)');


test_deposit(\&alloc, \&check);


1;
__END__
