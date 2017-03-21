#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::Snapshot;

use Test::More tests => 1 + test_snapshot_count() + 18;

BEGIN
{
    use_ok('Synctl::File::1::Snapshot');
}


sub alloc
{
    my (@specs) = @_;
    my ($box, $snapshot, $spec);
    my ($path, $type, $content, $props, @rem);

    $box = mktroot();
    $snapshot = Synctl::File::1::Snapshot->new($box . '/snapshot', '0' x 32);
    $snapshot->init();

    foreach $spec (@specs) {
	($path, $type, @rem) = @$spec;

	if ($type eq 'f') {
	    ($content, $props) = @rem;
	    $snapshot->set_file($path, $content, %$props);
	} elsif ($type eq 'd') {
	    ($props) = @rem;
	    $snapshot->set_directory($path, %$props);
	}
    }

    return $snapshot;
}

sub check_properties
{
    my ($a, $b) = @_;
    my ($key, $value);

    if (!defined($a) || !defined($b) ||
	ref($a) ne 'HASH' || ref($b) ne 'HASH') {
	return 0;
    }

    if (scalar(keys(%$a)) != scalar(keys(%$b))) {
	return 0;
    }

    foreach $key (keys(%$a)) {
	$value = $b->{$key};

	if (!defined($value)) {
	    return 0;
	}

	if ($value ne $a->{$key}) {
	    return 0;
	}
    }

    return 1;
}

sub check_entry_count
{
    my ($snapshot, $root) = @_;
    my ($count, $list, $elem, $sep);

    if (!defined($root)) {
	$root = '/';
    }

    if ($root eq '/') {
	$sep  = '';
    } else {
	$sep = '/';
    }

    if ($snapshot->get_properties($root)) {
	$count = 1;
    } else {
	return 0;
    }

    $list = $snapshot->get_directory($root);
    if (defined($list)) {
	foreach $elem (@$list) {
	    $count += check_entry_count($snapshot, $root . $sep . $elem);
	}
    }

    return $count;
}

sub check
{
    my ($snapshot, @specs) = @_;
    my ($spec, $path, $type, $content, $props, @rem);
    my (@checked, $sprops, $size);

    foreach $spec (@specs) {
	($path, $type, @rem) = @$spec;
	push(@checked, $path);

	if ($type eq 'f') {
	    ($content, $props) = @rem;

	    if ($snapshot->get_file($path) ne $content) {
		is($snapshot->get_file($path), $content, 'snapshot content');
		return;
	    }

	} elsif ($type eq 'd') {
	    ($props) = @rem;

	    $sprops = $snapshot->get_properties($path);
	    if (!check_properties($props, $sprops)) {
		is_deeply($props, $sprops, 'snapshot content');
		return;
	    }
	}
    }

    $size = check_entry_count($snapshot);
    if (scalar(@checked) != $size) {
	is(scalar(@checked), $size, 'snapshot content');
	return;
    }

    is(1, 1, 'snapshot content');
}

sub write_content
{
    my ($path, $content) = @_;
    my ($fh);

    if (!open($fh, '>', $path)) {
	die ("$path: $!");
    }

    printf($fh "%s", $content);
    close($fh);
}


my $snapshot;
my ($refcounts);


test_snapshot(\&alloc, \&check);


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1, GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }]);
unlink($snapshot->path() . '/property/6666cd76f96956469e7be39d750cc7d9');
is_deeply($snapshot->checkup($refcounts), [ '/' ],
	  'removal of directory properties checked');
is_deeply($refcounts, {}, 'removal of directory properties handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1, GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }]);
write_content($snapshot->path() . '/property/6666cd76f96956469e7be39d750cc7d9',
	      "bad content\n");
is_deeply($snapshot->checkup($refcounts), [ '/' ],
	  'corruption of directory properties checked');
is_deeply($refcounts, {}, 'corruption of directory properties handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1, GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }]);
write_content($snapshot->path() . '/property/badref', "MODE => 644\n");
is_deeply($snapshot->checkup($refcounts), [ 'badref' ],
	  'addition of properties checked');
is_deeply($refcounts, {}, 'addition of properties handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', '00000000000000000000000000000000',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }]);
unlink($snapshot->path() . '/property/0639767f3e9eaad729b54037a7e2abf5');
is_deeply($snapshot->checkup($refcounts), [ '/a' ],
	  'removal of file properties checked');
is_deeply($refcounts, { '00000000000000000000000000000000' => 1 },
	  'removal of file properties handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', 'badref',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }]);
is_deeply($snapshot->checkup($refcounts), [ '/a' ],
	  'modification of file content checked');
is_deeply($refcounts, {}, 'modification of file content handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', '00000000000000000000000000000000',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }]);
unlink($snapshot->path() . '/content/a');
is_deeply($snapshot->checkup($refcounts), ['0639767f3e9eaad729b54037a7e2abf5'],
	  'removal of file content checked');
is_deeply($refcounts, {}, 'removal of file content handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', '00000000000000000000000000000000',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }]);
is_deeply($snapshot->checkup($refcounts), [], 'no error checked');
is_deeply($refcounts, { '00000000000000000000000000000000' => 1 },
	  'no error handled');


$refcounts = {};
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', '00000000000000000000000000000000',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }],
		  ['/b', 'f', '00000000000000000000000000000000',
		   { MODE => 755, USER => 3 , GROUP => 3,
		     MTIME => 40, INODE => 2, SIZE => 12 }]);
is_deeply($snapshot->checkup($refcounts), [], 'no error multiref checked');
is_deeply($refcounts, { '00000000000000000000000000000000' => 2 },
	  'no error multiref handled');


$refcounts = { '11111111111111111111111111111111' => 3,
	       '00000000000000000000000000000000' => 6 };
$snapshot = alloc(['/', 'd', { MODE => 755, USER => 1 , GROUP => 1,
			       MTIME => 30, INODE => 1, SIZE => 4096 }],
		  ['/a', 'f', '00000000000000000000000000000000',
		   { MODE => 644, USER => 1 , GROUP => 1,
		     MTIME => 30, INODE => 1, SIZE => 12 }]);
is_deeply($snapshot->checkup($refcounts), [], 'no error not empty checked');
is_deeply($refcounts, { '11111111111111111111111111111111' => 3,
                        '00000000000000000000000000000000' => 7 },
	  'no error not empty handled');


1;
__END__
