#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;

plt({
	data        => {
		
	},
	'plot.type' => 'imshow',
	stringmap   => {
		'H' => 'Alpha helix',
		'B' => 'Residue in isolated β-bridge',
		'E' => 'Extended strand, participates in β ladder',
		'G' => '3-helix (3/10 helix)',
		'I' => '5 helix (pi helix)',
		'T' => 'hydrogen bonded turn',
		'S' => 'bend',
		' ' => 'Loops and irregular elements'
	},
	'output.file' => '/tmp/dssp.svg'
});
