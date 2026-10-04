#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use autodie ':all';
use feature 'say';
use File::Temp 'tempfile';
use DDP { output => 'STDOUT', array_max => 10, show_memsize => 1 };
use Devel::Confess 'color';
use Matplotlib::Simple qw(bar plot);

my $base_code = <<'END_OF_CODE';
sub bar { # a wrapper to simplify calling
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1];
	if ((defined $args->{'plot_type'}) && ($args->{'plot_type'} ne $current_sub)) {
		warn "$args->{'plot_type'} will be ignored for $current_sub";
	}
	if (defined $args->{plots}) {
		die "\"plots\" is meant for the subroutin \"plot\"; $current_sub is single-only";
	}
	plot({
		%{ $args },
		plot_type => $current_sub
	});
}
END_OF_CODE
foreach my $m ('barh', 'boxplot','hist','hist2d','imshow','pie','scatter','violin','wide') {
	my $code = $base_code;
	$code =~ s/^sub bar \{/sub $m \{/;
	say $code;
}
=bar({
   output_file => '/tmp/gospel.word.counts.png',
   data              => {
	  Matthew => 18345,
	  Mark    => 11304,
	  Luke    => 19482,
	  John    => 15635,
   }
});
