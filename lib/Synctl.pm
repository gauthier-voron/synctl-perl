package Synctl;

use 5.022001;
use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

use constant {
    ESYNTAX => 'Invalid call syntax',
    EINVLD  => 'Invalid argument value',
    EPERM   => 'Invalid permission',
    ESYS    => 'System error',
    EPROT   => 'Protocol error',
    ECONFIG => 'Configuration error',

    ERROR   => 1,
    WARN    => 2,
    INFO    => 3,
    DEBUG   => 4,

    IFCREAT => 'Create file',        # path of the file created
    IFDELET => 'Delete file',        # path of the file deleted
    ILCREAT => 'Create link',        # path of the source, path of the dest
    IRGET   => 'Create reference',   # hash of the reference
    IRPUT   => 'Delete reference',   # hash of the reference
    ICSEND  => 'Send bytes',         # amount of sent bytes
    ICRECV  => 'Receive bytes',      # amount of received bytes
    ICONFIG => 'Use configuration',  # what is configured, at what value
    IRLOAD  => 'Load references',    # <nothing>
    IFCHECK => 'Check file',         # path of the file
    IFPROCS => 'Process file',       # path of the file
    IFSEND  => 'Send file',          # path of the file
    IFRECV  => 'Receive file',       # path of the file
    IREGEX  => 'Build regex',        # include/exclude, from, to
    INODMAP => 'Nodemap update',     # client/server, key, value
};


require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
    'error'   => [ qw(throw ESYNTAX EINVLD EPERM ESYS EPROT ECONFIG) ],
    'verbose' => [ qw(notify ERROR WARN INFO DEBUG IFCREAT IFDELET ILCREAT
                      IRGET IRPUT ICSEND ICRECV ICONFIG IRLOAD IFCHECK IFPROCS
                      IFSEND IFRECV IREGEX INODMAP) ],
    'all'     => [ qw(Configure backend init controler send list recv serve) ]
    );

push(@{$EXPORT_TAGS{'all'}}, @{$EXPORT_TAGS{'error'}});
push(@{$EXPORT_TAGS{'all'}}, @{$EXPORT_TAGS{'verbose'}});

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.1.0';

require Synctl::FileControler;
require Synctl::FileDeposit;
require Synctl::Receiver;
require Synctl::Seeker;
require Synctl::Sender;
require Synctl::SshControler;
require Synctl::SshProtocol;
require Synctl::SshServer;


sub Configure
{
    my (@arr) = @_;
    my (%args, $key);

    if (scalar(@arr) % 2) {
	return throw(ESYNTAX, @arr);
    }

    %args = @arr;

    foreach $key (%args) {
	if ($key eq 'ERROR') {
	    return __configure_error($args{$key});
	} elsif ($key eq 'VERBOSE') {
	    return __configure_verbose($args{$key});
	} else {
	    return throw(ESYNTAX, $key);
	}
    }
}


my $__ERROR = \&__default_error;

sub throw
{
    $__ERROR->(@_);
    return undef;
}

sub __default_error
{
    my ($code, @hints) = @_;
    my $message = $code;

    if (@hints) {
	@hints = map { if (defined($_)) { $_ } else { '<undef>' } } @hints;
	$message .= " : " . join(', ', @hints);
    }

    confess($message);
}

sub __configure_error
{
    my ($error) = @_;
    my $handler;

    if (!defined($error)) {
	$error = \&__default_error;
    }
    
    if (ref($error) eq 'SCALAR') {
	$handler = sub { $$error = shift(@_); };
    } elsif (ref($error) eq 'ARRAY') {
	$handler = sub { push(@$error, shift(@_)); };
    } elsif (ref($error) eq 'CODE') {
	$handler = $error;
    } else {
	return throw(ESYNTAX, $error);
    }

    $__ERROR = $handler;
    return 1;
}


my $__VERBOSE = \&__default_verbose;

sub notify
{
    $__VERBOSE->(@_);
    return 1;
}

sub __default_verbose
{
    __filter_notice(WARN, @_);
}

sub __filter_notice
{
    my ($floor, $level, @args) = @_;

    if ($level <= $floor) {
	__notice($level, @args);
    }
}

sub __notice
{
    my ($level, $code, @hints) = @_;
    my %names = (
	ERROR() => 'ERROR',
	WARN()  => 'WARN',
	INFO()  => 'INFO',
	DEBUG() => 'DEBUG'
	);

    @hints = map { if (defined($_)) { $_ } else { '<undef>' } } @hints;
    printf(STDERR "[%s] %s: %s\n", $names{$level}, $code, join(' ', @hints));
}

