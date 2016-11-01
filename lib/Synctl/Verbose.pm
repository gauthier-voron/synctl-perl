package Synctl::Verbose;

use strict;
use warnings;

use Carp;
use Encode;
use POSIX qw(locale_h);

use Synctl qw(:error :verbose);


sub __rw
{
    my ($self, $name, $value) = @_;

    if (defined($value)) {
	$self->{$name} = $value;
    }

    return $self->{$name};
}

sub __state    { return shift->__rw('__state',    @_); }
sub __progress_going { return shift->__rw('__progress_going', @_); }
sub __progress_text { return shift->__rw('__progress_text', @_); }
sub __progress_done { return shift->__rw('__progress_done', @_); }
sub __progress_total { return shift->__rw('__progress_total', @_); }
sub __term     { return shift->__rw('__term',     @_); }
sub __ltext    { return shift->__rw('__ltext',    @_); }
sub __lbar     { return shift->__rw('__lbar',     @_); }
sub __lastsetup { return shift->__rw('__lastsetup', @_); }
sub __first { return shift->__rw('__first', @_); }
sub __last { return shift->__rw('__last', @_); }
sub __fsent { return shift->__rw('__fsent', @_); }
sub __wsent { return shift->__rw('__wsent', @_); }
sub __csent { return shift->__rw('__csent', @_); }
sub __frecv { return shift->__rw('__frecv', @_); }
sub __wrecv { return shift->__rw('__wrecv', @_); }
sub __crecv { return shift->__rw('__crecv', @_); }
sub __encoding { return shift->__rw('__encoding', @_); }


sub new
{
    my ($class, @err) = @_;
    my $self;

    if (@err) {
	return throw(ESYNTAX, shift(@err));
    }

    $self = bless({}, $class);
    $self->__state('');
    $self->__progress_going(0);
    $self->__lastsetup(0);
    $self->__encoding(setlocale(LC_CTYPE));

    $self->__first(0);
    $self->__last(0);
    
    $self->__fsent(0);
    $self->__wsent(0);
    $self->__csent(0);

    $self->__frecv(0);
    $self->__wrecv(0);
    $self->__crecv(0);

    return $self;
}


sub __setup
{
    my ($self) = @_;
    my ($cols, $ltext, $lbar);

    if (-t STDOUT) {
	$cols = `tput cols`;

	$lbar = sprintf("%d", $cols * 2 / 5);
	if ($lbar < 10) {
	    $lbar = 0;
	}

	$ltext = $cols - $lbar - 8;

	$self->__term(1);
	$self->__ltext($ltext);
	$self->__lbar($lbar);
    } else {
	$self->__term(0);
    }
}

sub __restrict_path
{
    my ($path, $maxlen) = @_;
    my $length = length($path);
    my $tlen;

    if ($length <= $maxlen) {
	return $path;
    }

    if ($maxlen <= 2) {
	return ('.' x $maxlen);
    }

    if ($maxlen <= 10) {
	return ('..' . substr($path, -($maxlen - 2)));
    }

    if ($maxlen <= 18) {
	return (substr($path, 0, $maxlen - 10)
		. '..'
		. substr($path, -8));
    }

    if ($maxlen <= 30) {
	$tlen = sprintf("%d", ($maxlen - 2) / 2);
	return (substr($path, 0, $tlen)
		. '..'
		. substr($path, -($maxlen - $tlen - 2)));
    }

    return (substr($path, 0, 14) . '..' . substr($path, -($maxlen - 16)));
}

sub __format_bytes
{
    my ($value) = @_;
    my @suffixes = ('KiB', 'MiB', 'GiB', 'TiB', 'PiB');
    my $suffix = 'B';

    while (@suffixes) {
	if ($value >= 2048) {
	    $value /= 1024;
	    $suffix = shift(@suffixes);
	} else {
	    last;
	}
    }

    if ($suffix eq 'B' || $value >= 100) {
	return sprintf("%d %s", $value, $suffix);
    } else {
	return sprintf("%.1f %s", $value, $suffix);
    }
}

