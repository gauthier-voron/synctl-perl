package Synctl::File;

use strict;
use warnings;

use Synctl qw(:error);


require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(deposit snapshot);

our @VERSIONS = qw(1);


sub __instance
{
    my ($type, $path, @args) = @_;
    my ($fh, $version, $class, $cpath);

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (ref($path) ne '') {
	return throw(EINVLD, $path);
    }

    if (open($fh, '<', $path . '/version')) {
	chomp($version = <$fh>);
	close($fh);

	if (!grep { $version eq $_ } @VERSIONS) {
	    $version = undef;
	}
    }

    if (!defined($version)) {
	$version = (sort { $b <=> $a } @VERSIONS)[0];
    }

    $class = 'Synctl::File::' . $version . '::' . $type;
    $cpath = $class;
    $cpath =~ s|::|/|g;
    $cpath .= '.pm';

    require $cpath;
    return $class->new($path, @args);
}


sub deposit
{
    my ($clazz, @args) = @_;
    return __instance('Deposit', @args);
}

sub snapshot
{
    my ($clazz, @args) = @_;
    return __instance('Snapshot', @args);
}


1;
__END__
