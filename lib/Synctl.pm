package Synctl;

use strict;
use warnings;

use Carp;

require Exporter;

my @ISA = qw(Exporter);
my @EXPORT_OK = qw(backend);


sub backend
{
    my ($target, @err) = @_;
    my ($type, $class, $classpath);
    my %types = (
	'file' => 'Synctl::FileBackend',
	'ssh'  => 'Synctl::SshBackend',
	''     => 'Synctl::FileBackend'
	);

    if (@err) { confess('unexpected parameters'); }
    if (ref($target) ne '') { confess('target should be a scalar'); }

    if ($target =~ m|^(.*?)://|) {
	$type = $1;
    } else {
	$type = '';
    }

    $class = $types{$type};
    if (!defined($class)) {
	carp("unknown scheme '$type'");
	return undef;
    }

    $classpath = $class;
    $classpath =~ s|::|/|g;
    $classpath .= '.pm';
    require $classpath;
    
    return $class->new($target);
}
