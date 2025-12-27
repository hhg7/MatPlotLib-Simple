#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
#use DDP {output => 'STDOUT', array_max => 10, show_memsize => 1};
use Devel::Confess 'color';
use Digest::SHA;
use Term::ANSIColor;

sub file2string ($file) {
	open my $fh, '<', $file;
	return do { local $/; <$fh> };
}

sub list_regex_files ($regex, $directory = '.', $case_sensitive = 'yes') {
	die "\"$directory\" doesn't exist" unless -d $directory;
	my @files;
	opendir (my $dh, $directory);
	if ($case_sensitive eq 'yes') {
		$regex = qr/$regex/;
	} else {
		$regex = qr/$regex/i;
	}
	while (my $file = readdir $dh) {
		next if $file !~ $regex;
		next if $file =~ m/^\.{1,2}$/;
		my $f = "$directory/$file";
		next unless -f $f;
		if ($directory eq '.') {
			push @files, $file
		} else {
			push @files, $f
		}
	}
	@files
}
my $filename = 'md5sums.tsv';
open my $tsv, '>', $filename;
foreach my $file (list_regex_files('\.svg$', 'output.images')) {
	my $text = file2string($file);
	my @text = split /\n/, $text;
	@text = grep {$_ !~ m/^\h*\<dc:title\>made.+\/Simple\.pm\<\/dc:title\>$/} @text;
	$text = join ("\n", @text);
	say $tsv "$file\t" . md5_base64($text);
}
say 'wrote ' . colored(['white on_blue'], $filename);
