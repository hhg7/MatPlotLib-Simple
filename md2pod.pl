#!/usr/bin/env perl

use 5.044;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use DDP {output => 'STDOUT', array_max => 10, show_memsize => 1};
use Devel::Confess 'color';
use Markdown::To::POD 'markdown_to_pod';
use HTML::Table;
use List::MoreUtils 'first_index';
use Test::More;
use Test::Pod;
use Test::CPAN::Changes;

sub file2string ($file) {
	open my $fh, '<', $file;
	return do { local $/; <$fh> };
}

# Markdown::To::POD's list-detection regex has no blank line requirement before
# a following heading, so a heading glued straight onto a list (no blank line
# between them) gets swallowed into the final list item: the "=headN" is then
# emitted *inside* the "=over", and the list's "=back" lands after it
# ("You forgot a '=back' before '=headN'", "=back without =over"). This is a
# parse-time failure, so it must be repaired in the Markdown before conversion.
#
# Guarantee a blank line before every heading (ATX "# X" and Setext "X" over a
# row of "=" or "-"). The "\S" mirrors the converter's own header regex (header
# text required, so a bare "###" is left alone). Fenced code regions are
# skipped so "# comment" lines inside them are untouched. GFM table separators
# never match the Setext underline test because they contain pipes.
sub ensure_blank_before_headings ($text) {
	my @lines = split /\n/, $text, -1;
	my @out;
	my $in_fence = 0;
	foreach my $j (0..$#lines) {
		my $ln = $lines[$j];
		$in_fence = !$in_fence if $ln =~ m/^[ \t]*(?:```|~~~)/;
		my $is_atx = !$in_fence && $ln =~ m/^\#{1,6}[ \t]*\S/;
		my $is_setext = !$in_fence && $ln =~ m/\S/
			&& $j < $#lines && $lines[$j+1] =~ m/^[ \t]*(?:=+|-+)[ \t]*$/;
		push @out, ''
			if ($is_atx || $is_setext) && scalar @out > 0 && $out[-1] ne '';
		push @out, $ln;
	}
	return join "\n", @out;
}

# Markdown::To::POD emits a nested list's "=over" directly after the parent
# "=item" line with no blank line between them. POD requires a blank line
# before every command paragraph, so without it the "=over" is absorbed into
# the item's text rather than opening a list; the matching inner "=back" then
# closes the *outer* list, orphaning later "=item"/"=back" directives
# ("'=item' outside of any '=over'", "=back without =over").
#
# Repair by guaranteeing a blank line before every POD command paragraph.
# "=begin X" / "=end X" data blocks are copied verbatim so their raw contents
# are never rewritten.
sub fix_pod_command_spacing ($pod) {
	my @in = split /\n/, $pod, -1;
	my @out;
	my $in_data = 0;
	foreach my $cmd_line (@in) {
		if ($in_data) {
			push @out, $cmd_line;
			$in_data = 0 if $cmd_line =~ m/^=end\b/;
			next;
		}
		if ($cmd_line =~ m/^=\w+/) {
			# a command paragraph must be preceded by a blank line
			push @out, '' if scalar @out > 0 && $out[-1] ne '';
			push @out, $cmd_line;
			$in_data = 1 if $cmd_line =~ m/^=begin\b/;
		} else {
			push @out, $cmd_line;
		}
	}
	return join "\n", @out;
}

# Guarantee balanced =over/=back. Even with the blank-line repairs above, the
# converter can emit a heading while a list is still open (e.g. a Setext-
# underlined heading, or any heading the pre-processor's normalization missed),
# leaving the matching =back stranded after the heading. Close any list still
# open when a heading / =cut / end-of-file is reached, and drop any =back that
# has no open =over. "=begin X" / "=end X" data blocks are passed through
# verbatim so their contents are never miscounted.
sub balance_pod_over_back ($pod) {
	my @in = split /\n/, $pod, -1;
	my @out;
	my $depth = 0;
	my $in_data = 0;
	foreach my $bal_line (@in) {
		if ($in_data) {
			push @out, $bal_line;
			$in_data = 0 if $bal_line =~ m/^=end\b/;
			next;
		}
		if ($bal_line =~ m/^=begin\b/) {
			push @out, $bal_line;
			$in_data = 1;
			next;
		}
		if ($bal_line =~ m/^=over\b/) {
			$depth++;
			push @out, $bal_line;
			next;
		}
		if ($bal_line =~ m/^=back\b/) {
			# drop a =back that has no matching open =over
			if ($depth > 0) {
				$depth--;
				push @out, $bal_line;
			}
			next;
		}
		if ($bal_line =~ m/^=(?:head\d+|cut|pod|encoding)\b/) {
			while ($depth > 0) {
				push @out, '', '=back';
				$depth--;
			}
			push @out, '' if scalar @out > 0 && $out[-1] ne '';
			push @out, $bal_line;
			next;
		}
		push @out, $bal_line;
	}
	while ($depth > 0) {
		push @out, '', '=back';
		$depth--;
	}
	return join "\n", @out;
}

sub insert_file_into_another {
#
# this sub inserts some lines from a donating file into a receiving file
#
	my ($args) = @_;
	my $current_sub = (split(/::/,(caller(0))[3]))[-1]; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	unless (ref $args eq 'HASH') {
		die "args must be given as a hash ref, e.g. \"$current_sub({ filename => 'blah.xlsx' })\"";
	}
	my @reqd_args = (
		'donating.file',      # file that donates text
		'receiving.file',     # file that receives text
		'donate.start.str',   # line in donating file that starts text
		'receiving.start.str' # 
	);
	my @undef_args = grep { !defined $args->{$_}} @reqd_args;
	if (scalar @undef_args > 0) {
		p @undef_args;
		die 'the above args are necessary, but were not defined.';
	}
	my @defined_args = ( @reqd_args,
		'destination.file',  # by default, $args->{'receiving.file'}
		'donate.end.str',    # the string in the donating  file indicating end of saving lines
		'receiving.end.str', # the string in the receiving file indicating end of saving lines
		'substitute'         # an array of text substitutions to do
	);
	my @bad_args = grep { my $key = $_; not grep {$_ eq $key} @defined_args} keys %{ $args };
	if (scalar @bad_args > 0) {
		p @bad_args;
		say 'the above arguments are not recognized.';
		p @defined_args;
		die 'The above args are accepted.'
	}
	my @missing_files = grep {not -f $args->{$_}} ('donating.file', 'receiving.file');
	if (scalar @missing_files > 0) {
		p $args;
		say STDERR 'the above args have these files missing:';
		p @missing_files;
		die 'the above files are missing';
	}
	my $file = file2string($args->{'donating.file'});
	my @donating_file = split /\n/, $file;
	my $start_idx = first_index {$_ eq $args->{'donate.start.str'}} @donating_file;
	if ($start_idx == -1) {
		die "Couldn't find start line in $args->{'donating.file'}";
	}
	my $end_idx = scalar @donating_file - 1; # 'donate.end.str' gets priority
	if (defined $args->{'donate.end.str'}) {
		$end_idx = first_index {$_ eq $args->{'donate.end.str'}} @donating_file;
	}
	die "Couldn't get end string = \"$args->{'donate.end.str'}\"" if $end_idx == -1;
	if ($end_idx <= $start_idx) {
		die "$args->{'donating.file'}: \$end_idx = $end_idx <= \$start_idx = $start_idx";
	}
	@donating_file = @donating_file[$start_idx+1..$end_idx]; # take the lines that are needed
	foreach my $sub (@{ $args->{substitute} }) {
		foreach my $line (@donating_file) {
			$line =~ s/$sub->[0]/$sub->[1]/;
		}
	}
	if (scalar @donating_file == 0) {
		p $args;
		die "there were 0 lines to save from $args->{'donating.file'}";
	}
	$file = file2string($args->{'receiving.file'});
	my @receiving_file = split /\n/, $file;
	$start_idx = first_index {$_ eq $args->{'receiving.start.str'}} @receiving_file;
	if ($start_idx == -1) {
		die "Couldn't find start line in $args->{'receiving.start.str'}";
	}
	$end_idx = scalar @receiving_file - 1;
	if (defined $args->{'receiving.end.str'}) {
		$end_idx = first_index {$_ eq $args->{'receiving.end.str'}} @receiving_file;
	}
	if ($end_idx == -1) {
		die "\"$args->{'donate.end.str'}\" wasn't found in \"$args->{'receiving.file'}\"";
	}
	if ($end_idx <= $start_idx) {
		die "$args->{'receiving.file'}: \$end_idx = $end_idx <= \$start_idx = $start_idx";
	}
	# remove the lines that are supposed to be removed; insert @donating_file
	splice @receiving_file, $start_idx + 1, $end_idx - $start_idx - 1, @donating_file;
	$args->{'destination.file'} = 
	open my $fh, '>', $args->{'receiving.file'};
	say $fh join ("\n", @receiving_file);
	return 1;
}

my $md = file2string('README.md');
# Ensure headings are separated from preceding blocks so the converter's list
# detection terminates correctly before them
$md = ensure_blank_before_headings($md);
my @md = split /\n/, $md;
my @idx = grep {$md[$_] =~ m/\|.+\|/} 0..$#md; # indices with tables
my @table_end = grep {
	($idx[$_+1] - $idx[$_]) > 1
	} 0..$#idx-1; # get table ends
my @table_start = (0, map {$_ + 1} @table_end);
push @table_end, $#idx; # assume that last index is the end of a table (it should be)
foreach my ($table_i, $table_start) (indexed reverse @table_start) {
	my @md_table = @md[@idx[$table_start..$table_end[$table_i]]];
	splice @md, $idx[$table_start], scalar @md_table; # remove the original MD code
	my @table;
	foreach my $line (@md_table) {
		push @table, [grep {$_ ne ''} split /\h*\|\h*/, $line];
	}
	my $t =  HTML::Table->new(-data => \@table);
	my $table = $t->getTable;
	@table = grep {$_ ne ''} split /\n/, $table;
	foreach my $line (@table) {
		$line =~ s/`([^`]+)`/\<code\>$1\<\/code\>/g;
	}
	splice @md, $idx[$table_start], 0, @table; # insert the HTML code
}
$md = join ("\n", @md);
my $pod = markdown_to_pod($md);
say 'Writing README.pod from README.md, which must be copied into lib/Matplotlib/Simple.pm';
open my $tmp, '>', 'README.pod';
say $tmp $pod;
close $tmp;
$pod = file2string('README.pod');
my @pod = split /\n/, $pod;

# get table start and end indices
foreach my $i ( grep {$pod[$_] =~ /^<img\h/} reverse 0..$#pod) {
	next if $pod[$i-1] eq '<p>' eq $pod[$i+1]; # html paragraph
	splice @pod, $i+1, 0, '<p>', ''; # end
	splice @pod, $i, 0, '', '=for html', '<p>',; # start
}
foreach my $i (grep {$pod[$_] eq '<table>'} reverse 0..$#pod) {
	splice @pod, $i, 0, '=for html';
}
unshift @pod, "=encoding utf8\n";

# Repair command-paragraph spacing so nested lists stay balanced POD, then
# close any list left open across a heading and drop stray =back directives
$pod = fix_pod_command_spacing(join "\n", @pod);
$pod = balance_pod_over_back($pod);
@pod = split /\n/, $pod;

# An "=item" outside of any list is a POD error Test::Pod reports, and it can
# only come from the converter, so wrap any orphan in its own list
my $over_depth = 0;
my @fixed_pod;
foreach my $line (@pod) {
	if ($line =~ m/^=over\b/) {
		$over_depth++;
	} elsif ($line =~ m/^=back\b/) {
		$over_depth-- if $over_depth > 0;
	} elsif (($line =~ m/^=item\b/) && ($over_depth == 0)) {
		push @fixed_pod, '' if scalar @fixed_pod > 0 && $fixed_pod[-1] ne '';
		push @fixed_pod, '=over 4', '';
		$over_depth++;
	}
	push @fixed_pod, $line;
}
while ($over_depth > 0) { # close out any block that the wrapping above opened
	push @fixed_pod, '' if scalar @fixed_pod > 0 && $fixed_pod[-1] ne '';
	push @fixed_pod, '=back', '';
	$over_depth--;
}
@pod = @fixed_pod;

open my $fh, '>', 'README.pod';
say $fh join ("\n", @pod);
close $fh;

my $lib = file2string('lib/Matplotlib/Simple.pm');
my @lib = split /\n/, $lib;
my $line = first_index {$_ eq '# from md2pod.pl πατερ ημων ο εν τοις ουρανοις, ἁγιασθήτω τὸ ὄνομά σου'} @lib;
if ($line == -1) {
	die 'Could not find correct line index';
}
splice @lib, 1-(scalar @lib - $line);
push @lib, @pod; # add properly formatted POD text
open $fh, '>', 'lib/Matplotlib/Simple.pm';
say $fh join ("\n", @lib);
close $fh;

insert_file_into_another({
	'donating.file'       => 'mpl.examples.pl',
	'donate.start.str'    => '# Λέγω οὖν, μὴ ἀπώσατο ὁ θεὸς',
	'receiving.file'      => 't/01.all.tests.t',
	'receiving.start.str' => '# Λέγω οὖν, μὴ ἀπώσατο ὁ θεὸς',
	'receiving.end.str'   => '# σὺ δὲ τῇ πίστει ἕστηκας. μὴ ὑψηλὰ φρόνει, ἀλλὰ φοβοῦ',
});

my $test = file2string('t/01.all.tests.t');
my @test = split /\n/, $test;
my $output_idx = '-inf';
my @output_files;
foreach my ($idx, $line) (indexed @test) {
	$line =~ s/\.png'(,?)/.svg'$1/;
	$line =~ s/'output\.images\//'\/tmp\//;
	if ($line =~ m/output\.file\'\h*=\>\h+'(.+)\.svg/) {
		push @output_files, "$1.svg" unless $1 eq '/tmp/dies_ok';
		next;
	}
	if ($line =~ m/^my \@output_files\h*=\h*.+\);$/) {
		$output_idx = $idx;
	}
}
die 'Could not find @output_files declaration in t/01.all.tests.t' if $output_idx < 0;
die 'no output files found' if scalar @output_files == 0;

$test[$output_idx] = 'my @output_files = (\'' . join ("', '", @output_files) . "');";
open my $t, '>', 't/01.all.tests.t';
say $t join ("\n", @test);
close $t;

pod_file_ok( 'lib/Matplotlib/Simple.pm' );

changes_file_ok('Changes'); # hand-maintained; no longer generated from README.md
done_testing();
