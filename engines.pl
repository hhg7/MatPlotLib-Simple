#!/usr/bin/env perl

use 5.044;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Cn::Util;
use Matplotlib::Simple;

bar(
	output_file => '/tmp/bar.svg',
	engine      => 'gnuplot',
	data        => {
		Russia => 142,
		USA    => 300,
	},
	style       => 'native'
);
