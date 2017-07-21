#!/usr/bin/perl -l

use strict;
use warnings;

use File::Path qw(remove_tree);

use Synctl;
use Synctl::FileControler;
use Synctl::File::1::Deposit;
use Synctl::File::1::Snapshot;

use t::File;

use Test::More tests => 217;

BEGIN
{
    use_ok('Synctl::File::1::Fsck');
}


Synctl::Configure(VERBOSE => sub {});


sub alloc
{
    my $box = mktroot();
    my ($deposit, $controler);

    mktdir($box . '/snapshots', MODE => 0755);

    $deposit = Synctl::File::1::Deposit->new($box . '/deposit');
    $deposit->init();

    $controler = Synctl::FileControler->new($deposit, $box . '/snapshots');

    return $controler;
}

sub filter
{
    my ($properties) = @_;
    my ($key, %filtered);

    foreach $key (keys(%$properties)) {
	if ($key eq 'MODE') {
	    $filtered{$key} = $properties->{$key};
	}
    }

    return \%filtered;
}


my ($controler, $client);
my (%hashes, $snapshot0, $snapshot1, %counts);
my $fsck;


#------------------------------------------------------------------------------
# Sane server: just to be sure nothing bad happens when we try to fix something
# which already works.

$controler = alloc();
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

ok($fsck, 'instantiation of Fsck');
is($fsck->checkup(), 0, 'checkup on sane server');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'sane server deposit hashes');
is_deeply(\%hashes, { '7fc56270e7a70fa81a5935b72eacbe29' => 1,
		      '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'sane server deposit references');
is($controler->deposit()->get('7fc56270e7a70fa81a5935b72eacbe29'), 2,
   'sane server deposit reference count on A');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'sane server deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'sane server deposit reference count on C');

is($snapshot0->sane(), 1, 'sane server snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'sane server snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file0', 'file1' ],
	  'sane server snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'sane server snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), '7fc56270e7a70fa81a5935b72eacbe29',
   'sane server snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 0 content of /file1');

is($snapshot1->sane(), 1, 'sane server snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'sane server snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'sane server snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'sane server snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'sane server snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'sane server snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Truncated server: a server where we delete a snapshot with "rm -rf"

$controler = alloc();
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
remove_tree($snapshot0->path());
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

is($fsck->checkup(), 0, 'checkup on truncated server');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'truncated server deposit hashes');
is_deeply(\%hashes, { '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'truncated server deposit references');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 3,
   'truncated server deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'truncated server deposit reference count on C');

is($snapshot1->sane(), 1, 'truncated server snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'truncated server snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'truncated server snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'truncated server snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'truncated server snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'truncated server snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'truncated server snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'truncated server snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'truncated server snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'truncated server snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'truncated server snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Recomputable server: a server where we delete all the reference information
# in the deposit

$controler = alloc();
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
remove_tree($controler->deposit()->path() . '/refcount');
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

is($fsck->checkup(), 0, 'checkup on recomputable server');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'recomputable server deposit hashes');
is_deeply(\%hashes, { '7fc56270e7a70fa81a5935b72eacbe29' => 1,
		      '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'recomputable server deposit references');
is($controler->deposit()->get('7fc56270e7a70fa81a5935b72eacbe29'), 2,
   'recomputable server deposit reference count on A');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'recomputable server deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'recomputable server deposit reference count on C');

is($snapshot0->sane(), 1, 'recomputable server snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'recomputable server snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'recomputable server snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'recomputable server snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'recomputable server snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file0', 'file1' ],
	  'recomputable server snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'recomputable server snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), '7fc56270e7a70fa81a5935b72eacbe29',
   'recomputable server snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'recomputable server snapshot 0 content of /file1');

is($snapshot1->sane(), 1, 'recomputable server snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'recomputable server snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'recomputable server snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'recomputable server snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'recomputable server snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'recomputable server snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'recomputable server snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'recomputable server snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'recomputable server snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'recomputable server snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'recomputable server snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Corrupted deposit: a server where some objects are modified / deleted

$controler = alloc();
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
unlink($controler->deposit()->path() .
       '/object/7fc56270e7a70fa81a5935b72eacbe29');
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

is($fsck->checkup(), 1, 'checkup on corrupted deposit');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'corrupted deposit deposit hashes');
is_deeply(\%hashes, { '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'corrupted deposit deposit references');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'corrupted deposit deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'corrupted deposit deposit reference count on C');

is($snapshot0->sane(), 0, 'corrupted deposit snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'corrupted deposit snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'corrupted deposit snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted deposit snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted deposit snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file0', 'file1' ],
	  'corrupted deposit snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'corrupted deposit snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), '7fc56270e7a70fa81a5935b72eacbe29',
   'corrupted deposit snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted deposit snapshot 0 content of /file1');

is($snapshot1->sane(), 1, 'corrupted deposit snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'corrupted deposit snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted deposit snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'corrupted deposit snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'corrupted deposit snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted deposit snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'corrupted deposit snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'corrupted deposit snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted deposit snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'corrupted deposit snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'corrupted deposit snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Corrupted snapshot: a server where some references are modified / deleted

$controler = alloc();
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
unlink($snapshot0->path() . '/content/file0');
unlink($snapshot1->path() . '/property/e8c118fedf0ce7deb764ed4b77b9a0c4');
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

is($fsck->checkup(), 1, 'checkup on corrupted snapshot');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'corrupted snapshot deposit hashes');
is_deeply(\%hashes, { '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'corrupted snapshot deposit references');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'corrupted snapshot deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'corrupted snapshot deposit reference count on C');

is($snapshot0->sane(), 0, 'corrupted snapshot snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'corrupted snapshot snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'corrupted snapshot snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted snapshot snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted snapshot snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file1' ],
	  'corrupted snapshot snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'corrupted snapshot snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), undef,
   'corrupted snapshot snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 0 content of /file1');

is($snapshot1->sane(), 0, 'corrupted snapshot snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'corrupted snapshot snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted snapshot snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'corrupted snapshot snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { },
	  'corrupted snapshot snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted snapshot snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'corrupted snapshot snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'corrupted snapshot snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'corrupted snapshot snapshot 1 content of /file3');


#==============================================================================
# Stub to test partial fsck

{
    package InterruptSnapshot;
    use parent qw(Synctl::File::1::Snapshot);

    sub test_inner     { return shift()->_rw('__test_inner', @_); }
    sub test_interrupt { return shift()->_rw('__test_interrupt', @_); }

    sub _new
    {
	my ($self, $inner) = @_;

	$self->test_inner($inner);
	return $self;
    }

    sub path            { return shift()->test_inner()->path(@_); }
    sub _init           { return shift()->test_inner()->_init(@_); }
    sub _sane           { return shift()->test_inner()->_sane(@_); }
    sub _id             { return shift()->test_inner()->_id(@_); }
    sub _date           { return shift()->test_inner()->_date(@_); }
    sub _set_file       { return shift()->test_inner()->_set_file(@_); }
    sub _set_directory  { return shift()->test_inner()->_set_directory(@_); }
    sub _get_file       { return shift()->test_inner()->_get_file(@_); }
    sub _get_directory  { return shift()->test_inner()->_get_directory(@_); }
    sub _get_properties { return shift()->test_inner()->_get_properties(@_); }
    sub _flush          { return shift()->test_inner()->_flush(@_); }

    sub _checkup
    {
	my ($self, @args) = @_;
	my $int = $self->test_interrupt();

	if (defined($int)) {
	    $int->();
	}

	return $self->test_inner()->_checkup(@args);
    }
}

{
    package InterruptControler;
    use parent qw(Synctl::FileControler);

    sub test_inner      { return shift()->_rw('__test_inner', @_); }
    sub test_interrupts { return shift()->_rw('__test_interrupts', @_); }

    sub _new
    {
	my ($self, $inner) = @_;

	$self->test_inner($inner);
	return $self;
    }

    sub _deposit  { return shift()->test_inner()->_deposit(@_); }
    sub _create   { return shift()->test_inner()->_create(@_); }
    sub _delete   { return shift()->test_inner()->_delete(@_); }

    sub _snapshot
    {
	my ($self, @args) = @_;
	my @snapshots = $self->test_inner()->_snapshot(@args);
	my $interrupts = $self->test_interrupts();
	my ($inner, $outter, $num);

	foreach $num (keys(%$interrupts)) {
	    $inner = $snapshots[$num];
	    $outter = InterruptSnapshot->new($inner);
	    $outter->test_interrupt($self->test_interrupts()->{$num});
	    $snapshots[$num] = $outter;
	}

	return @snapshots;
    }
}

sub alloc_interrupt
{
    my ($interrupts) = @_;
    my $inner = alloc();
    my $outter = InterruptControler->new($inner);

    $outter->test_interrupts($interrupts);

    return $outter;
}

#==============================================================================


#------------------------------------------------------------------------------
# Sane server: partial fsck with no interrupt

$controler = alloc_interrupt({ 0 => sub { $counts{0}++; },
			       1 => sub { $counts{1}++; } });
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

ok($fsck, 'instantiation of Fsck');

ok($fsck->partial(1), 'configuration of partial Fsck');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 0, 'checkup on sane server');
is($counts{0}, 1, 'checkup count on snapshot 0');
is($counts{1}, 1, 'checkup count on snapshot 1');


%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'sane server deposit hashes');
is_deeply(\%hashes, { '7fc56270e7a70fa81a5935b72eacbe29' => 1,
		      '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'sane server deposit references');
is($controler->deposit()->get('7fc56270e7a70fa81a5935b72eacbe29'), 2,
   'sane server deposit reference count on A');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'sane server deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'sane server deposit reference count on C');

is($snapshot0->sane(), 1, 'sane server snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'sane server snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file0', 'file1' ],
	  'sane server snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'sane server snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), '7fc56270e7a70fa81a5935b72eacbe29',
   'sane server snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 0 content of /file1');

is($snapshot1->sane(), 1, 'sane server snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'sane server snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'sane server snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'sane server snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'sane server snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'sane server snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Sane server: partial fsck with interrupt

$controler = alloc_interrupt({ 0 => sub { $counts{0}++; $fsck->interrupt(); },
			       1 => sub { $counts{1}++; }});

$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

ok($fsck, 'instantiation of Fsck');

ok($fsck->partial(1), 'configuration of partial Fsck');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 0, 'checkup on sane server -> interrupted');
is($counts{0}, 1, 'checkup count on snapshot 0');
is($counts{1}, 0, 'checkup count on snapshot 1');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 0, 'checkup on sane server');
is($counts{0}, 0, 'checkup count on snapshot 0');
is($counts{1}, 1, 'checkup count on snapshot 1');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'sane server deposit hashes');
is_deeply(\%hashes, { '7fc56270e7a70fa81a5935b72eacbe29' => 1,
		      '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'sane server deposit references');
is($controler->deposit()->get('7fc56270e7a70fa81a5935b72eacbe29'), 2,
   'sane server deposit reference count on A');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'sane server deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'sane server deposit reference count on C');

is($snapshot0->sane(), 1, 'sane server snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'sane server snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file0', 'file1' ],
	  'sane server snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'sane server snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), '7fc56270e7a70fa81a5935b72eacbe29',
   'sane server snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 0 content of /file1');

is($snapshot1->sane(), 1, 'sane server snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'sane server snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'sane server snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { MODE => 0100666 },
	  'sane server snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'sane server snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'sane server snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'sane server snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'sane server snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'sane server snapshot 1 content of /file3');


#------------------------------------------------------------------------------
# Corrupted snapshot: partial fsck with interrupt

$controler = alloc_interrupt({ 0 => sub { $counts{0}++;$fsck->interrupt();},
			       1 => sub { $counts{1}++;$fsck->interrupt();}});
$client = mktroot();
mktfile($client . '/file0', MODE => 0644, CONTENT => 'A');
mktfile($client . '/file1', MODE => 0755, CONTENT => 'B');
mktdir($client . '/dir0', MODE => 0700);
Synctl::send($client, $controler, sub { return 1; });
($snapshot0) = $controler->snapshot();
unlink($client . '/file0');
mktfile($client . '/file2', MODE => 0600, CONTENT => 'B');
mktfile($client . '/file3', MODE => 0666, CONTENT => 'C');
Synctl::send($client, $controler, sub { return 1; });
($snapshot1) = grep { $_->id() ne $snapshot0->id() } $controler->snapshot();
unlink($snapshot0->path() . '/content/file0');
unlink($snapshot1->path() . '/property/e8c118fedf0ce7deb764ed4b77b9a0c4');
$fsck = Synctl::File::1::Fsck->new($controler->deposit(),
				   $controler->snapshot());

ok($fsck->partial(1), 'configuration of partial Fsck');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 1, 'checkup on corrupted server -> interrupted 0');
is($counts{0}, 1, 'checkup count on snapshot 0');
is($counts{1}, 0, 'checkup count on snapshot 1');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 1, 'checkup on corrupted server -> interrupted 1');
is($counts{0}, 0, 'checkup count on snapshot 0');
is($counts{1}, 1, 'checkup count on snapshot 1');

