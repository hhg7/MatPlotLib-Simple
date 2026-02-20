#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;
use File::Temp;

plt({
	'plot.type' => 'boxplot',
	data        => {
		A => [0..9]
	},
	'output.file' => '/tmp/whiskers.svg',
});
