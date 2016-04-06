package Synctl::Config;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;
use Synctl;


sub _client  { shift()->_rw('_client',  @_); }
sub _server  { shift()->_rw('_server',  @_); }
sub _include { shift()->_rw('_include', @_); }
sub _exclude { shift()->_rw('_exclude', @_); }
sub  client  { shift()->_ro('_client',  @_); }
sub  server  { shift()->_ro('_server',  @_); }
sub  path    { shift()->_rw('_path',    @_); }


sub _read_config_line
{
    my ($self, $line, $lnum) = @_;
    my ($key, $value, $setter, $path);
    my %SETTERS = (
	'client'  => \&_client,
	'server'  => \&_server,
	'include' => \&_add_include,
	'exclude' => \&_add_exclude
	);

    $line =~ s|#.*||;
    $line =~ s|^\s*||;
    $line =~ s|\s*$||;
    return if ($line eq '');

    if (!($line =~ m|^(\w+)\s*=\s*(.*)$|)) {
	$path = $self->path();
	carp("Bad syntax in configuration file '$path:$lnum' : '$line'");
	return undef;
    }

    ($key, $value) = ($1, $2);
    $setter = $SETTERS{$key};

    if (!defined($setter)) {
	$path = $self->path();
	carp("Unknown key in configuration file '$path:$lnum' : '$key'");
	return undef;
    }

    $self->$setter($value);
}

sub init
{
    my ($self, $path, @paths) = @_;
    my ($fd, $fullpath, $line, $lnum);

    $self->SUPER::init();
    $self->_include([]);
    $self->_exclude([]);

    if (!defined($path)) { confess('missing parameter'); }

    if (!@paths) { @paths = ('.'); }
    foreach $fullpath (map { $_ . '/' . $path } @paths) {
	if (open($fd, '<', $fullpath)) {
	    $self->path($fullpath);
	    last;
	}
    }
    if (!defined($self->path())) {
	carp("Cannot find any configuration file '$path'");
	return undef;
    }


    $lnum = 0;
    while ($line = <$fd>) {
	$lnum++;
	$self->_read_config_line($line, $lnum);
    }

    close($fd);
    return $self;
}


sub _add_include
{
    my ($self, $value, @err) = @_;
    my $list = $self->_include();

    push(@$list, $value);
}

sub _add_exclude
{
    my ($self, $value, @err) = @_;
    my $list = $self->_exclude();

    push(@$list, $value);
}


sub include
{
    my ($self, @err) = @_;
    my $list = $self->_include();

    if (@err) { confess('unexpected parameters'); }
    return @$list;
}

sub exclude
{
    my ($self, @err) = @_;
    my $list = $self->_exclude();

    if (@err) { confess('unexpected parameters'); }
    return @$list;
}


sub backend
{
    my ($self, @err) = @_;
    my $server = $self->server();
    my $client = $self->client();
    my $backend;

    if (@err) { confess('unexpected parameters'); }
    if (!defined($server)) { carp('Undefined server scheme'); return undef; }

    $backend = Synctl::backend($server);
    if (!defined($backend)) { return undef; }

    if (defined($client)) { $backend->client($client); }
    $backend->include($self->include());
    $backend->exclude($self->exclude());

    return $backend;
}


1;
__END__
