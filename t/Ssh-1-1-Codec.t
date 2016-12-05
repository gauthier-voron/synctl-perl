#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 43;

use t::File;


BEGIN
{
    use_ok('Synctl::Ssh::1::1::Codec');
}


my ($scalar, $ref);
my ($connection, $in, $out);
my ($fh, @arr, @ret, $scal, $map, $text);
my $box = mktroot();


                         is(encode('scalar'), 'S6:scalar', 'encode scalar');
                         is(encode(''), 'S0:', 'encode empty scalar');
                         is(encode(381), 'S3:381', 'encode number');
                         is(encode(':'), 'S1::', 'encode sign');
                         is(encode(undef), 'U', 'encode undef');
                         is(encode("a\nb"), "S3:a\nb", 'encode newline');

$scalar = 'scalar';      is_deeply(encode(\$scalar), 's6:scalar',
				   'encode scalar ref');
$scalar = '';            is_deeply(encode(\$scalar), 's0:',
				   'encode empty scalar ref');
$scalar = 381;           is_deeply(encode(\$scalar), 's3:381',
				   'encode number ref');
$scalar = ':';           is_deeply(encode(\$scalar), 's1::',
				   'encode sign ref');

$scalar = undef;         is_deeply(encode(\$scalar), 'u', 'encode undef ref');

$ref = [ 'a', 'b' ];     is_deeply(encode($ref), 'a2:S1:aS1:b',
				   'encode array ref');
$ref = [ 'a' ];          is_deeply(encode($ref), 'a1:S1:a',
				   'encode single element array ref');
$ref = [ [ 'a' ] ];      is_deeply(encode($ref), 'a1:a1:S1:a',
				   'encode multilevel array ref');
$ref = [ '' ];           is_deeply(encode($ref), 'a1:S0:',
				   'encode single empty element array ref');
$ref = [ ];              is_deeply(encode($ref), 'a0:',
				   'encode empty array ref');
$ref = [ undef ];        is_deeply(encode($ref), 'a1:U',
				   'encode array containing undef');

$ref = { 'a' => 'b' };   is_deeply(encode($ref), 'h2:S1:aS1:b',
				   'encode hash ref');
$ref = { };              is_deeply(encode($ref), 'h0:',
				   'encode empty hash ref');
$ref = { 'a' => undef }; is_deeply(encode($ref), 'h2:S1:aU',
				   'encode undef value hash ref');
$ref = { undef => 'b' }; is_deeply(encode($ref), 'h2:S5:undefS1:b',
				   'encode undef key hash ref');

                         is(decode('S0:'), '', 'decode empty scalar');
                         is(decode('S1:a'), 'a', 'decode scalar');
                         is(decode('S1::'), ':', 'decode sign scalar');
                         is(decode('S2:42'), 42, 'decode number');
                         is(decode('U'), undef, 'decode undef');
                         is(decode("S3:a\nb"), "a\nb", 'decode newline');

$scalar = 'a';           is_deeply(decode('s1:a'), \$scalar,
				   'decode scalar ref');
$scalar = '';            is_deeply(decode('s0:'), \$scalar,
				   'decode empty scalar ref');
$scalar = ':';           is_deeply(decode('s1::'), \$scalar,
				   'decode sign scalar ref');
$scalar = 42;            is_deeply(decode('s2:42'), \$scalar,
				   'decode number ref');

$scalar = undef;         is_deeply(decode('u'), \$scalar,
				   'decode undef ref');

$ref = [ 'a', 'b' ];     is_deeply(decode('a2:S1:aS1:b'), $ref,
				   'decode array ref');
$ref = [ 'a' ];          is_deeply(decode('a1:S1:a'), $ref,
				   'decode single element array ref');
$ref = [ [ 'a' ] ];      is_deeply(decode('a1:a1:S1:a'), $ref,
				   'decode multilevel array ref');
$ref = [ '' ];           is_deeply(decode('a1:S0:'), $ref,
				   'decode single empty element array ref');
$ref = [ ];              is_deeply(decode('a0:'), $ref,
				   'decode empty array ref');
$ref = [ undef ];        is_deeply(decode('a1:U'), $ref,
				   'decode array containing undef');

$ref = { 'a' => 'b' };   is_deeply(decode('h2:S1:aS1:b'), $ref,
				   'decode hash ref');
$ref = { };              is_deeply(decode('h0:'), $ref,
				   'decode empty hash ref');
$ref = { 'a' => undef }; is_deeply(decode('h2:S1:aU'), $ref,
				   'decode undef val hash ref');
$ref = { undef => 'b' }; is_deeply(decode('h2:S5:undefS1:b'), $ref,
				   'decode undef key hash ref');


# if (!open($fh, '>', $box . '/input')) { die ($!); }
# printf($fh '7:a1:S1:a');                                       # ('a')
# printf($fh '11:a2:S1:aS1:b');                                  # ('a', 'b')
# printf($fh '14:a1:a2:S1:aS1:b');                               # ([ 'a', 'b' ])
# printf($fh '4:a1:U');                                          # (undef)
# printf($fh '3:a0:');                                           # ()
# printf($fh '75:a2:S32:d9b83e346cf02111689e63b90e284b4dS32:886062be7d998bc22768e231822ec025');
# close($fh);


# if (!open($in, '<', $box . '/input')) { die ($!); }
# if (!open($out, '>', $box . '/output')) { die ($!); }
# if (!open($fh, '<', $box . '/output')) { die ($!); }

# ok($connection = Synctl::SshProtocol->connect($in, $out), 'creation unbound');


# is_deeply([ $connection->recv() ], [ 'a' ], 'recv single scalar');
# is_deeply([ $connection->recv() ], [ 'a', 'b' ], 'recv multiple scalar');
# is_deeply([ $connection->recv() ], [ [ 'a', 'b' ] ], 'recv single array ref');
# is_deeply([ $connection->recv() ], [ undef ], 'recv undef');
# is_deeply([ $connection->recv() ], [ ], 'recv empty');


# $connection->send('a');              push(@arr, <$fh>);
# $connection->send('a', 'b');         push(@arr, <$fh>);
# $connection->send([ 'a', 'b' ]);     push(@arr, <$fh>);
# $connection->send(undef);            push(@arr, <$fh>);
# $connection->send();                 push(@arr, <$fh>);


# close($in);
# close($out);
# close($fh);


# is(shift(@arr), '7:a1:S1:a', 'send single scalar');
# is(shift(@arr), '11:a2:S1:aS1:b', 'send multiple scalar scalar');
# is(shift(@arr), '14:a1:a2:S1:aS1:b', 'send single array ref');
# is(shift(@arr), '4:a1:U', 'send undef');
# is(shift(@arr), '3:a0:', 'send empty');


1;
__END__