%counts = (0 => 0, 1 => 0);
is($fsck->checkup(), 0, 'checkup on corrupted snapshot');
is($counts{0}, 0, 'checkup count on snapshot 0');
is($counts{1}, 0, 'checkup count on snapshot 1');

%hashes = ();
is($controler->deposit()->hash(sub { $hashes{shift()} = 1 }), 1,
   'corrupted snapshot deposit hashes');
is_deeply(\%hashes, { '9d5ed678fe57bcca610140957afab571' => 1,
                      '0d61f8370cad1d412f80b84d143e1257' => 1 },
	  'corrupted snapshot deposit references');
is($controler->deposit()->get('9d5ed678fe57bcca610140957afab571'), 4,
   'corrupted snapshot deposit reference count on B');
is($controler->deposit()->get('0d61f8370cad1d412f80b84d143e1257'), 2,
   'corrupted snapshot deposit reference count on C');

is($snapshot0->sane(), 0, 'corrupted snapshot snapshot 0 sane');
is_deeply(filter($snapshot0->get_properties('/')), { MODE => 040700 },
	  'corrupted snapshot snapshot 0 properties of /');
is_deeply(filter($snapshot0->get_properties('/file0')), { MODE => 0100644 },
	  'corrupted snapshot snapshot 0 properties of /file0');