sub __format_speed
{
    my ($value) = @_;
    my @suffixes = ('KiB/s', 'MiB/s', 'GiB/s', 'TiB/s', 'PiB/s');
    my $suffix = 'B/s';

    while (@suffixes) {
	if ($value >= 2048) {
	    $value /= 1024;
	    $suffix = shift(@suffixes);
	} else {
	    last;
	}
    }

    if ($value >= 100) {
	return sprintf("%d %s", $value, $suffix);
    } else {
	return sprintf("%.1f %s", $value, $suffix);
    }
}


sub __print_title
{
    my ($self, $text) = @_;

    $self->__end_progress(0);

    if ($self->__term()) {
	printf("\033[34;1m::\033[0m \033[1m%s\033[0m\n", $text);
    } else {
	printf(":: %s\n", $text);
    }
}

sub __print_info
{
    my ($self, $text) = @_;

    $self->__end_progress(0);
    printf(" %s\n", $text);
}

sub __print_progress
{
    my ($self, $text, $done, $total, $end) = @_;
    my ($ltext, $lbar, $percent, $count);
    my $buffer = '';

    if ($self->__term()) {
	$ltext = $self->__ltext();
	$lbar = $self->__lbar();
	
	$buffer .= sprintf("\r %-" . ($ltext - 1) . "s",
			  __restrict_path($text, $ltext - 1));

	if ($lbar) {
	    if (!defined($total)) {
		$total = '';
	    }
	    
	    $buffer .= sprintf(" [");
	    if ($total =~ /^\d+$/) {
		$percent = sprintf("%d", $done * 100 / $total);
		$count = sprintf("%d", $percent * $lbar / 100);

		$buffer .= sprintf("%s%s", '#' x $count, ' ' x ($lbar-$count));
		$buffer .= sprintf("] %3d%%", $percent);
	    } else {
		if ($total ne '') {
		    $total = ' ' . $total;
		}

		$buffer .= sprintf("%$lbar" . "s", $done . $total . ' ');
		$buffer .= sprintf("]     ");
	    }
	}

	if ($end) {
	    $buffer .= "\n";
	}

	local $| = 1;
	printf("%s", $buffer);
    } elsif ($end && ($done == $total)) {
	printf("* %s\n", $text);
    }
}

sub __print_statistics
{
    my ($self) = @_;
    my ($stat, $getter, $text, $value, %values, $format, $maxlen);
    my @stats = (
	[ \&__fsent, 'Referenced files', undef           ],
	[ \&__wsent, 'Sent files',       undef           ],
	[ \&__csent, 'Sent data',        \&__format_bytes],
	[ \&__frecv, 'Compared files',   undef           ],
	[ \&__wrecv, 'Received files',   undef           ],
	[ \&__crecv, 'Received data',    \&__format_bytes],
	[ \&__speed, 'Transfert speed',  \&__format_speed],
	);

    $self->__print_title('Statistics');

    $maxlen = 0;

    foreach $stat (@stats) {
	($getter, $text, $_) = @$stat;
	if (($value = $getter->($self)) != 0) {
	    $values{$text} = $value;
	    if (length($text) > $maxlen) {
		$maxlen = length($text);
	    }
	}
    }

    foreach $stat (@stats) {
	($_, $text, $format) = @$stat;
	if (!defined($value = $values{$text})) {
	    next;
	}

	if (defined($format)) {
	    $value = $format->($value);
	}
	
	$self->__print_info(sprintf("%-$maxlen" . "s : %s", $text, $value));
    }
}

sub __clean_progress
{
    my ($self, $text) = @_;
    my ($ltext, $lbar);

    if ($self->__term()) {
	$ltext = $self->__ltext();
	$lbar = $self->__lbar();
	
	printf("\r%s\r", ' ' x ($ltext + $lbar + 8));
    } else {
	printf("  %s\n", $text);
    }
}


sub __start_progress
{
    my ($self, $text, $total) = @_;

    $self->__end_progress();
    
    $self->__progress_text($text);
    $self->__progress_done(0);
    $self->__progress_total($total);
    $self->__progress_going(1);

    $self->__print_progress($text, 0, $total);
}

sub __continue_progress
{
    my ($self, $inc) = @_;
    my ($text, $done, $total);
    my ($previous, $current);

    if ($self->__progress_going()) {
	$text = $self->__progress_text();
	$done = $self->__progress_done();
	$total = $self->__progress_total();

	$previous = $done * 100 / $total;

	$done += $inc;
	$self->__progress_done($done);

	$current = $done * 100 / $total;

	if ($current != $previous) {
	    $self->__print_progress($text, $done, $total);
	}
    }
}

