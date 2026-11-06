#!/usr/bin/env perl

=pod

Draws the figures in README.md's "Engines" section: one figure of four simple
subplots, the same call each time, by matplotlib, gnuplot and ggplot2 in each
engine's default style.  The PNGs are committed under output.images/, and the
README links them by their raw.githubusercontent.com URL so that the POD made
from it shows them on metacpan too.  Re-run from the repository root with

	perl -Ilib engine.examples.pl

which needs python3 with matplotlib, gnuplot and Rscript with ggplot2.

=cut

use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Matplotlib::Simple 'plt';

# Fixed seed, so that re-running draws the same points and the committed PNGs
# change only when an engine's drawing does.
srand(20261106);

# Box-Muller: $n normal deviates of mean $mean and s.d. $sd
sub normal {
	my ($mean, $sd, $n) = @_;
	my @out;
	while (@out < $n) {
		my ($u, $v) = (1 - rand, rand);
		push @out, $mean + $sd * sqrt(-2 * log $u) * cos(6.283185307179586 * $v);
	}
	return \@out;
}

my %groups = (
	A => normal(100, 15, 200),
	B => normal(85,  10, 200),
);
my @x = map { $_ / 4 } 0 .. 40;

foreach my $engine (qw(matplotlib gnuplot ggplot2)) {
	plt(
		output_file => "output.images/engine.$engine.png",
		engine      => $engine,
		ncols       => 2,
		nrows       => 2,
		suptitle    => "engine: $engine",
		plots       => [
			{
				plot_type => 'bar',
				title     => 'bar',
				data      => { Matthew => 18345, Mark => 11304, Luke => 19482, John => 15635 },
			},
			{
				plot_type => 'boxplot',
				title     => 'boxplot',
				data      => \%groups,
			},
			{
				plot_type => 'hist',
				title     => 'hist',
				data      => \%groups,
			},
			{
				plot_type => 'plot',
				title     => 'plot',
				data      => {
					sin => [ \@x, [ map { sin } @x ] ],
					cos => [ \@x, [ map { cos } @x ] ],
				},
			},
		],
	);
	print "output.images/engine.$engine.png\n";
}
