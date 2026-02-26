#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;

scatter({
	'output.file' => '/tmp/hist2d.logscale.svg',
	data        => {
		A => [1..9],
		B => [1..9]
	},
	logscale => ['x', 'y']
});
