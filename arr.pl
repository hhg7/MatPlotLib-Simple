#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;

scatter({
	add           => [
	{
		'plot.type' => 'plot',
		'show.legend' => 0,
		data        => {
			A => [
				[1..9],
				[1..9]
			]
		}
	}
	],
	'output.file' => '/tmp/scatter.logscale.svg',
	data        => {
		A => [1..9],
		B => [1..9]
	},
	logscale => ['x', 'y']
});
