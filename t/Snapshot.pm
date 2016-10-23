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
    return 23;
}

sub test_snapshot
{
    my ($snapshot) = @_;
    my ($properties, $content);

    
    ok(!$snapshot->init(), 'init on existing');

    like($snapshot->date(), qr/^\d{4}(-\d\d){5}(-.*)?$/, 'date on existing');


    is($snapshot->get_directory('/'), undef, 'get root directory when empty');
    is($snapshot->get_file('/toto'), undef, 'get some file when empty');
    is($snapshot->get_properties('/toto'), undef, 'get properties when empty');


    is($snapshot->set_file('/toto', ''), undef,'set some file when no parent');
    is($snapshot->set_file('/', ''), undef, 'set root as a file');

    ok($snapshot->set_directory('/'), 'set root directory');
    ok($snapshot->set_file('/file', ''), 'set empty file');

    is($snapshot->set_directory('/'), undef, 'cannot set directory twice');
    is($snapshot->set_directory('/file'), undef, 'cannot set file twice');


    is($snapshot->set_file('/bad/', ''), undef, 'set trailing slash file');
    is($snapshot->set_file('/./bad', ''), undef, 'set single-doted file');
    is($snapshot->set_file('/../bad', ''), undef, 'set double-doted file');
    is($snapshot->set_file('//bad', ''), undef, 'set double-slashed file');


    ok($snapshot->set_directory('/dir',
				MODE => 040755, USER => 'nobody',
				GROUP => 'root', MTIME => 42, INODE => 23),
       'set directory with properties');

    $properties = $snapshot->get_properties('/dir');
    is_deeply($properties, { MODE => 040755, USER => 'nobody', GROUP => 'root',
			     MTIME => 42, INODE => 23 },
	      'get directory properties');


    ok($snapshot->set_file('/dir/file0', 'file 0 content',
			   MODE => 0100644, USER => 'daemon', GROUP => 'adm',
			   MTIME => 74, INODE => 19),
       'set file with content and properties');

    $properties = $snapshot->get_properties('/dir/file0');
    is_deeply($properties, { MODE => 0100644, USER => 'daemon', GROUP => 'adm',
			     MTIME => 74, INODE => 19 },
	      'get file properties');

    $content = $snapshot->get_file('/dir/file0');
    is($content, 'file 0 content', 'get file content');


    $content = $snapshot->get_directory('/dir/file0');
    is($content, undef, 'get directory content on file');

    $content = $snapshot->get_directory('/dir');
    is_deeply($content, [ 'file0' ], 'get directory content');

    $content = $snapshot->get_file('/dir');
    is_deeply($content, undef, 'get file content on directory');
}


1;
__END__
