package Synctl::Util::Status;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Fcntl qw(:mode);
use Scalar::Util qw(blessed);

use Synctl qw(:error);


sub all       { return shift()->_rw('__all',       @_); }
sub color     { return shift()->_rw('__color',     @_); }
sub porcelain { return shift()->_rw('__porcelain', @_); }
sub snapshot  { return shift()->_rw('__snapshot',  @_); }
sub checksum  { return shift()->_rw('__checksum',  @_); }


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self->all(0);
    $self->color(0);
    $self->porcelain(0);
    $self->snapshot(0);
    $self->checksum(1);

    return $self;
}


sub __colorize_status
{
    my ($status) = @_;
    my ($inex, $psync, $csync) = split('', $status);
    my ($lead, $tail);

    if ($inex eq 'i') {
	if ($psync eq '*' || grep { $csync eq $_ } qw(* m)) {
	    $lead = "\033[1;33m";
	} elsif ($psync eq 'm') {
	    $lead = "\033[1;36m";
	} else {
	    $lead = "\033[1;32m";
	}
    } elsif ($inex eq 'e') {
	$lead = "\033[1;31m";
    } else {
	$lead = "\033[1;30m";
    }

    $tail = "\033[0m";
    return $lead . $status . $tail;
}

sub __display_status
{
    my ($self, $cprop, $sprop) = @_;
    my ($buffer, $inex, $psync, $csync);

    if (defined($cprop->{INODE})) {
	if ($cprop->{MODE}) {
	    $inex = 'i';
	} else {
	    $inex = 'e';
	}
    } else {
	$inex = '-';
    }

    if (!$self->snapshot()) {
	$psync = '?';
    } elsif (!defined($sprop->{MODE})) {
	$psync = '*';
    } elsif ($inex eq '-') {
	$psync = 'x';
    } elsif (grep { defined($cprop->{$_}) != defined($sprop->{$_}) ||
		    (defined($cprop->{$_}) && $cprop->{$_} ne $sprop->{$_}) }
	     qw(MODE USER GROUP MTIME)) {
	$psync = 'm';
    } else {
	$psync = '-'
    }

    if (!$self->snapshot() || !$self->checksum()) {
	$csync = '?';
    } elsif ($psync eq '*') {
	$csync = '*';
    } elsif ($inex eq '-') {
	$csync = 'x';
    } elsif ($cprop->{HASH} eq $sprop->{HASH}) {
	$csync = '-';
    } else {
	$csync = 'm';
    }

    $buffer = $inex . $psync . $csync;
    if ($self->color()) {
	$buffer = __colorize_status($buffer);
    }

    return $buffer;
}

sub __colorize_entry
{
    my ($entry, $cprop, $path) = @_;
    my (@stats, $mode, $key, $col);
    my (%colors, $lscolors);

    $lscolors = $ENV{LS_COLORS};
    if (defined($lscolors)) {
	%colors = map { split('=', $_) } split(':', $lscolors);
    }

    if (!defined($mode = $cprop->{MODE})) {
	@stats = stat($path . '/' . $entry);
	if (!@stats) {
	    return $entry;
	}

	$mode = $stats[2];
    }

    if (S_IFMT($mode) == S_IFDIR) {
	$key = 'di';
    } elsif (S_IFMT($mode) == S_IFLNK) {
	$key = 'ln';
    } elsif ($mode & (S_IXUSR | S_IXGRP | S_IXOTH)) {
	$key = 'ex';
    } elsif ($entry =~ /\.([^.]+)$/) {
	$key = '*.' . $1;
    } else {
	$key = '';
    }

    $col = $colors{$key};
    if (!defined($col)) {
	$col = '0';
    }

    return "\033[$col" . 'm' . $entry . "\033[0m";
}

sub __merge_keys
{
    my ($ha, $hb) = @_;
    my ($h, %keys);

    foreach $h ($ha, $hb) {
	foreach (keys(%$h)) {
	    $keys{$_} = 1;
	}
    }

    return keys(%keys);
}

sub __display_human
{
    my ($self, $handler, $cprops, $sprops, $path) = @_;
    my ($buffer, $entry, $cprop);

    foreach $entry (sort { $a cmp $b } __merge_keys($cprops, $sprops)) {
	if (!$self->all() && substr($entry, 0, 1) eq '.') {
	    next;
	}

	$cprop = $cprops->{$entry};

	$buffer = '';
	$buffer .= $self->__display_status($cprop, $sprops->{$entry});

	if ($self->color()) {
	    $buffer .= ' ' . __colorize_entry($entry, $cprop, $path);
	} else {
	    $buffer .= ' ' . $entry;
	}

	$handler->($buffer);
    }
}

sub __display_porcelain
{
    my ($self, $handler, $cprops) = @_;
    my ($entry, $buffer);

    foreach $entry (sort { $a cmp $b } keys(%$cprops)) {
	$buffer = '';

	if (defined($cprops->{$entry}->{MODE})) {
	    $buffer .= 'i';
	} else {
	    $buffer .= 'e';
	}

	$buffer .= ' ' . $entry;
	$handler->($buffer);
    }
}

