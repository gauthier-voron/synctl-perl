#!/usr/bin/perl -l

use strict;
use warnings;

use Test::More tests => 1;

use t::File;


BEGIN
{
    use_ok('Synctl::SshServer');
}


my $box = mktroot();



1;
__END__
