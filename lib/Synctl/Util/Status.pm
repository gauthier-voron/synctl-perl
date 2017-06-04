package Synctl::Util::Status;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Fcntl qw(:mode);
use Scalar::Util qw(blessed);

use Synctl qw(:error);


sub porcelain { return shift()->_rw('__porcelain', @_); }

sub __tty     { return shift()->_rw('__tty',       @_); }
sub __handler { return shift()->_rw('__handler',   @_); }


sub _new
{
    my ($self, @err) = @_;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    return $self;
}


sub __targets_inode
{
    my ($self, $path) = @_;
    my ($dh, $entry, $epath);
    my (@stats, $dev, $inode, $mode);
    my $ret = {};

    @stats = stat($path);
    if (!@stats) {
	return throw(ESYS, $path, $!);
    }

    ($dev, $inode, $mode) = @stats[0, 1, 2];

    if (!($mode & S_IFDIR)) {
	$ret->{$dev . ':' . $inode} = $path;
	return $ret;
    } else {
	$ret->{$dev . ':' . $inode} = '.';
    }

    if (!opendir($dh, $path)) {
	return throw(ESYS, $path, $!);
    }

    foreach $entry (grep { ! /^\.$/ } readdir($dh)) {
	$epath = $path . '/' . $entry;
	@stats = lstat($epath);
	if (!@stats) {
	    closedir($dh);
	    return throw(ESYS, $epath, $!);
	}

	($dev, $inode) =  @stats[0, 1];
	$ret->{$dev . ':' . $inode} = $entry;
    }

    closedir($dh);
    return $ret;
}

sub __branch_inodes
{
    my ($self, $path) = @_;
    my ($npath, @stats, $dev, $inode, $cur, $lst);
    my $ret = [];

    $npath = $path;
    $npath =~ s|^(.*/)[^/]+/*$|$1|;
    if (($npath eq $path) && !($npath =~ m|^/+$|)) {
	$npath = '.';
    }

    $lst = '';

    while (1) {
	@stats = stat($npath);
	if (!@stats) {
	    return throw(ESYS, $npath, $!);
	}

	($dev, $inode) = @stats[0, 1];
	$cur = $dev . ':' . $inode;

	if ($cur eq $lst) {
	    last;
	} else {
	    push(@$ret, $cur);
	    $lst = $cur;

	    $npath = $npath . '/..';
	}
    }

    return $ret;
}

sub __director_filter
{
    my ($path, $root, $base, $inodes) = @_;
    my ($ret, @stats, $dev, $inode);

    if (($ret = $base->($path)) == 0) {
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

sub __directed_seek
{
    my ($self, $seeker, $branch, $targets) = @_;
    my ($base, $decorated, $inodes);
    my $ret = {};

    $base = $seeker->filter();
    $inodes = [ @$branch, keys(%$targets) ];
    $decorated = sub {
	return __director_filter(shift(), $seeker->path(), $base, $inodes);
    };
    $seeker->filter($decorated);

    $seeker->seek(sub {
	my (%props) = @_;
	my @matches = grep { $props{INODE} eq $_ } keys(%$targets);
	my ($inode, $entry);

	if (@matches) {
	    $inode = shift(@matches);
	    $entry = $targets->{$inode};
	    $ret->{$entry} = \%props;
	}
    });

    $seeker->filter($base);
    return $ret;
}

sub __apply_seeker
{
    my ($self, $seeker, $path) = @_;
    my ($branch, $targets, $found, $entry);

    $targets = $self->__targets_inode($path);
    if (!defined($targets)) {
	return undef;
    }

    $branch = $self->__branch_inodes($path);
    if (!defined($branch)) {
	return undef;
    }

    $found = $self->__directed_seek($seeker, $branch, $targets);
    if (!defined($found)) {
	return undef;
    }

    foreach $entry (values(%$targets)) {
	if (!defined($found->{$entry})) {
	    $found->{$entry} = undef;
	}
    }

    return $found;
}


sub __display_porcelain
{
    my ($self, $found) = @_;
    my ($entry, $handler, $buffer);

    $handler = $self->__handler();

    foreach $entry (sort { $a cmp $b } keys(%$found)) {
	$buffer = '';

	if (defined($found->{$entry})) {
	    $buffer .= 'i';
	} else {
	    $buffer .= 'e';
	}

	$buffer .= ' ' . $entry;
	$handler->($buffer);
    }
}

sub __display_tty
{
    my ($self, $found) = @_;
    my ($entry, $handler, $buffer);

    $handler = $self->__handler();

    foreach $entry (sort { $a cmp $b } keys(%$found)) {
	$buffer = '';

	if (defined($found->{$entry})) {
	    $buffer .= "\033[32mi";
	} else {
	    $buffer .= "\033[31me";
	}

	$buffer .= sprintf(" %s\033[0m", $entry);
	$handler->($buffer);
    }
}

sub __display
{
    my ($self, $found) = @_;

    if ($self->__tty() && !$self->porcelain()) {
	$self->__display_tty($found);
    } else {
	$self->__display_porcelain($found);
    }
}


sub __setup_handler
{
    my ($self, $output) = @_;
    my ($tty, $handler);

    $tty = 0;

    if (ref($output) eq 'SCALAR') {
	$$output = '';
	$handler = sub { $$output .= shift() . "\n"; };
    } elsif (ref($output) eq 'ARRAY') {
	@$output = ();
        $handler = sub { push(@$output, { @_ }) };
    } elsif (ref($output) eq 'GLOB') {
	if (-t $output) {
	    $tty = 1;
	}
	$handler = sub { printf($output "%s\n", shift()); };
    } elsif (ref($output) eq 'CODE') {
        $handler = $output;
    } else {
	return throw(EINVLD, $output);
    }

    $self->__tty($tty);
    $self->__handler($handler);

    return 1;
}

sub execute
{
    my ($self, $output, $seeker, $path, @err) = @_;
    my ($found);

    if (!defined($seeker)) {
	return throw(ESYNTAX, undef);
    } elsif (!blessed($seeker) || !$seeker->isa('Synctl::Seeker')) {
	return throw(EINVLD, $seeker);
    } elsif (!defined($self->__setup_handler($output))) {
	return undef;
    } elsif (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $found = $self->__apply_seeker($seeker, $path);
    if (!defined($found)) {
	return undef;
    }

    $self->__display($found);
    return 1;
}


1;
__END__