sub __configure_verbose
{
    my ($verbose) = @_;
    my $handler;

    if (!defined($verbose)) {
	$verbose = 0;
    }

    if (ref($verbose) eq '') {
	if (!($verbose =~ /^\d+$/)) {
	    if (lc($verbose) eq 'error') {
		$verbose = ERROR;
	    } elsif (lc($verbose) eq 'warn') {
		$verbose = WARN;
	    } elsif (lc($verbose) eq 'info') {
		$verbose = INFO;
	    } elsif (lc($verbose) eq 'debug') {
		$verbose = DEBUG;
	    } else {
		return throw(EINVLD, $verbose);
	    }
	}
	$handler = sub { __filter_notice($verbose, @_); }
    } elsif (ref($verbose) eq 'CODE') {
	$handler = $verbose;
    } else {
	return throw(ESYNTAX, $verbose);
    }

    $__VERBOSE = $handler;
    return 1;
}


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


sub __check_empty_dir
{
    my ($path) = @_;
    my $dh;

    if (!opendir($dh, $path)) {
	throw(ESYS, $!, $path);
	return 0;
    }

    if (scalar(grep { ! /^\.\.?$/ } readdir($dh)) > 0) {
	return 0;
    }

    closedir($dh);
    return 1;
}

sub init
{
    my ($location, @err) = @_;
    my ($type, $path, $deposit, $controler);

    if (!defined($location)) {
	return throw(ESYNTAX, $location);
    }

    if ($location =~ m|^([^:]+)://(.*)$|) {
	($type, $path) = ($1, $2);
    } else {
	($type, $path) = ('file', $location);
    }

    if ($type ne 'file') {
	return throw(EINVLD, $location);
    }

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (-d $path) {
	if (!(-r $path) || !(-w $path) || !(-x $path)) {
	    return throw(EPERM, $location);
	}

	if (!__check_empty_dir($path)) {
	    return throw(EINVLD, $location);
	}
    } else {
	if (!mkdir($path)) {
	    return throw(ESYS, $!, $path);
	} else {
	    notify(INFO, IFCREAT, $path);
	}
    }

    $deposit = Synctl::FileDeposit->new($path . '/deposit');
    if (!defined($deposit->init())) {
	return undef;
    }

    if (!mkdir($path . '/snapshots')) {
	return throw(ESYS, $!, $path . '/snapshots');
    } else {
	notify(INFO, IFCREAT, $path . '/snapshots');
    }

    $controler = Synctl::FileControler->new($deposit, $path . '/snapshots');
    return $controler;
}