is_deeply(filter($snapshot0->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted snapshot snapshot 0 properties of /file1');
is_deeply(filter($snapshot0->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted snapshot snapshot 0 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot0->get_directory('/')} ],
	  [ 'dir0', 'file1' ],
	  'corrupted snapshot snapshot 0 content of /');
is_deeply($snapshot0->get_directory('/dir0'), [],
	  'corrupted snapshot snapshot 0 content of /dir0');
is($snapshot0->get_file('/file0'), undef,
   'corrupted snapshot snapshot 0 content of /file0');
is($snapshot0->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 0 content of /file1');

is($snapshot1->sane(), 0, 'corrupted snapshot snapshot 1 sane');
is_deeply(filter($snapshot1->get_properties('/')), { MODE => 040700 },
	  'corrupted snapshot snapshot 1 properties of /');
is_deeply(filter($snapshot1->get_properties('/file1')), { MODE => 0100755 },
	  'corrupted snapshot snapshot 1 properties of /file1');
is_deeply(filter($snapshot1->get_properties('/file2')), { MODE => 0100600 },
	  'corrupted snapshot snapshot 1 properties of /file2');
is_deeply(filter($snapshot1->get_properties('/file3')), { },
	  'corrupted snapshot snapshot 1 properties of /file3');
is_deeply(filter($snapshot1->get_properties('/dir0')), { MODE => 040700 },
	  'corrupted snapshot snapshot 1 properties of /dir0');
is_deeply([ sort { $a cmp $b } @{$snapshot1->get_directory('/')} ],
	  [ 'dir0', 'file1', 'file2', 'file3' ],
	  'corrupted snapshot snapshot 1 content of /');
is_deeply($snapshot1->get_directory('/dir0'), [],
	  'corrupted snapshot snapshot 1 content of /dir0');
is($snapshot1->get_file('/file1'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 1 content of /file1');
is($snapshot1->get_file('/file2'), '9d5ed678fe57bcca610140957afab571',
   'corrupted snapshot snapshot 1 content of /file2');
is($snapshot1->get_file('/file3'), '0d61f8370cad1d412f80b84d143e1257',
   'corrupted snapshot snapshot 1 content of /file3');


1;
__END__
