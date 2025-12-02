#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;

my $str = 'H-H	432
N-H 	391
I-I 	149
C=C 	614
H-F 	565
N-N 	160
I-Cl 	208
C≡C 	839
H-Cl 	427
N-F 	272
I-Br 	175
O=O 	495
H-Br 	363
N-Cl 	200
C=O* 	745
H-I 	295
N-Br 	243
S-H 	347
C≡O 	1072
N-O 	201
S-F 	327
N=O 	607
C-H 	413
O-H 	467
S-Cl 	253
N=N 	418
C-C 	347
O-O 146
S-Br 	218
N≡N 	941
C-N 	305
O-F 190
S-S 	266
C≡N 	891
C-O 	358
O-Cl 	203
C=N 	615
C-F 	485
O-I 	234
Si-Si 	340
C-Cl 	339
Si-H 	393
C-Br 	276
F-F 	154
Si-C 	360
C-I 	240
F-Cl 	253
Si-O 	452
C-S 	259
F-Br 	237
Cl-Cl 	239
Cl-Br 	218
Br-Br 	193';
my %bond_dissociation;
my @l = split /\n/, $str;
foreach my $l (grep {/\-/} @l) {
	p $l;
	my $bond;
	if ($l =~ m/([\-=≡])/) {
		$bond = $1;
	} else {
		die "$l failed regex.";
	}
	my @line = split /\h+/, $l;
	p @line;
	my @atom = grep {$_ ne ''} split /\h*[-=≡]\h*/, $line[0];
	p @atom;
	$bond_dissociation{$atom[0]}{$atom[1]} = $line[1];
	$bond_dissociation{$atom[1]}{$atom[0]} = $line[1];
}
colored_table({
	'output.file' => '/tmp/single.bonds.svg',
	data          => \%bond_dissociation,
	'col.labels'  => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
	'row.labels'  => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
	'show.numbers'=> 1,
});