sub __file_controler
{
    my ($path, @args) = @_;
    my $deposit_path = $path . '/deposit';
    my $snapshot_path = $path . '/snapshots';
    my ($deposit, $controler, %opts, $opt);

    if (!defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (scalar(@args) % 2) {
	return throw(ESYNTAX, pop(@args));
    }

    %opts = @args;

    foreach $opt (keys(%opts)) {
	if ($opt eq 'DEPOSIT') {
	    $deposit_path = $path . '/' . $opts{$opt};
	} elsif ($opt eq 'SNAPSHOTS') {
	    $snapshot_path = $path . '/' . $opts{$opt};
	} else {
	    return throw(EINVLD, $opt);
	}
    }
    
    if (!(-d $deposit_path) || !(-d $snapshot_path)) {
	return throw(EINVLD, $path);
    }

    if (!defined($deposit = Synctl::FileDeposit->new($deposit_path))) {
	return undef;
    }
    
    return Synctl::FileControler->new($deposit, $snapshot_path);
}

sub __ssh_controler
{
    my ($location, @args) = @_;
    my ($address, $path, %opts, $opt);
    my ($pid, $child_in, $child_out, $parent_in, $parent_out);
    my ($connection, $controler);
    my @lcommand = qw(ssh);
    my @rcommand = qw(/home/gauthier/Projets/perl-synctl/script/nsynctl serve);

    if (!defined($location)) {
	return throw(ESYNTAX, undef);
    } elsif (scalar(@args) % 2) {
	return throw(ESYNTAX, pop(@args));
    }

    %opts = @args;

    foreach $opt (keys(%opts)) {
	if ($opt eq 'COMMAND') {
	    if (ref($opts{$opt}) eq 'ARRAY') {
		@lcommand = @{$opts{$opt}};
	    } else {
		return throw(ESYNTAX, $opts{$opt});
	    }
	} elsif ($opt eq 'RCOMMAND') {
	    if (ref($opts{$opt}) eq 'ARRAY') {
		@rcommand = @{$opts{$opt}};
	    } else {
		return throw(ESYNTAX, $opts{$opt});
	    }
	} else {
	    return throw(EINVLD, $opt);
	}
    }

    if (!($location =~ m|^([^:]+):(.*)$|)) {
	return throw(EINVLD, $location);
    } else {
	($address, $path) = ($1, $2);
    }

    if (!pipe($child_in, $parent_out)) { return throw(ESYS, $!); }
    if (!pipe($parent_in, $child_out)) { return throw(ESYS, $!); }
    if (!defined($pid = fork()))       { return throw(ESYS, $!); }

    if ($pid == 0) {
	close($child_in);
	close($child_out);

	open(STDIN, '<&', $parent_in);
	open(STDOUT, '>&', $parent_out);
	close(STDERR);

	local $| = 1;

	exec (@lcommand, $address, @rcommand, $path);
	exit (1);
    } else {
	close($parent_in);
	close($parent_out);
    }

    $connection = Synctl::SshProtocol->connect($child_in, $child_out);
    if (!defined($connection)) {
	goto err;
    }
    
    $controler = Synctl::SshControler->new($connection);
    if (!defined($controler)) {
	goto err;
    }

    return $controler;
  err:
    close($child_in);
    close($child_out);
    kill('TERM', $pid);
    waitpid($pid, 0);
    return undef;
}

sub controler
{
    my ($location, @args) = @_;
    my ($type, $path, $action);
    my %actions = (
	'file' => \&__file_controler,
	'ssh'  => \&__ssh_controler
	);

    if (!defined($location)) {
	return throw(ESYNTAX, $location);
    }

    if ($location =~ m|^([^:]+)://(.*)$|) {
	($type, $path) = ($1, $2);
    } else {
	($type, $path) = ('file', $location);
    }

    $action = $actions{$type};

    if (!defined($action)) {
	return throw(EINVLD, $location);
    }

    return $action->($path, @args);
}

sub serve
{
    my ($controler, @err) = @_;
    my ($connection, $server);

    if (!defined($controler)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!blessed($controler) || !$controler->isa('Synctl::Controler')) {
	return throw(EINVLD, $controler);
    }

    $connection = Synctl::SshProtocol->connect(\*STDIN, \*STDOUT);
    if (!defined($connection)) {
	return undef;
    }

    $server = Synctl::SshServer->new($connection, $controler);
    if (!defined($server)) {
	return undef;
    }

    return $server->serve();
}

sub send
{
    my ($path, $controler, $filter, @err) = @_;
    my ($seeker, $sender, $snapshot);

    if (!defined($path) || !defined($controler)) {
	return throw(ESYNTAX, undef);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    } elsif (!(-e $path)) {
	return throw(EINVLD, $path);
    } elsif (!$controler->isa('Synctl::Controler')) {
	return throw(EINVLD, $controler);
    } elsif (defined($filter) && ref($filter) ne 'CODE') {
	return throw(EINVLD, $filter);
    }

    if (!defined($seeker = Synctl::Seeker->new($path))) {
	return undef;
    } elsif (!defined($seeker->filter($filter))) {
	return undef;
    }

    if (!defined($snapshot = $controler->create())) {
	return undef;
    }

    $sender = Synctl::Sender->new($controler->deposit(), $snapshot, $seeker);
    if (!defined($sender)) {
	# $controler->delete($snapsot);
	return undef;
    }

    return $sender->send();
}


sub list
{
    my ($controler, $filter, @err) = @_;
    my ($cfilter, @snapshots);

    if (!defined($controler)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($controler) || !$controler->isa('Synctl::Controler')) {
	return throw(EINVLD, $controler);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    if (defined($filter) && !($filter =~ m|^/|)) {
	$cfilter = $filter;
	if (length($cfilter) < 19) {
	    $cfilter .= substr('9999-99-99-99-99-99', length($filter));
	}

	if (!($cfilter =~ /^\d{4}(-\d\d){5}$/)) {
	    return throw(EINVLD, $filter);
	}

	$filter = $cfilter;
    }

    @snapshots = $controler->snapshot();
    @snapshots = sort { $a->date() cmp $b->date() } @snapshots;

    if (defined($filter)) {
	if ($filter =~ m|^/|) {
	    @snapshots = grep { defined($_->get_file($filter)) } @snapshots;
	} else {
	    @snapshots = grep { $_->date() le $filter } @snapshots;
	}
    }

    return @snapshots;
}

sub recv
{
    my ($controler, $snapshot, $path, $filter, @err) = @_;
    my ($deposit, $receiver);

    if (!defined($controler) || !defined($snapshot) || !defined($path)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($controler) || !$controler->isa('Synctl::Controler')) {
	return throw(EINVLD, $controler);
    } elsif (!blessed($snapshot) || !$snapshot->isa('Synctl::Snapshot')) {
	return throw(EINVLD, $snapshot);
    } elsif ((-e $path) && !(-d $path && -r $path && -w $path && -x $path)) {
	return throw(EPERM, $path);
    } elsif (defined($filter) && ref($filter) ne 'CODE') {
	return throw(EINVLD, $filter);
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $deposit = $controler->deposit();
    $receiver = Synctl::Receiver->new('/', $path, $snapshot, $deposit);
    if (!defined($receiver)) {
	return undef;
    }

    if (defined($filter)) {
	$receiver->filter($filter);
    }

    if (!(-e $path)) {
	notify(INFO, IFCREAT, $path);
	if (!mkdir($path)) {
	    return throw(ESYS, $!);
	}
    }

    return $receiver->receive();
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
