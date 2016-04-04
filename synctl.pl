#!/usr/bin/perl -l

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);


sub posix_time
{
    my ($s, $mi, $h, $d, $mo, $y) = localtime();

    $mo += 1;
    $y += 1900;

    return sprintf("%04d-%02d-%02d-%02d-%02d-%02d", $y, $mo, $d, $h, $mi, $s);
}

sub error
{
    my ($message, $ret) = @_;
    my $prog = $0;
    
    if (!defined($message)) { $message = "undefined error"; }
    if (!defined($ret)) { $ret = 1; }

    $prog =~ s|^.*/||;
    printf(STDERR "%s: %s\n", $prog, $message);
    printf(STDERR "Please type '$0 --help' for more informations\n");

    exit ($ret);
}

sub opterror
{
    my ($message) = @_;

    $message =~ s/^Unknown option: (.*)$/$1/;
    chomp($message);

    error("unknown option : '$message'");
}

sub usage
{
    return <<"EOF"
Usage: $0 [options] <client> [<user>@]<server>:<path>
Make a backup from the local <client> path to the <path> on the remote ssh
<server>, logging as <user>.

Options:
  -h, --help                  Print this help message and exit.
  -v, --verbose               Be verbose about what is done.
  -n, --dry-run               Don't do anything on disk.
  -e, --exclude=<path>        Exclude a path from the backed files.
  -i, --include=<path>        Include an excluded path in the backed files.
EOF
}

sub list_backups
{
    my ($suser, $saddress, $spath) = @_;
    my $sshaddr = $suser . '@' . $saddress;
    my @command = ('ssh', $sshaddr, 'ls', $spath);
    my $cmd = join(' ', @command);
    my @entries = sort { $b cmp $a }
                  grep { ! /^\.\.?$/ }
                  grep { /^\d{4}-\d\d-\d\d-\d\d-\d\d-\d\d$/ }
                  split("\n", `$cmd`);

    return @entries;
}

sub make_backup
{
    my ($cpath, $suser, $saddress, $spath, @options) = @_;
    my ($last_backup) = list_backups($suser, $saddress, $spath);
    my @command = ('rsync', '-aAHXzc', @options);

    if (defined($last_backup)) {
	push(@command, '--link-dest=../' . $last_backup . '/');
    }

    push(@command, $cpath);
    push(@command, $suser . '@' . $saddress . ':'
	 . $spath . '/' . posix_time() . '/');

    if (grep { m|^-v$| } @options) {
	print join(' ', @command);
    }

    return system(@command);
}


sub main
{
    my ($verbose, $dryrun) = (0, 0);
    my (@exclude, @include, @options);
    my ($suser, $saddress, $spath);
    my ($client, $server, @err);

    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('permute');
    {
	local $SIG{__WARN__} = \&opterror;
	GetOptionsFromArray(
	    \@_,
	    'h|help' => sub { printf(usage()); exit (0); },
	    'v|verbose' => \$verbose,
	    'n|dry-run' => \$dryrun,
	    'e|exclude=s' => \@exclude,
	    'i|include=s' => \@include);
    }
    ($client, $server, @err) = @_;

    if (!defined($client)) { error('missing operand client'); }
    if (!defined($server)) { error('missing operand server'); }
    if (@err) { error("unexpected argument : '" . $err[0] . "'"); }

    if ($server =~ m|(?:([^@]+)@)?([^:]+):(.*)$|) {
	($suser, $saddress, $spath) = ($1, $2, $3);
	if (!defined($suser)) { $suser = $ENV{USER}; }
    } else {
	error("invalid operand server : '$server'");
    }

    if ($verbose) { push(@options, '-v'); }
    if ($dryrun) { push(@options, '-n'); }
    push(@options, map { '--include=' . $_ } @include);
    push(@options, map { '--exclude=' . $_ } @exclude);
    
    return make_backup($client, $suser, $saddress, $spath, @options);
}

exit (main(@ARGV));
__END__
