package t::Controler;

use strict;
use warnings;

use Test::More;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(test_controler_count test_controler);


sub test_controler_count
{
    return 8;
}

sub test_controler
{
    my ($controler) = @_;
    my (@arr, $scal, $snapshot0, $snapshot1);

    ok($controler->deposit(), 'controler deposit');

    @arr = $controler->snapshot();
    is(scalar(@arr), 0, 'controler list (empty)');

    $snapshot0 = $controler->create();
    ok($snapshot0, 'controler create first');

    @arr = $controler->snapshot();
    is(scalar(@arr), 1, 'controler list (after one creation)');

    $snapshot1 = $controler->create();
    ok($snapshot1, 'controler create second');

    @arr = $controler->snapshot();
    is(scalar(@arr), 2, 'controler list (after two creations)');

    ok($controler->delete($snapshot0), 'controler delete');

    @arr = $controler->snapshot();
    is(scalar(@arr), 1, 'controler list (after one deletion)');
}


1;
__END__
