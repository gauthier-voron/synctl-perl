package t::MockSnapshot;

use parent qw(Synctl::Snapshot);
use strict;
use warnings;


sub _new
{
    my ($self, $content, $properties) = @_;

    if (!defined($self->SUPER::_new())) {
	return undef;
    }
    
    $self->{'content'} = $content;
    $self->{'properties'} = $properties;

    return $self;
}

sub _init
{
    return 1;
}


sub _set_file
{
    my ($self, $path, $content, %args) = @_;
    
    $self->{'content'}->{$path} = $content;
    $self->{'properties'}->{$path} = \%args;

    return 1;
}

sub _set_directory
{
    my ($self, $path, %args) = @_;

    $self->{'content'}->{$path} = [];
    $self->{'properties'}->{$path} = \%args;

    return 1;
}

sub _get_file
{
    my ($self, $path) = @_;
    
    return $self->{'content'}->{$path};
}

sub _get_directory
{
    my ($self, $path) = @_;
    my ($key, $entry, @entries);

    foreach $key (keys(%{$self->{'content'}})) {
	if ($key =~ m|^$path/*([^/]+)/*$|) {
	    $entry = $1;
	    $entry =~ s|^/*||;
	    push(@entries, $entry);
	}
    }
    
    return \@entries;
}

sub _get_properties
{
    my ($self, $path, @err) = @_;

    return $self->{'properties'}->{$path};
}

sub _flush
{
    my ($self) = @_;
    return 1;
}


1;
__END__
