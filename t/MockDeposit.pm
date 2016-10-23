package t::MockDeposit;

use parent qw(Synctl::Deposit);
use strict;
use warnings;

use Carp;


sub _new
{
    my ($self, $path, $content, $reference, $mapper) = @_;

    if (!defined($self->SUPER::_new())) {
	return undef;
    }
    
    $self->{'path'} = $path;
    $self->{'content'} = $content;
    $self->{'reference'} = $reference;
    $self->{'mapper'} = $mapper;

    return $self;
}

sub _init
{
    return 1;
}

sub path
{
    my ($self) = @_;
    return $self->{'path'};
}

sub _hash
{
    my ($self, $output) = @_;
    my $hash;
    
    if (ref($output) eq 'ARRAY') {
	@$output = ();
	push(@$output, keys(%{$self->{'content'}}));
	return 1;
    }

    if (ref($output) eq 'CODE') {
	foreach $hash (keys(%{$self->{'content'}})) {
	    $output->($hash);
	}
	return 1;
    }

    confess('test not implemented');
}

sub _get
{
    my ($self, $hash) = @_;
    my $count = $self->{'reference'}->{$hash};

    if (!defined($count)) {
	return undef;
    }

    $count++;
    $self->{'reference'}->{$hash} = $count;
    return $count;
}

sub _put
{
    my ($self, $hash) = @_;
    my $count = $self->{'reference'}->{$hash};

    if (!defined($count)) {
	return undef;
    }

    $count--;
    if ($count == 0) {
	delete($self->{'reference'}->{$hash});
	delete($self->{'content'}->{$hash});
    } else {
	$self->{'reference'}->{$hash} = $count;
    }
    return $count;
}


sub _send
{
    my ($self, $input) = @_;
    my ($content, $hash, $count, $tmp);

    if (ref($input) eq 'CODE') {
	$content = '';
	while (defined($tmp = $input->())) {
	    $content .= $tmp;
	}
    } else {
	confess('test not implemented');
    }

    $hash = $self->{'mapper'}->{$content};
    if (!defined($hash)) { confess('test not implemented'); }

    $self->{'content'}->{$hash} = $content;
    
    $count = $self->{'reference'}->{$hash};
    if (!defined($count)) { $count = 0; }
    $count++;

    $self->{'reference'}->{$hash} = $count;
    return $hash;
}

sub _recv
{
    my ($self, $hash, $output) = @_;
    my $content = $self->{'content'}->{$hash};

    if (!defined($content)) { return undef; }

    if (ref($output) eq 'CODE') {
	$output->($content);
	return 1;
    }

    confess('test not implemented');
}


1;
__END__