sub __display
{
    my ($self, $handler, $cprops, $sprops, $path) = @_;

    if ($self->porcelain()) {
	$self->__display_porcelain($handler, $cprops);
    } else {
	$self->__display_human($handler, $cprops, $sprops, $path);
    }
}


sub __normalize_output
{
    my ($output) = @_;
    my ($handler);

    if (ref($output) eq 'SCALAR') {
	$$output = '';
	$handler = sub { $$output .= shift() . "\n"; };
    } elsif (ref($output) eq 'ARRAY') {
	@$output = ();
        $handler = sub { push(@$output, { @_ }) };
    } elsif (ref($output) eq 'GLOB') {
	$handler = sub { printf($output "%s\n", shift()); };
    } elsif (ref($output) eq 'CODE') {
        $handler = $output;
    } else {
	return throw(EINVLD, $output);
    }

    return $handler;
}


sub __canonical_parent
{
    my ($path) = @_;
    my $parent = $path;

    $parent =~ s|[^/]+/*$||;
    if ($parent eq '') {
	$parent = '.';
    }

    return $parent;
}

sub __parents_inode
{
    my ($path) = @_;
    my (@stats, $dev, $inode, $parent, $key);
    my $parents = {};

    $parent = __canonical_parent($path);

    while (1) {
	@stats = stat($parent);
	if (!@stats) {
	    $parent = __canonical_parent($parent);
	    next;
	}

	($dev, $inode) = @stats[0, 1];
	$key = $dev . ':' . $inode;

	if (defined($parents->{$key})) {
	    last;
	}

	$parents->{$key} = $parent;
	$parent = $parent . '/..';
    }

    return $parents;
}

sub __targets_inode
{
    my ($path) = @_;
    my (@stats, $dev, $inode, $mode);
    my ($entry, $fh);
    my $targets = {};

    @stats = stat($path);
    if (!@stats) {
	$targets->{$path}->{INODE} = '';
	return $targets;
    }

    ($dev, $inode, $mode) = @stats[0, 1, 2];

    if ($mode & S_IFDIR) {
	$targets->{'.'}->{INODE} = $dev . ':' . $inode;
    } else {
	$targets->{$path}->{INODE} = $dev . ':' . $inode;
	return $targets;
    }

    if (!opendir($fh, $path)) {
	return $targets;
    }

    foreach $entry (grep { ! /^\.$/ } readdir($fh)) {
	@stats = lstat($path . '/' . $entry);
	if (!@stats) {
	    next;
	}

	($dev, $inode) = @stats[0, 1];
	$targets->{$entry}->{INODE} = $dev . ':' . $inode;
    }

    return $targets;
}


sub __seek_filter
{
    my ($path, $inner, $root, $inodes) = @_;
    my ($ret, @stats, $dev, $inode);

    if (($ret = $inner->($path)) == 0) {
	return 0;
    }

    @stats = lstat($root . '/' . $path);
    if (!@stats) {
	return 0;
    }

    ($dev, $inode) = @stats[0, 1];
    $inode = $dev . ':' . $inode;

    if (!grep { $inode eq $_ } @$inodes) {
    	return 0;
    }

    return $ret;
}

sub __seek_cprops
{
    my ($seeker, $parents, $targets) = @_;
    my ($inner, $outer, @inodes, %rtargets);
    my ($cprops, $pprops) = ({}, {});

    push(@inodes, keys(%$parents));
    push(@inodes, map { $targets->{$_}->{INODE} } keys(%$targets));
    %rtargets = map { $targets->{$_}->{INODE}, $_ } keys(%$targets);

    $inner = $seeker->filter();
    $outer = sub { __seek_filter(shift(), $inner, $seeker->path(), \@inodes) };
    $seeker->filter($outer);

    $seeker->seek(sub {
	my (%props) = @_;
	my $inode = $props{INODE};
	my $path = $rtargets{$inode};
	my $parent = $parents->{$props{INODE}};;

	if (defined($path)) {
	    $cprops->{$path} = \%props;
	}

	if (defined($parent)) {
	    $pprops->{$parent} = \%props;
	}
    });

    $seeker->filter($inner);
    return ($cprops, $pprops);
}

sub __populate_unexisting
{
    my ($path, $cprops, $pprops) = @_;
    my ($deepest, $name);

    ($deepest) = grep { ! /\.\.$/ } keys(%$pprops);
    if (!defined($deepest)) {
	$cprops->{$path}->{NAME} = $path;
	return;
    }

    if ($deepest ne '.') {
	$name = substr($path, length($deepest));
    } else {
	$name = $path;
    }
    $name = $pprops->{$deepest}->{NAME} . '/' . $name;
    $name =~ s|^//|/|;
    $cprops->{$path}->{NAME} = $name;
}

sub __populate_missing
{
    my ($targets, $cprops) = @_;
    my ($path, $base, $sep, $name);

    if (defined($cprops->{'.'})) {
	$base = $cprops->{'.'}->{NAME};

	if ($base eq '/') {
	    $sep = '';
	} else {
	    $sep = '/';
	}
    }

    foreach $path (keys(%$targets)) {
	if (defined($cprops->{$path})) {
	    next;
	}

	$cprops->{$path}->{INODE} = $targets->{$path};

	if (!defined($base) || $path eq '..') {
	    $cprops->{$path}->{NAME} = $path;
	} else {
	    $name = $base . $sep . $path;
	    $cprops->{$path}->{NAME} = $name;
	}
    }
}


sub __seek_sprops
{
    my ($snapshot, $path, $cprops) = @_;
    my (%rcprops, $name, %sprops, $props);
    my ($entry, $entries, $sep);

    %rcprops = map { $cprops->{$_}->{NAME}, $_ } keys(%$cprops);
    foreach $name (keys(%rcprops)) {
	$props = $snapshot->get_properties($name);
	$props->{NAME} = $name;
	$sprops{$rcprops{$name}} = $props;
    }

    if (defined($cprops->{'.'})) {
	$name = $cprops->{'.'}->{NAME};
	$entries = $snapshot->get_directory($name);
	if (!defined($entries)) {
	    $entries = [];
	}

	if ($name eq '/') {
	    $sep = '';
	} else {
	    $sep = '/';
	}

	foreach $entry (@$entries) {
	    if (defined($sprops{$entry})) {
		next;
	    }

	    $props = $snapshot->get_properties($name . $sep . $entry);
	    $props->{NAME} = $entry;
	    $sprops{$entry} = $props;
	}
    }

    return \%sprops;
}


sub __hash_link
{
    my ($path) = @_;
    my $content = readlink($path);

    if (!defined($content)) {
	return '';
    }

    return md5_hex($content);
}

sub __hash_file
{
    my ($path) = @_;
    my ($fh, $hash, $ctx);

    if (!open($fh, '<', $path)) {
	return '';
    }

    $ctx = Digest::MD5->new();
    $ctx->addfile($fh);
    $hash = $ctx->hexdigest();
    close($fh);

    return $hash;
}

sub __hash_entry
{
    my ($path) = @_;

    if (-l $path) {
	return __hash_link($path);
    } elsif (-f $path) {
	return __hash_file($path);
    } else {
	return '';
    }
}

sub __seek_cchecksums
{
    my ($path, $cprops) = @_;
    my ($entry, $mode, $cpath);

    foreach $entry (keys(%$cprops)) {
	$cpath = $path . '/' . $entry;
	$mode = $cprops->{$entry}->{MODE};

	if (defined($mode) && ($mode & S_IFDIR)) {
	    $cprops->{$entry}->{HASH} = '';
	    next;
	} elsif (!defined($mode) && (-d $cpath)) {
	    $cprops->{$entry}->{HASH} = '';
	    next;
	}

	$cprops->{$entry}->{HASH} = __hash_entry($cpath);
    }
}

sub __seek_schecksums
{
    my ($snapshot, $sprops) = @_;
    my ($prop, $entry, $hash);

    foreach $entry (keys(%$sprops)) {
	$prop = $sprops->{$entry};

	if (!defined($prop->{MODE})) {
	    next;
	}

	if ($prop->{MODE} & S_IFDIR) {
	    $prop->{HASH} = '';
	} else {
	    $prop->{HASH} = $snapshot->get_file($prop->{NAME});
	}
    }
}


sub __execute
{
    my ($self, $handler, $seeker, $path) = @_;
    my ($parents, $targets, $cprops, $pprops);
    my ($deepest, $name);
    my ($snapshot, $sprops);

    $parents = __parents_inode($path);
    $targets = __targets_inode($path);
    ($cprops, $pprops) = __seek_cprops($seeker, $parents, $targets);

    if (defined($targets->{'.'})) {
	__populate_missing($targets, $cprops);
    } elsif (scalar(keys(%$cprops)) == 0) {
	__populate_unexisting($path, $cprops, $pprops);
    }

    $snapshot = $self->snapshot();
    if ($snapshot) {
	$sprops = __seek_sprops($snapshot, $path, $cprops);

	if ($self->checksum()) {
	    __seek_cchecksums($path, $cprops);
	    __seek_schecksums($snapshot, $sprops);
	}
    }

    $self->__display($handler, $cprops, $sprops, $path);
    return 1;
}

sub execute
{
    my ($self, $output, $seeker, $path, @err) = @_;
    my ($handler);

    if (!defined($seeker)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($seeker) || !$seeker->isa('Synctl::Seeker')) {
	return throw(EINVLD, $seeker);
    } elsif (!defined($handler = __normalize_output($output))) {
	return undef;
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self->__execute($handler, $seeker, $path);
}


1;
__END__
