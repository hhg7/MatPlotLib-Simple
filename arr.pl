#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;
use File::Temp;

#my $fh = File::Temp->new(DIR => '/tmp', SUFFIX => '.py', UNLINK => 0);
plt({
	cbpad       => 0.01,          # default 0.05 is too big
	data        => {
		'sin' => [map {sin($_ * 3.141592653/180)} 0..360],
		'cos' => [map {cos($_ * 3.141592653/180)} 0..360]
	},
	'plot.type'   => 'hexbin',
	'output.file' => '/tmp/hexbin.svg',
	set_ylim      => '0, 1',
});

