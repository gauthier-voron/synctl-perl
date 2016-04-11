package Synctl;

use 5.022001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
    'all' => [ qw(backend) ]
    );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.1.0';


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
    } elsif ($target =~ m|^(.*)@(.*):(.*)$|) {
	$type = 'ssh';
	$target = 'ssh://' . $target;
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


1;
__END__

=head1 NAME

Synctl - Make local or remote incremental backups

=head1 SYNOPSIS

  use Synctl;

  my $backend = Synctl::backend('/mnt/backup');
  my $backend = Synctl::backend('file:///mnt/backup');
  my $backend = Synctl::backend('ssh://backup@www.remote.net:/var/backup');

  foreach my $backup ($backend->list()) {    # list every backups made at this
      printf("%s\n", $backup);               #   server before
  }

  $backend->client('/');           # set the root of files to backup
  $backend->exclude('/mnt');       # ignore some files during the backup
  $backend->dryrun(1);             # do not make any write on disk
  $backend->verbose(1);            # explain what is going on

  $backend->send();                # make a new backup
  $backend->recv();                # recover from the last backup
  $backend->recv('2016-03');       # recover from the last backup of March 2016

  use Synctl::Config;

  # Parse a configuration file named 'config-name' which can be found either in
  # '~/.config/synctl' or in '~/.synctl'.

  my $config = Synctl::Config->new('config-name', '~/.config/synctl',
      '~/.synctl');

  my $backend = $config->backend();

=head1 AUTHOR

Gauthier Voron <gauthier.voron@mnesic.fr>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Gauthier Voron

This library is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut
