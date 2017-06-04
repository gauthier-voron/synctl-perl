#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 26;

use t::File;

use Synctl::Seeker;

BEGIN
{
    use_ok('Synctl::Util::Status');
}


my ($seeker, $status, $content, $error, $cwd);

Synctl::Configure(ERROR => sub { $error = 1; });

my $box = mktroot();
mktdir ($box . '/unrelated');
mktdir ($box . '/client');
mktlink($box . '/clink', 'client');
mktlink($box . '/dlink', 'client/dir0');
mktdir ($box . '/client/dir0');
mktfile($box . '/client/dir0/file0');
mktfile($box . '/client/file0');
mktfile($box . '/client/file1');

$seeker = Synctl::Seeker->new($box . '/client');
ok($status = Synctl::Util::Status->new(), 'new status');
ok($status->porcelain(1), 'status porcelain mode');
close(STDOUT);


$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/client'), 1, 'status on root return');
close(STDOUT);
is($content, <<EOF, 'status on root print');
i .
e ..
i dir0
i file0
i file1
EOF
is(scalar(grep { ! /^\S\S*( \S+)* (\.|\.\.|dir0|file0|file1)$/ }
	  split("\n", $content)), 0, 'status compatibility');

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/client/dir0'), 1,
   'status on subdir return');
close(STDOUT);
is($content, <<EOF, 'status on subdir print');
i .
i ..
i file0
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/client/file0'), 1,
   'status on file return');
close(STDOUT);
is($content, <<"EOF", 'status on file print');
i $box/client/file0
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/clink'), 1,
   'status on root through link return');
close(STDOUT);
is($content, <<EOF, 'status on root through link print');
i .
e ..
i dir0
i file0
i file1
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/dlink'), 1,
   'status on subdir through link return');
close(STDOUT);
is($content, <<EOF, 'status on subdir through link print');
i .
i ..
i file0
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/client/fake'), undef,
   'status on fake return');
close(STDOUT);
is($error, 1, 'status on fake error');

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box), 1, 'status on parent dir return');
close(STDOUT);
is($content, <<EOF, 'status on parent dir print');
e .
e ..
i client
e clink
e dlink
e unrelated
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, $box . '/unrelated'), 1,
   'status on unrelated return');
close(STDOUT);
is($content, <<EOF, 'status on unrelated print');
e .
e ..
EOF

$cwd = $ENV{PWD};
chdir($box . '/client');

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, '.'), 1,
   'status on root relative return');
close(STDOUT);
is($content, <<EOF, 'status on root relative print');
i .
e ..
i dir0
i file0
i file1
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, 'dir0'), 1,
   'status on subdir relative return');
close(STDOUT);
is($content, <<EOF, 'status on subdir relative print');
i .
i ..
i file0
EOF

$error = undef;
$content = undef;
open(STDOUT, '>', \$content) or die ("cannot open stdout: $!");
is($status->execute($seeker, 'dir0/file0'), 1,
   'status on subfile relative return');
close(STDOUT);
is($content, <<EOF, 'status on subfile relative print');
i dir0/file0
EOF

chdir($cwd);


1;
__END__
