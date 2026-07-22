#!/usr/bin/env perl

use 5.044;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use DDP {output => 'STDOUT', array_max => 10, show_memsize => 1};
use Devel::Confess 'color';
use Matplotlib::Simple;

plt(
 	'output.file' => 'output.images/venn.svg',
 	ncols         => 2,
 	suptitle      => 'Proportional-area Venn diagrams',
 	plots => [
 		{
 			'plot.type' => 'venn_proportional_area',
 			title       => 'Two sets',
 			data        => {
 				Perl   => [qw(regex hashes CPAN sigils)],
 				Python => [qw(regex hashes pip indentation)],
 			},
 		},
 		{
 			'plot.type'  => 'venn_proportional_area',
 			title        => 'Three sets with colors',
 			set_colors   => [qw(skyblue lightgreen salmon)],
 			alpha        => 0.5,
 			data         => {
 				Mammals => [qw(bat whale dog cat human platypus)],
 				Aquatic => [qw(whale shark octopus platypus)],
 				Legged  => [qw(dog cat human bat platypus shark)],
 			},
 		},
 	],
);
