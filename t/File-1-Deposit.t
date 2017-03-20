#!/usr/bin/perl -l

use strict;
use warnings;

use t::Deposit;
use t::File;

use Test::More tests => 6 + test_deposit_count() + 24;


BEGIN
{
    use_ok('Synctl::File::1::Deposit');
}


sub alloc
{
    my (@contents) = @_;
    my $box = mktroot();
    my $path = $box . '/deposit';
    my ($content, @refs);
    my $deposit = Synctl::File::1::Deposit->new($path);

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

sub read_content
{
    my ($path) = @_;
    my ($fh, $count);

    if (!open($fh, '<', $path)) {
	return undef;
    }

    chomp($count = <$fh>);
    close($fh);

    return $count;
}

sub write_content
{
    my ($path, $count) = @_;
    my ($fh);

    if (!open($fh, '>', $path)) {
	die ("$path: $!");
    }

    printf($fh "%s", $count);
    close($fh);
}



my $box = mktroot();
my $path = $box . '/deposit';
my $deposit = Synctl::File::1::Deposit->new($path);
my $eviltwin = Synctl::File::1::Deposit->new($path);
my $ref;


ok($deposit, 'deposit instanciation');
ok($eviltwin, 'eviltwin instanciation');

ok($deposit->init(), 'init from nothing');
ok(!$deposit->init(), 'init on existing (same object)');
ok(!$eviltwin->init(), 'init on existing (different object)');


test_deposit(\&alloc, \&check);


$ref = '7fc56270e7a70fa81a5935b72eacbe29';

$deposit = alloc('A');
$path = $deposit->path() . '/refcount/' . $ref;
unlink($path);
is_deeply($deposit->checkup({ $ref => 1 }), [],
	  'removal of refcount file checked');
is(read_content($path), '1', 'removal of refcount file fixed');

$deposit = alloc('A');
$path = $deposit->path() . '/refcount/' . $ref;
is_deeply($deposit->checkup({}), [], 'addition of refcount file checked');
ok(!(-e $path), 'addition of refcount file fixed');

$deposit = alloc('A');
$path = $deposit->path() . '/refcount/' . $ref;
write_content($path, '2');
is_deeply($deposit->checkup({ $ref => 1 }), [],
	  'modification of refcount file checked');
is(read_content($path), '1', 'modification of refcount file fixed');

$deposit = alloc('A');
$path = $deposit->path() . '/refcount/' . $ref;
rename($path, $deposit->path() . '/refcount/badname');
is_deeply($deposit->checkup({ $ref => 1 }), [],
	  'renaming of refcount file checked');
ok(-e $path, 'renaming of refcount file fixed');
ok(!(-e $deposit->path() . '/refcount/badname'),
   'renaming of refcount file fixed for badname');


$deposit = alloc('A');
$path = $deposit->path() . '/object/' . $ref;
unlink($path);
is_deeply($deposit->checkup({ $ref => 1 }), [ $ref ],
	  'removal of object file checked');
ok(!(-e $deposit->path() . '/refcount/' . $ref),
   'removal of object file fixed');

$deposit = alloc('A');
$path = $deposit->path() . '/object/' . $ref;
is_deeply($deposit->checkup({}), [], 'addition of object file checked');
ok(!(-e $path), 'addition of object file fixed');

$deposit = alloc('B');
$path = $deposit->path() . '/object/' . $ref;
is_deeply($deposit->checkup({ $ref => 1 }), [ $ref ],
	  'modification of object file checked');
ok(!(-e $path), 'modification of object file fixed');
ok(!(-e $deposit->path() . '/refcount/' . $ref),
   'modification of object file fixed for refcount');

$deposit = alloc('A');
$path = $deposit->path() . '/object/' . $ref;
rename($path, $deposit->path() . '/object/badname');
is_deeply($deposit->checkup({ $ref => 1 }), [],
	  'renaming of object file checked');
ok(-e $path, 'renaming of object file fixed');
ok(!(-e $deposit->path() . '/object/badname'),
   'renaming of object file fixed for badname');


$deposit = alloc('A');
rename($deposit->path() . '/refcount/' . $ref,
       $deposit->path() . '/refcount/badname');
rename($deposit->path() . '/object/' . $ref,
       $deposit->path() . '/object/badname');
is_deeply($deposit->checkup({ $ref => 1 }), [],
	  'renaming of refcount/object file checked');
ok(-e ($deposit->path() . '/refcount/' . $ref),
   'renaming of refcount/object file fixed for refcount');
ok(-e ($deposit->path() . '/object/' . $ref),
   'renaming of refcount/object file fixed for object');
ok(!(-e $deposit->path() . '/refcount/badname'),
     'renaming of refcount/object file fixed for refcount badname');
ok(!(-e $deposit->path() . '/object/badname'),
     'renaming of refcount/object file fixed for object badname');


1;
__END__
