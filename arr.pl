#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;

my @t;# = arange(0.01, 10, 0.01);
for (my $t = 0.01; $t <= 10; $t += 0.01) {
	push @t, $t;
}
plt({
	data          => [
		[ # plot 0
			[@t],              # x coordinates
			[map {sin($_)} @t] # y coordinates
		],
		[ # plot 1
			[@t],
			[map {exp($_)} @t]
		]
	],
	'output.file' => '/tmp/twinx.svg',
	'plot.type'   => 'plot',
	'set.options' => [
		'color = "blue"', # plot 0
		'color = "red"'   # plot 1
	],
	tick_params => 'axis = "y", labelcolor = "blue"',
	ylabel      => '"sin", color="blue"', # applies to base ax object
	'twinx.args'  => {
		1 => { # automatically knows that plot 1 is twinned on x
			tick_params => 'axis = "y", labelcolor = "red"',
			ylabel      => '"exp", color="red"',
		}
	},
});
