package t::File;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use File::Temp qw(tempdir);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = ('mktroot', 'mktfile', 'mktdir', 'mktlink',
	       'rdtroot', 'rdtfile', 'rdtdir', 'rdtlink');


sub mktroot
{
    my (%args) = @_;
    my $root = tempdir('troot.XXXXXX', TMPDIR => 1, CLEANUP => 1);

    return $root;
}

sub mktfile
{
    my ($path, %args) = @_;
    my ($fd, $value);

    if (!open($fd, '>', $path)) { die ("cannot create file '$path' : $!"); }
    
    if (defined($value = $args{'CONTENT'})) {
	printf($fd "%s", $value);
    }

    close($fd);

    if (defined($value = $args{'MODE'})) {
	chmod($value, $path);
    }

    return $path;
}

sub mktdir
{
    my ($path, %args) = @_;
    my $value;

    if (!mkdir($path)) { die ("cannot create directory '$path' : $!"); }

    if (defined($value = $args{'MODE'})) {
	chmod($value, $path);
    }

    return $path;
}

sub mktlink
{
    my ($path, $target, %args) = @_;

    if (!symlink($target, $path)) {
	die ("cannot create symlink '$path' : $!");
    }

    return $path;
}


sub rdtfile
{
    my ($path, $dest) = @_;
    my ($fh, $digest);
    my ($hash, $mode, $uid, $gid, $mtime);

    ($mode, $uid, $gid, $mtime) = (stat($path))[2, 4, 5, 9];

    if (!open($fh, '<', $path)) {
	$hash = '0' x 20;
    } else {
	$digest = Digest::MD5->new();
	$digest->addfile($fh);
	$hash = $digest->hexdigest();
	
	close($fh);
    }

    $dest->{$path} =
	sprintf("%03o %d %d %d %s", $mode, $uid, $gid, $mtime, $hash);
}

sub rdtlink
{
    my ($path, $dest) = @_;
    my ($fh, $content);
    my ($hash, $mode, $uid, $gid, $mtime);

    ($mode, $uid, $gid, $mtime) = (lstat($path))[2, 4, 5, 9];

    $content = readlink($path);
    $hash = md5_hex($content);

    $dest->{$path} =
	sprintf("%03o %d %d %d %s", $mode, $uid, $gid, $mtime, $hash);
}

sub rdtdir
{
    my ($path, $dest) = @_;
    my ($dh, $entry);
    my ($mode, $uid, $gid, $mtime);

    ($mode, $uid, $gid, $mtime) = (stat($path))[2, 4, 5, 9];

    if (opendir($dh, $path)) {
	foreach $entry (map  { $path . '/' . $_ }
			grep { ! /^\.\.?$/      }
			readdir($dh)) {
	    rdtroot($entry, $dest);
	}

	close($dh);
    }

    $dest->{$path} = sprintf("%03o %d %d %d", $mode, $uid, $gid, $mtime);
}

sub rdtroot
{
    my ($path, $dest) = @_;
    my ($ndest, $text, $key, $rkey);

    if (!defined($dest)) {
	$dest = {};
	$ndest = $dest;
    }

    if (-l $path) {
	rdtlink($path, $dest);
    } elsif (-f $path) {
	rdtfile($path, $dest);
    } elsif (-d $path) {
	rdtdir($path, $dest);
    }

    if (defined($ndest)) {
	delete($ndest->{$path});
	foreach $key (sort { $a cmp $b } keys(%$ndest)) {
	    $rkey = ($key =~ s/^$path/./r);
	    $text .= $rkey . ' => ' . $ndest->{$key} . "\n";
	}

	return $text;
    }
}


1;
__END__
