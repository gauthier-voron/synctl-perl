package Synctl::Ssh;

use strict;
use warnings;

use Synctl qw(:error :verbose);


require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(controler server);

our @VERSIONS = qw(1.1);


sub __split_version
{
    my ($version) = @_;

    if (!defined($version)) {
	return (undef, undef);
    } elsif (!($version =~ /^(\d+)\.(\d+)$/)) {
	return (undef, undef);
    }

    return ($1, $2);
}

sub __join_version
{
    my ($major, $minor) = @_;

    if (!defined($major) || !defined($minor)) {
	return undef;
    } elsif (!($major =~ /^\d+$/) || !($minor =~ /^\d+$/)) {
	return undef;
    }
    
    return $major . '.' . $minor;
}


sub __check_compatible_version
{
    my ($client_version, $server_version) = @_;
    my ($client_major, $client_minor);
    my ($server_major, $server_minor);

    if (!defined($client_version) || !defined($server_version)) {
	return 0;
    }

    ($client_major, $client_minor) = __split_version($client_version);
    ($server_major, $server_minor) = __split_version($server_version);

    if (!defined($client_major) || !defined($client_minor) ||
	!defined($server_major) || !defined($server_minor)) {
	return 0;
    }

    if ($client_major != $server_major) {
	return 0;
    } elsif ($client_major > $server_major) {
	return 0;
    } else {
	return 1;
    }
}

sub __find_last_version
{
    my ($version, $major, $minor) = @_;
    my ($last_major, $last_minor);

    foreach $version (@VERSIONS) {
	($major, $minor) = __split_version($version);
	if (!defined($major) || !defined($minor)) {
	    next;
	}

	if (!defined($last_major) || !defined($last_minor)) {
	    goto affect;
	} elsif ($major > $last_major) {
	    goto affect;
	} elsif (($major == $last_major) && ($minor > $last_minor)) {
	    goto affect;
	}

	next;

      affect:
	($last_major, $last_minor) = ($major, $minor);
    }

    if (defined($last_major) && defined($last_minor)) {
	return __join_version($last_major, $last_minor);
    } else {
	return undef;
    }
}

sub __find_client_version
{
    my ($server_version) = @_;
    my ($server_major, $server_minor) = __split_version($server_version);
    my ($version, $major, $minor, $client_minor);

    foreach $version (@VERSIONS) {
	($major, $minor) = __split_version($version);
	if (!defined($major) || !defined($minor)) {
	    next;
	}

	if (($major != $server_major) || ($minor > $server_minor)) {
	    next;
	}

	if (!defined($client_minor) || ($minor > $client_minor)) {
	    $client_minor = $minor;
	}
    }

    if (!defined($client_minor)) {
	return undef;
    } else {
	return __join_version($server_major, $client_minor);
    }
}

sub __find_server_version
{
    my ($client_version) = @_;
    my ($client_major, $client_minor) = __split_version($client_version);
    my ($version, $major, $minor, $server_major, $server_minor);

    foreach $version (@VERSIONS) {
	($major, $minor) = __split_version($version);
	if (!defined($major) || !defined($minor)) {
	    next;
	}

	if ($major > $client_major) {
	    next;
	} elsif (($major == $client_major) && ($minor > $client_minor)) {
	    next;
	}

	if (!defined($server_major) || !defined($server_minor)) {
	    goto affect;
	} elsif ($major > $server_major) {
	    goto affect;
	} elsif (($major == $server_major) && ($minor > $server_minor)) {
	    goto affect;
	}

	next;

      affect:
	($server_major, $server_minor) = ($major, $minor);
    }

    if (defined($server_major) && defined($server_minor)) {
	return __join_version($server_major, $server_minor);
    } else {
	return undef;
    }
}


sub __send_version
{
    my ($out, $version) = @_;
    my ($prev);

    if (length($version) > 8) {
	return 0;
    } if (!($version =~ /^\d+\.\d+$/)) {
	return 0;
    }

    $prev = select($out);
    local $| = 1;
    select($prev);
    
    printf($out "%-8s", $version);

    return 1;
}

sub __recv_version
{
    my ($in) = @_;
    my ($version);

    local $/ = \8;
    $version = <$in>;

    if (!defined($version)) {
	return 0;
    } elsif (!($version =~ /^(\d+\.\d+)\s*$/)) {
	return 0;
    }

    return $1;
}


sub __controler_instance
{
    my ($in, $out, $version) = @_;
    my ($major, $minor) = __split_version($version);
    my $class = 'Synctl::Ssh::' . $major . '::' . $minor . '::Controler';
    my $path = $class;

    $path =~ s|::|/|g;
    $path = $path . '.pm';

    require $path;
    return $class->new($in, $out);
}

sub controler
{
    my ($class, $in, $out, @err) = @_;
    my ($client_version, $server_version, $ret);

    $client_version = __find_last_version();
    if (!defined($client_version)) {
	return undef;
    }

    $ret = __send_version($out, $client_version);
    notify(INFO, IPROT, 'transmit', 'client ssh version : ' . $client_version);
    if (!$ret) {
	notify(INFO, IPROT, 'transmit', 'client ssh version : FAILURE');
	return undef;
    }

    $server_version = __recv_version($in);
    if (!$server_version) {
	notify(INFO, IPROT, 'receive', 'server ssh version : ABORT');
	return undef;
    }
    notify(INFO, IPROT, 'receive', 'server ssh version : ' . $server_version);

    $client_version = __find_client_version($server_version);
    if (!defined($client_version)) {
	return undef;
    }
    notify(INFO, IPROT, 'compute', 'used ssh version : ' . $client_version);

    $ret = __send_version($out, $client_version);
    notify(INFO, IPROT, 'transmit', 'used ssh version : ' . $client_version);
    if (!$ret) {
	notify(INFO, IPROT, 'transmit', 'used ssh version : FAILURE');
	return undef;
    }

    return __controler_instance($in, $out, $client_version);
}


sub __server_instance
{
    my ($in, $out, $controler, $version) = @_;
    my ($major, $minor) = __split_version($version);
    my $class = 'Synctl::Ssh::' . $major . '::' . $minor . '::Server';
    my $path = $class;

    $path =~ s|::|/|g;
    $path = $path . '.pm';

    require $path;
    return $class->new($in, $out, $controler);
}

sub server
{
    my ($class, $in, $out, $controler, @err) = @_;
    my ($client_version, $server_version, $ret);

    $client_version = __recv_version($in);
    if (!$client_version) {
	return undef;
    }

    $server_version = __find_server_version($client_version);
    if (!defined($server_version)) {
	return undef;
    }

    $ret = __send_version($out, $server_version);
    if (!$ret) {
	return undef;
    }

    $client_version = __recv_version($in);
    if (!$client_version) {
	return undef;
    } elsif (!__check_compatible_version($client_version, $server_version)) {
	return undef;
    }

    return __server_instance($in, $out, $controler, $server_version);
}


1;
__END__
