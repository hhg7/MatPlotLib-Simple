#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;
use File::Temp;

plt({
	plots => [
		{
			color        => {
				A => 'red', B => 'green', C => 'blue'
			},
			data => {
				A => 1, B => 2, C => 3
			},
			'plot.type'   => 'bar'
		},
		{
			color        => {
				A => 'red', B => 'green', C => 'blue'
			},
			data => {
				A => 1, B => 2, C => 3
			},
			'plot.type'   => 'barh'
		},
	],
	ncols         => 2,
	'output.file' => '/tmp/key.colors.bar.svg',
});