sub __end_progress
{
    my ($self, $ender) = @_;
    my ($text, $done);

    if ($self->__progress_going()) {
	if (!defined($ender)) {
	    $ender = 'terminate';
	}

	$text = $self->__progress_text();
	$done = $self->__progress_done();

	if ($ender eq 'terminate' && $done == 0) {
	    $ender = 'abort';
	} elsif ($ender eq 'terminate' && $done != 0) {
	    $ender ='complete';
	}

	if ($ender eq 'abort') {
	    $self->__clean_progress($text);
	} elsif ($ender eq 'complete') {
	    $self->__print_progress($text, 100, 100, 1);
	}
	
	$self->__progress_going(0);
    }
}


sub __notice_loading_references
{
    my ($self) = @_;

    if ($self->__state() ne 'preparing transfert') {
	$self->__print_title('Preparing transfert...');
	$self->__state('preparing transfert');
    } else {
	$self->__end_progress('terminate');
    }

    $self->__start_progress('Loading references');
}

sub __notice_send_file
{
    my ($self, $name) = @_;
    my $encoding = $self->__encoding();

    $self->__end_progress('terminate');

    if ($self->__state() ne 'sending files') {
	$self->__print_title('Sending files...');
	$self->__state('sending files');
    }
    
    $self->__fsent($self->__fsent() + 1);
    $self->__start_progress(Encode::decode($encoding, $name));
}

sub __notice_receive_file
{
    my ($self, $name) = @_;
    my $encoding = $self->__encoding();

    $self->__end_progress('terminate');

    if ($self->__state() ne 'receiving files') {
	$self->__print_title('Receiving files...');
	$self->__state('receiving files');
    }

    $self->__frecv($self->__frecv() + 1);
    $self->__start_progress(Encode::decode($encoding, $name));
}

sub __notice_will_receive_content
{
    my ($self, $amount) = @_;

    if ($self->__state() eq 'receiving files') {
	$self->__wrecv($self->__wrecv() + 1);
    }

    $self->__progress_total($amount);
}

sub __notice_receive_content
{
    my ($self, $amount) = @_;

    if ($self->__first() == 0) {
	$self->__first(time());
    }

    if (defined($amount)) {
	$self->__crecv($self->__crecv() + $amount);
	$self->__continue_progress($amount);
    }

    $self->__last(time());
}

sub __notice_will_send_content
{
    my ($self, $amount) = @_;

    $self->__wsent($self->__wsent() + 1);
    $self->__progress_total($amount);
}

sub __notice_send_content
{
    my ($self, $amount) = @_;

    if ($self->__first() == 0) {
	$self->__first(time());
    }
    
    if (defined($amount)) {
	$self->__csent($self->__csent() + $amount);
	$self->__continue_progress($amount);
    }

    $self->__last(time());
}


sub notice
{
    my ($self, $level, $code, @hints) = @_;
    my ($now, $handler);
    my %handlers = (
	IRLOAD() => \&__notice_loading_references,
	IFRECV() => \&__notice_receive_file,
	IFSEND() => \&__notice_send_file,
	IWRECV() => \&__notice_will_receive_content,
	IWSEND() => \&__notice_will_send_content,
	ICRECV() => \&__notice_receive_content,
	ICSEND() => \&__notice_send_content
	);

    $handler = $handlers{$code};
    if (defined($handler)) {
	$now = time();
	if ($self->__lastsetup() + 10 < $now) {
	    $self->__setup();
	    $self->__lastsetup($now);
	}
	
	$handler->($self, @hints);
    }
}


sub __speed
{
    my ($self) = @_;
    my $duration = $self->__last() - $self->__first();

    if ($duration == 0) {
	return 0;
    } else {
	return ($self->__csent() + $self->__crecv()) / $duration;
    }
}

sub DESTROY
{
    my ($self) = @_;

    if ($self->__lastsetup() != 0) {
	$self->__end_progress('terminate');
	$self->__print_statistics();
    }
}


1;
__END__
