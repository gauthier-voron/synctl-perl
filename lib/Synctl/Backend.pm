package Synctl::Backend;

use parent qw(Synctl::Object);
use strict;
use warnings;

use Carp;


sub _client  { shift()->_rw('_client' , @_); }
sub  verbose { shift()->_rw('_verbose', @_); }
sub  dryrun  { shift()->_rw('_dryrun' , @_); }
sub _include { shift()->_rw('_include', @_); }
sub _exclude { shift()->_rw('_exclude', @_); }


sub init
{
    my ($self, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    if (!defined($self->SUPER::init())) {
	return undef;
    }

    $self->verbose(0);
    $self->dryrun(0);
    $self->_include([]);
    $self->_exclude([]);

    return $self;
}


sub client
{
    my ($self, $value, @err) = @_;

    if (@err) { confess("unexpected parameters"); }
    if (defined($value)) {
	if (ref($value) ne '') { confess('value should be a scalar'); }
	if (!$value =~ m|^/|) { confess('value should be an absolute path'); }
	$self->_client($value);
    }

    return $self->_client();
}

sub target
{
    my ($self, @err) = @_;

    confess("unimplemented method");

    return '';
}

sub include
{
    my ($self, @values) = @_;
    my ($value, $list);

    $list = $self->_include();
    
    foreach $value (@values) {
	if (ref($value) ne '') { confess('values should be scalars'); }
	if (!$value =~ m|^/|) { confess('values should be absolute paths'); }

	push(@$list, $value);
    }

    return @$list;
}

sub exclude
{
    my ($self, @values) = @_;
    my ($value, $list);

    $list = $self->_exclude();
    
    foreach $value (@values) {
	if (ref($value) ne '') { confess('values should be scalars'); }
	if (!$value =~ m|^/|) { confess('values should be absolute paths'); }

	push(@$list, $value);
    }

    return @$list;
}


sub _filter_entries
{
    my ($self, @entries) = @_;

    @entries = sort { $b cmp $a }
               grep { ! /^\.\.?$/ }
               grep { /^\d{4}-\d\d-\d\d-\d\d-\d\d-\d\d$/ }
               @entries;

    return @entries;
}


sub _posix_time
{
    my ($s, $mi, $h, $d, $mo, $y) = localtime();

    $mo += 1;
    $y += 1900;

    return sprintf("%04d-%02d-%02d-%02d-%02d-%02d", $y, $mo, $d, $h, $mi, $s);
}

sub _compose_rsync
{
    my ($self, @err) = @_;
    my @command = ('rsync', '-aAHc');
    my ($entry);

    if (@err) { confess("unexpected parameters"); }
    
    if ($self->verbose()) { push(@command, '-v'); }
    if ($self->dryrun())  { push(@command, '-n'); }
    else { push(@command, '-M--fake-super', '-X'); }

    foreach $entry ($self->include()) { push(@command, "--include=$entry" ); }
    foreach $entry ($self->exclude()) { push(@command, "--exclude=$entry" ); }

    return @command;
}

sub _compose_rsync_send
{
    my ($self, $target, @err) = @_;
    my @command = $self->_compose_rsync();
    my ($base, @others) = $self->list();

    if (@err) { confess("unexpected parameters"); }
    if (!defined($self->client())) { carp('Undefined client'); return undef; }
    
    if (defined($base)) { push(@command, '--link-dest=../' . $base . '/'); }

    push(@command, $self->client() . '/');
    push(@command, $target . '/' . $self->_posix_time() . '/');

    return @command;
}

sub _compose_rsync_recv
{
    my ($self, $target, $when, @err) = @_;
    my @command = $self->_compose_rsync();
    my @entries = $self->list();
    my ($base);

    if (@err) { confess("unexpected parameters"); }
    if (!defined($self->client())) { carp('Undefined client'); return undef; }

    if (!defined($when)) {
	$base = shift(@entries);
    } else {
	if (length($when) < 19) {
	    $when .= 'z' x (19 - length($when));
	}
	
	while (@entries && $entries[0] gt $when) {
	    shift(@entries);
	}
	$base = shift(@entries);
    }
    
    if (!defined($base)) {
	return ();
    }

    push(@command, '--delete-after');
    push(@command, $target . '/' . $base . '/');
    push(@command, $self->client() . '/');

    return @command;
}


sub list
{
    my ($self, @err) = @_;
    
    confess("unimplemented method");

    return ('');
}

sub send
{
    my ($self, @err) = @_;
    
    confess("unimplemented method");

    return 0;
}

sub recv
{
    my ($self, $when, @err) = @_;

    confess("unimplemented method");

    return 0;
}


1;
__END__
