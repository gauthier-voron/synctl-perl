#!/usr/bin/perl -l

use strict;
use warnings;

use t::File;
use t::Snapshot;

use Test::More tests => 1 + test_snapshot_count();;

BEGIN
{
    use_ok('Synctl::FileSnapshot');
}


sub alloc
{
    my (@specs) = @_;
    my ($box, $snapshot, $spec);
    my ($path, $type, $content, $props, @rem);

    $box = mktroot();
    $snapshot = Synctl::FileSnapshot->new($box . '/snapshot', '0' x 32);
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


test_snapshot(\&alloc, \&check);


1;
__END__
