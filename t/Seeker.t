#!/usr/bin/perl -l

use strict;
use warnings;

use POSIX qw(getgid getuid);
use Test::More tests => 11;

use t::File;

BEGIN
{
    use_ok('Synctl::Seeker');
}


my $box = mktroot();
mktfile($box . '/file0', MODE => 0644, CONTENT => 'file0');
mktfile($box . '/file1', MODE => 0755, CONTENT => 'file1');
mktdir($box . '/dir0', MODE => 0700);
mktfile($box . '/dir0/file2', MODE => 0644, CONTENT => 'file2');
mktlink($box . '/link0', 'file0');
mktlink($box . '/dir0/link1', '../file1');
system('ln', $box . '/dir0/file2', $box . '/hlink0');

my $seeker = Synctl::Seeker->new($box);
my $badseek = Synctl::Seeker->new($box . '-unexisting');
my ($user, $group) = (getuid(), getgid());
my (@list, %hash, @elist);

is($badseek->seek(\@list), 0, 'seek on unexisting');

is($seeker->seek(\@list), 8, 'seek to list');
%hash = map { $_->{NAME}, [ $_->{PATH} , $_->{MODE} , $_->{USER} ,
			    $_->{GROUP} ] } @list;
is_deeply(\%hash, { 
    '/'           => [ $box . '/'           ,  040700 , $user , $group ],
    '/file0'      => [ $box . '/file0'      , 0100644 , $user , $group ],
    '/file1'      => [ $box . '/file1'      , 0100755 , $user , $group ],
    '/dir0'       => [ $box . '/dir0'       ,  040700 , $user , $group ],
    '/dir0/file2' => [ $box . '/dir0/file2' , 0100644 , $user , $group ],
    '/link0'      => [ $box . '/link0'      , 0120777 , $user , $group ],
    '/dir0/link1' => [ $box . '/dir0/link1' , 0120777 , $user , $group ],
    '/hlink0'     => [ $box . '/hlink0'     , 0100644 , $user , $group ],
	  }, 'seek to list is correct (mode, user, group)');

%hash = map { $_->{PATH}, $_->{INODE} } @list;
is($hash{'/dir0/file2'}, $hash{'/hlink0'}, 'seek to list is correct (inode)');

is($seeker->seek(\@list, \@elist), 8, 'seek to list with error list');
is(scalar(@elist), 0, 'seek to list gives no error');


ok($seeker->filter(sub { ! m|^/dir| }), 'set filter (code)');
is($seeker->seek(\@list), 5, 'seek to list with filter');


SKIP : {
    skip 'running as root', 2 if ($> == 0);

    mktdir($box . '/forbidden', MODE => 0700);
    mktfile($box . '/forbidden/hidden', MODE => 0644, CONTENT => 'hidden');
    chmod(0, $box . '/forbidden');
    $seeker = Synctl::Seeker->new($box . '/forbidden');
    is($seeker->seek(\@list, \@elist), 1,
       'seek /forbidden to list with error list');
    is(scalar(@elist), 1, 'seek /forbidden to list gives 1 error');
}


1;
__END__
