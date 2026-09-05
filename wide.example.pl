#!/usr/bin/env perl
=head1 wide.example.pl

Generator for the three C<wide> figures shown in the README.

This script is not shipped in the CPAN distribution (dist.ini's PruneFiles and
MANIFEST.SKIP drop every .pl but Makefile.PL); it lives in the git repository
beside the images it writes.  Re-run it from the repository root with

	perl -Ilib wide.example.pl

which rewrites output.images/single.wide.png, output.images/wide.png and
output.images/wide.and.violin.png in place.  The code below is the code printed
in the "wide" section of README.md, with one addition: srand is seeded so that
re-running the generator reproduces the committed images rather than a fresh set
of random replicates.

=cut

use strict;
use warnings FATAL => 'all';
use autodie ':all';
use Matplotlib::Simple;

srand 20260727;	# fixed so the committed PNGs are reproducible

sub rand_between {
	my ( $min, $max ) = @_;
	return $min + rand( $max - $min );
}

my @x = 0 .. 100;
my %runs;
foreach my $group ( 'Clinical', 'HGI' ) {
	my $shift = $group eq 'HGI' ? 1 : 0;	# HGI sits one unit above Clinical
	foreach my $replicate ( 1 .. 3 ) {
		push @{ $runs{$group} }, [
			[@x],                                                          # x
			[ map { $shift + sin( $_ / 10 ) + rand_between( -0.2, 0.2 ) } @x ] # y
		];
	}
}

wide(
	'output.file' => 'output.images/single.wide.png',
	data          => \%runs,
	color         => {	# one color per group
		Clinical => 'blue',
		HGI      => 'green',
	},
	title         => 'Visualization of similar lines plotted together',
	xlabel        => 'time',
	ylabel        => 'signal',
);

plt(
	'output.file' => 'output.images/wide.png',
	ncols         => 2,
	suptitle      => 'Replicate runs, summarised',
	plots         => [
		{
			'plot.type' => 'wide',
			data        => \%runs,                          # hash of groups of runs
			color       => { Clinical => 'blue', HGI => 'green' },
			title       => '"Two groups, mean +/- 1 s.d."', # comma: quoted
			xlabel      => 'time',
			ylabel      => 'signal',
		},
		{
			'plot.type'   => 'wide',
			data          => $runs{Clinical},               # just the runs, unlabelled
			color         => 'red',
			'show.legend' => 0,
			title         => 'One group with no legend',
			xlabel        => 'time',
		},
	],
);

my %endpoints;
foreach my $group ( keys %runs ) {
	@{ $endpoints{$group} } = map { $_->[1][-1] } @{ $runs{$group} };
}
plt(
	'output.file' => 'output.images/wide.and.violin.png',
	ncols         => 2,
	plots         => [
		{
			'plot.type' => 'wide',
			data        => \%runs,
			color       => { Clinical => 'blue', HGI => 'green' },
			title       => 'Runs over time',
		},
		{
			'plot.type' => 'violinplot',
			data        => \%endpoints,	# hash of arrays, same keys
			colors      => { Clinical => 'blue', HGI => 'green' },
			title       => 'Final values',
		},
	],
);
