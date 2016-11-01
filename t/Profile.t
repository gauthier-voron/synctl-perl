#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 52;

use t::File;


BEGIN
{
    use_ok('Synctl::Profile');
}


my $profile;
my @list;
my $list;
my $filter;
my $box;
my ($fh, $scalar, @array);


ok($profile = Synctl::Profile->new(), 'initialize with no parameter');
is($profile->client(), undef, 'client on empty profile');
is($profile->server(), undef, 'server on empty profile');
is_deeply($profile->filters(), [], 'filters on empty profile');


is_deeply($profile->filters([]), [], 'flush the filters list');
@list = ( '/a' );
is_deeply([ $profile->exclude(@list) ], \@list, 'exclude a new scalar list');
is_deeply($profile->filters(), [ '-/a' ],
	  'filters list after exclude scalar list');

$filter = $profile->filter();
is(ref($filter), 'CODE', 'filter with empty include and scalar exclude');
is($filter->('/a'), 0, 'filter on affected path path (/a => /a)');
is($filter->('/ab'), 1, 'filter on not affected path (/a => /ab)');
is($filter->('/c'), 1, 'filter on not affected path (/a => /c)');


$profile->filters([]);
@list = ( '/a?b', '/c*', '/*/d' , '/**/e' );
is_deeply([ $profile->exclude(@list) ], \@list, 'exclude a new glob list');

$filter = $profile->filter();
is(ref($filter), 'CODE', 'filter with empty include and glob exclude');
is($filter->('/ab'), 1, 'filter on not affected path (/a?b => /ab)');
is($filter->('/axxb'), 1, 'filter on not affected path (/a?b => /axxb)');
is($filter->('/axb'), 0, 'filter on affected path (/a?b => /axb)');
is($filter->('/c'), 0, 'filter on affected path (/c* => /c)');
is($filter->('/cx'), 0, 'filter on affected path (/c* => /cx)');
is($filter->('/cxx'), 0, 'filter on affected path (/c* => /cxx)');
is($filter->('/c/x'), 1, 'filter on not affected path (/c* => /c/x)');
is($filter->('/x/d'), 0, 'filter on affected path (/*/d => /x/d)');
is($filter->('/xxx/d'), 0, 'filter on affected path (/*/d => /xxx/d)');
is($filter->('/d'), 1, 'filter on not affected path (/*/d => /d)');
is($filter->('/x/xd'), 1, 'filter on not affected path (/*/d => /x/xd)');
is($filter->('/x/y/d'), 1, 'filter on not affected path (/*/d => /x/y/d)');
is($filter->('/x/e'), 0, 'filter on affected path (/**/e => /x/e)');
is($filter->('/xxx/e'), 0, 'filter on affected path (/**/e => /xxx/e)');
is($filter->('/e'), 1, 'filter on not affected path (/**/e => /e)');
is($filter->('/x/xe'), 1, 'filter on not affected path (/**/e => /x/xe)');
is($filter->('/x/y/e'), 0, 'filter on affected path (/**/e => /x/y/e)');


$profile->filters([]);
$profile->exclude('/a', '/cxy*');
$profile->include('/b', '/cx*');
$profile->exclude('/b', '/c*');

$filter = $profile->filter();
is(ref($filter), 'CODE', 'filter with glob include and glob exclude');
is($filter->('/a'), 0, 'filter on affected path (/a => /a)');
is($filter->('/b'), 1, 'filter on conflict path (/b | /b => /b)');
is($filter->('/cm'), 0, 'filter on affected path (/c* => /cm)');
is($filter->('/cxm'), 1, 'filter on conflict path (/cx* | /c* => /cxm)');
is($filter->('/cxy'), 0, 'filter on conflict path (/cx* | /cxy* => /cxy)');
is($filter->('/cxym'), 0, 'filter on conflict path (/cx* | /cxy* => /cxym)');


$profile->filters([]);
$profile->include('b/c$');
$profile->exclude('^/a[bc]?', 'de');

$filter = $profile->filter();
is(ref($filter), 'CODE', 'filter with regex include and regex exclude');
is($filter->('/a'), 0, 'filter on affected path (^/a[bc]? => /a)');
is($filter->('/ab/xy'), 0, 'filter on affected path (^/a[bc]? => /ab/xy)');
is($filter->('/xy/xdey/xy'), 0, 'filter on affected path (de => /xy/xdey/xy)');
is($filter->('/ab/c'), 1,'filter on conflict path (b/c$ | ^/a[bc]? => /ab/c)');
is($filter->('/xdeb/c'), 1, 'filter on conflict path (b/c$ | de => /xdeb/c)');


$box = mktroot();

mktfile($box . '/config-simple', CONTENT => <<"EOF");
server = /a
client = /b
include = /c*
exclude = /d
exclude = /e
EOF
if (!open($fh, '<', $box . '/config-simple')) { die ($!); }
ok($profile->read($fh), 'read from stream');
close($fh);
is($profile->server(), '/a', 'simple config server');
is($profile->client(), '/b', 'simple config client');
is_deeply($profile->filters(), [ '+/c*', '-/d', '-/e' ],
	  'simple config filters');

$scalar = <<"EOF";
# Plain line comment
    # Space beginning comment
# Now an empty line

server = /A     # End line comment
# In-between comment
client = /B  # # # Multi-dash comment
# include = commented-out
EOF
ok($profile->read($scalar), 'read from scalar');
is($profile->server(), '/A', 'comment config server');
is($profile->client(), '/B', 'comment config client');
is_deeply($profile->filters(), [], 'comment config filters');


1;
__END__
