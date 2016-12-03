package t::Snapshot;

use strict;
use warnings;

use t::File;

use Test::More;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(test_snapshot_count test_snapshot);


sub test_snapshot_count
{
    return 8  # snapshot#0
	+ 12  # snapshot#1
	+ 13  # snapshot#2
        +  1; # snapshot#3
}

sub test_snapshot
{
    my ($alloc, $check) = @_;
    my ($snapshot, $content, $properties, $dir, $file, @list);

    # snapshot#0
    $snapshot = $alloc->();
    like($snapshot->date(), qr/^\d{4}(-\d\d){5}(-.*)?$/, 'date on existing');
    is($snapshot->get_directory('/'), undef, 'get root directory when empty');
    is($snapshot->get_file('/a'), undef, 'get some file when empty');
    is($snapshot->get_properties('/'), undef, 'get dir properties on empty');
    is($snapshot->get_properties('/a'), undef, 'get file properties on empty');
    is($snapshot->set_file('/a', ''), undef,'set some file when no parent');
    is($snapshot->set_file('/', ''), undef, 'set root as a file');
    $check->($snapshot);

    # snapshot#1
    $snapshot = $alloc->();
    ok($snapshot->set_directory('/'), 'set root directory');
    ok($snapshot->set_file('/a', ''), 'set empty file');
    ok($snapshot->set_file('/b', 'b'), 'set full file');
    ok($snapshot->set_directory('/c'), 'set directory');
    ok($snapshot->set_file('/d', '', USER => 5), 'set file with properties');
    ok($snapshot->set_directory('/e', USER => 6),
       'set directory with properties');
    is($snapshot->set_directory('/'), undef, 'reset root directory');
    is($snapshot->set_file('/a', ''), undef, 'reset empty file as empty');
    is($snapshot->set_directory('/a'), undef, 'reset empty file as directory');
    is($snapshot->set_file('/c', ''), undef, 'reset directory as empty file');
    is($snapshot->set_directory('/c'), undef, 'reset directory as directory');
    $check->($snapshot,
	     [ '/'  , 'd'       , {           } ],
	     [ '/a' , 'f' , ''  , {           } ],
	     [ '/b' , 'f' , 'b' , {           } ],
	     [ '/c' , 'd'       , {           } ],
	     [ '/d' , 'f' , ''  , { USER => 5 } ],
	     [ '/e' , 'd'       , { USER => 6 } ]);

    # snapshot#2
    $snapshot = $alloc->(
	[ '/'  , 'd'       , { USER => 0 } ],
	[ '/a' , 'f' , ''  , { USER => 1 } ],
	[ '/b' , 'f' , 'b' , { USER => 2 } ],
	[ '/c' , 'd'       , { USER => 3 } ]);
    is($snapshot->get_file('/'), undef, 'get file on root directory');
    is_deeply([ sort { $a cmp $b } @{$snapshot->get_directory('/')} ],
	      [ 'a' , 'b' , 'c' ], 'get directory on root directory');
    is_deeply($snapshot->get_properties('/'), { USER => 0 },
	      'get properties on root directory');
    is($snapshot->get_file('/a'), '', 'get file on empty file');
    is($snapshot->get_directory('/a'), undef, 'get directory on empty file');
    is_deeply($snapshot->get_properties('/a'), { USER => 1 },
	      'get properties on empty file');
    is($snapshot->get_file('/b'), 'b', 'get file on full file');
    is($snapshot->get_directory('/a'), undef, 'get directory on full file');
    is_deeply($snapshot->get_properties('/b'), { USER => 2 },
	      'get properties on full file');
    is($snapshot->get_file('/c'), undef, 'get file on directory');
    is_deeply($snapshot->get_directory('/c'), [ ],
	      'get directory on directory');
    is_deeply($snapshot->get_properties('/c'), { USER => 3 },
	      'get properties on directory');
    $check->($snapshot,
	     [ '/'  , 'd'       , { USER => 0 } ],
	     [ '/a' , 'f' , ''  , { USER => 1 } ],
	     [ '/b' , 'f' , 'b' , { USER => 2 } ],
	     [ '/c' , 'd'       , { USER => 3 } ]);

    # snapshot#3
    $snapshot = $alloc->([ '/' , 'd' , {} ]);
    $snapshot->set_directory('/usr');
    $snapshot->set_directory('/usr/local');
    $snapshot->set_directory('/usr/local/share');
    $snapshot->set_directory('/usr/local/share/chroot');
    $snapshot->set_directory('/usr/local/share/chroot/usr');
    @list = (
	[ '/'                           , 'd' , {} ],
	[ '/usr'                        , 'd' , {} ],
	[ '/usr/local'                  , 'd' , {} ],
	[ '/usr/local/share'            , 'd' , {} ],
	[ '/usr/local/share/chroot'     , 'd' , {} ],
	[ '/usr/local/share/chroot/usr' , 'd' , {} ]
	);
    foreach $dir (qw(bin boot dev etc home lib lib64 mnt opt proc root)) {
	$snapshot->set_directory('/usr/local/share/chroot/usr/' . $dir,
				 MODE => 040755, USER => 'root',
				 GROUP => 'wheel');
	push(@list, [ '/usr/local/share/chroot/usr/' . $dir , 'd' ,
		      { MODE => 040755, USER => 'root', GROUP => 'wheel'} ]);
	foreach $file (qw(README INSTALL LICENCE Makefile configure HOWTO
		       Makefile.in main.c Main.hs main.pl main.cxx main.py)) {
	    $snapshot->set_file('/usr/local/share/chroot/usr/' . $dir .
				'/' . $file, $file, MODE => 0100644,
				USER => 'root', GROUP => 'wheel');
	push(@list, [ '/usr/local/share/chroot/usr/' . $dir . '/' . $file ,
		      'f' , $file ,
		      { MODE => 0100644, USER => 'root', GROUP => 'wheel'} ]);
	}
    }
    $check->($snapshot, @list);
}


1;
__END__
