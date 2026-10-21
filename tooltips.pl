#!/usr/bin/env perl
use 5.010;
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Matplotlib::Simple;

# tooltips appear only in an SVG opened in a web browser; hover over a point to see its label
scatter(
	output_file => 'tooltips.svg',
	data        => {
		Height => [150, 162, 175, 168],
		Weight => [ 50,  61,  80,  72],
	},
	tooltips    => ['Alice', 'Bob', 'Carol', 'Dave'], # one label per point, in data order
	title       => 'Hover over a point',
);
