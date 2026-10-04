#!/usr/bin/env perl

use 5.042.2;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;
use DDP;

plt(
	data => [0..7],
	plot_type => 'violin',
	output_file => '/tmp/single.arr.violin.svg'
);
p %ENV;
=my @arr = (
	{
		plot_type => 'plot',
		data        => {
			[0..3],
			[0..3]
		}
	}
);
plt({
	arr           => \@arr,
	output_file => '/tmp/opt.arr.svg'
});
