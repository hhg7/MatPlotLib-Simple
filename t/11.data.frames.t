#!/usr/bin/env perl
#
# "df": a data frame given whole, with its columns named by role ("x", "y",
# "by", and "color_key" for scatter), turned into the "data" each plot.type
# already takes.
#
# The four shapes are those of Stats::LikeR (lib/Stats/LikeR.pm, _df_shape):
# array of hashes, hash of arrays, hash of hashes (rows taken in the sorted
# order of their names, as Stats::LikeR's vals() takes them) and array of
# arrays (columns by 0-based position). Stats::LikeR is not needed: the frames
# here are written out by hand.
#
# Most of this calls frame_to_data on a plot hash and compares the "data" it
# leaves with the "data" a caller would have written by hand, so it runs
# everywhere, including a Windows smoker with no python. The rest goes through
# plt with execute => 0, and the last block renders, which needs python3 and
# matplotlib >= 3.10 and skips without them, as in t/10.review.fixes.0.317.t.
#
require 5.010;
use strict;
use warnings FATAL => 'all';
use File::Temp 'tempdir';
use File::Spec;
use Capture::Tiny 'capture';
use Matplotlib::Simple;
# The interpreter the module itself runs; see t/07.review.fixes.t.
my @PY = Matplotlib::Simple::python_command();
my $PY = join ' ', @PY;
use Test::More;

my $TMP = tempdir( CLEANUP => 1 );
my $seq = 0;

my $python_raw = ( scalar @PY ? qx/$PY --version 2>&1/ : '' );
my $python_available = ( $? == 0 && $python_raw =~ m/Python\s+3\.\d+/i ) ? 1 : 0;
my $mpl_available = 0;
if ($python_available) {
	# 3.10: the floor t/01 and t/03 gate on; see t/10.review.fixes.0.317.t.
	my $raw = qx/$PY -c "import matplotlib; print(matplotlib.__version__)" 2>&1/;
	if ( $? == 0 && $raw =~ m/^\s*(\d+)\.(\d+)/ ) {
		$mpl_available = ( $1 > 3 || ( $1 == 3 && $2 >= 10 ) ) ? 1 : 0;
	}
}
diag( $mpl_available ? 'matplotlib >= 3.10 found (render checks ON)' : 'no matplotlib >= 3.10 (render checks skipped)' );

# The same six people in each of the four shapes. Bo has no weight.
my @aoh = (
	{ name => 'Al', sex => 'M', height => 180, weight => 80, age => 30 },
	{ name => 'Bo', sex => 'F', height => 160, weight => undef, age => 25 },
	{ name => 'Cy', sex => 'M', height => 175, weight => 75, age => 41 },
	{ name => 'Di', sex => 'F', height => 165, weight => 60, age => 35 },
	{ name => 'Ed', sex => 'M', height => 170, weight => 70, age => 52 },
	{ name => 'Fi', sex => 'F', height => 155, weight => 50, age => 28 },
);
my @columns = ( 'name', 'sex', 'height', 'weight', 'age' );
my %hoa;
foreach my $row (@aoh) {
	push @{ $hoa{$_} }, $row->{$_} foreach @columns;
}
my %hoh = map { my %r = %{$_}; ( delete $r{name} ) => \%r } @aoh;    # row names are the names
my @aoa = map { [ @{$_}{@columns} ] } @aoh;                            # name=0 sex=1 height=2 weight=3 age=4
my %frame = ( AoH => \@aoh, HoA => \%hoa, HoH => \%hoh );

# frame_to_data on a fresh plot hash; returns the hash and the warnings given.
sub convert {
	my ( $type, %plot ) = @_;
	my @warned;
	local $SIG{__WARN__} = sub { push @warned, $_[0] };
	Matplotlib::Simple::frame_to_data( \%plot, $type, '', 'plt' );
	return ( \%plot, \@warned );
}

# Only the message, never the Devel::Confess trace that follows it, is matched.
sub converts_dying {
	my ( $type, $plot, $like, $name ) = @_;
	my $died = eval { convert( $type, %{$plot} ); 1 } ? '' : "$@";
	$died =~ s/\n\t.*\z//s;
	return ok( 0, "$name (did not die)" ) unless length $died;
	like( $died, $like, $name ) or diag("  died: $died");
	return;
}

sub out_file { return File::Spec->catfile( $TMP, 'gen' . $seq++ . '.svg' ) }

sub slurp {
	my ($file) = @_;
	open my $in, '<:encoding(UTF-8)', $file or die "can't read $file: $!";
	local $/;
	my $text = <$in>;
	close $in;
	return $text;
}

# Build one figure with execute => 0 and return the generated python as text.
sub gen {
	my (%spec) = @_;
	$spec{'output.file'} = out_file();
	$spec{execute} = 0;
	my ( $out, $err, $pyfile ) = capture { plt( \%spec ) };
	return slurp($pyfile);
}

sub gen_dying {
	my ( $spec, $like, $name ) = @_;
	my ( $out, $err, $died ) = capture { eval { gen( %{$spec} ); 1 } ? '' : "$@" };
	$died =~ s/\n\t.*\z//s;
	return ok( 0, "$name (did not die)" ) unless length $died;
	like( $died, $like, $name ) or diag("  died: $died");
	return;
}

# ----------------------------------------------------------------------------
# 1. Every shape gives the same "data", for the paired types.
# ----------------------------------------------------------------------------
foreach my $shape ( sort keys %frame ) {
	my ( $plot, $warned ) = convert( 'scatter', df => $frame{$shape}, x => 'height', y => 'weight', color_key => 'age' );
	is_deeply(
		$plot->{data},
		{ height => [ 180, 175, 165, 170, 155 ], weight => [ 80, 75, 60, 70, 50 ], age => [ 30, 41, 35, 52, 28 ] },
		"scatter from $shape: x, y and color in step, row by row, Bo left out"
	);
	is_deeply( $plot->{'keys'}, [ 'height', 'weight', 'age' ], "scatter from $shape: \"keys\" puts x first and y second" );
	ok( !exists $plot->{df} && !exists $plot->{x} && !exists $plot->{y}, "scatter from $shape: the frame's own keys are gone" );
	is( scalar @{$warned}, 1, "scatter from $shape: one warning" );
	like( $warned->[0] // '', qr/left out 1 of 6 rows of "df", which have no value in "height" or "weight" or "age"/, "scatter from $shape: it counts the row left out" );
}
{
	my ($plot) = convert( 'hist2d', df => \@aoa, x => 2, y => -2 );
	is_deeply( $plot->{data}, { 2 => [ 180, 175, 165, 170, 155 ], -2 => [ 80, 75, 60, 70, 50 ] }, 'hist2d from AoA: columns by position, negative from the end' );
	is_deeply( $plot->{'key.order'}, [ 2, -2 ], 'hist2d: "key.order" is x then y, whatever the sort would say' );
	($plot) = convert( 'hexbin', df => \%hoa, x => 'weight', y => 'height' );
	is_deeply( $plot->{'key.order'}, [ 'weight', 'height' ], 'hexbin: weight on x, though "height" sorts first' );
}

# ----------------------------------------------------------------------------
# 2. bar, barh and pie: one bar per row, in the frame's order.
# ----------------------------------------------------------------------------
{
	my ( $plot, $warned ) = convert( 'bar', df => \@aoh, x => 'name', y => 'height' );
	is_deeply( $plot->{data}, { Al => 180, Bo => 160, Cy => 175, Di => 165, Ed => 170, Fi => 155 }, 'bar: label => value' );
	is_deeply( $plot->{'key.order'}, [qw(Al Bo Cy Di Ed Fi)], 'bar: the bars are in row order' );
	is( $plot->{xlabel}, "'name'",   'bar: xlabel is the label column, as python text' );
	is( $plot->{ylabel}, "'height'", 'bar: ylabel is the value column' );
	is( scalar @{$warned}, 0, 'bar: nothing left out, nothing said' );

	($plot) = convert( 'bar', df => [ reverse @aoh ], x => 'name', y => 'age', xlabel => 'Person' );
	is_deeply( $plot->{'key.order'}, [qw(Fi Ed Di Cy Bo Al)], 'bar: a frame in another order keeps its order' );
	is( $plot->{xlabel}, 'Person', 'bar: the caller\'s own xlabel stands' );

	($plot) = convert( 'barh', df => \%hoh, y => 'age' );
	is_deeply( $plot->{data}, { Al => 30, Bo => 25, Cy => 41, Di => 35, Ed => 52, Fi => 28 }, 'barh from HoH without "x": the row names are the labels' );
	is( $plot->{xlabel}, "'age'", 'barh: the value axis is x' );
	ok( !defined $plot->{ylabel}, 'barh: no label for the row names, which have no column name' );

	($plot) = convert( 'bar', df => \%hoa, x => 'name', y => [ 'age', 'height' ], color => { height => 'red', age => 'blue' } );
	is_deeply( $plot->{data}{Al}, [ 30, 180 ], 'bar with two y columns: one array per label, in the order "y" gave' );
	is_deeply( $plot->{label}, [ 'age', 'height' ], 'bar with two y columns: the series are named by column' );
	is_deeply( $plot->{color}, [ 'blue', 'red' ], 'bar with two y columns: a color hash keyed by column is put in series order' );

	($plot) = convert( 'pie', df => \@aoh, x => 'name', y => 'age' );
	is( $plot->{data}{Ed}, 52, 'pie: label => value' );
	ok( !defined $plot->{xlabel}, 'pie: no axis labels' );
}
# A pivot: "by" makes one series per group.
{
	my @sales;
	foreach my $q ( 'Q1', 'Q2' ) {
		push @sales, { q => $q, year => $_, sales => ( $q eq 'Q1' ? 1 : 2 ) * $_ } foreach ( 10, 9 );
	}
	my ($plot) = convert( 'bar', df => \@sales, x => 'q', y => 'sales', by => 'year', color => { 9 => 'red', 10 => 'blue' } );
	is_deeply( $plot->{data}, { Q1 => [ 9, 10 ], Q2 => [ 18, 20 ] }, 'bar by: one value per label per group' );
	is_deeply( $plot->{label}, [ 9, 10 ], 'bar by: the groups are in numeric order, 9 before 10' );
	is_deeply( $plot->{color}, [ 'red', 'blue' ], 'bar by: a color hash keyed by group is put in group order' );
	converts_dying( 'bar', { df => [ @sales[ 0 .. 2 ] ], x => 'q', y => 'sales', by => 'year' },
		qr/no row of "df" has a value for "Q2"\/"9" \("q"\/"year"\)/, 'bar by: a missing pair is named, not drawn as nothing' );
	converts_dying( 'bar', { df => [ @sales, $sales[0] ], x => 'q', y => 'sales', by => 'year' },
		qr/more than one row of "df" has "q" = "Q1" and "year" = "10".*agg/, 'bar by: a repeated pair is refused, pointing to agg' );
}

# ----------------------------------------------------------------------------
# 3. Distributions: one per column, or one per group.
# ----------------------------------------------------------------------------
{
	my ( $plot, $warned ) = convert( 'hist', df => \@aoh, x => [ 'weight', 'age' ] );
	is_deeply( $plot->{data}, { weight => [ 80, 75, 60, 70, 50 ], age => [ 30, 25, 41, 35, 52, 28 ] }, 'hist with two columns: a missing weight costs only the weight' );
	is( scalar @{$warned}, 1, 'hist with two columns: one warning, for the one column with a gap' );
	ok( !exists $plot->{'key.order'}, 'hist: no "key.order", which hist does not take' );

	($plot) = convert( 'boxplot', df => \%hoa, y => 'height', by => 'sex' );
	is_deeply( $plot->{data}, { M => [ 180, 175, 170 ], F => [ 160, 165, 155 ] }, 'boxplot by: values grouped' );
	is_deeply( $plot->{'key.order'}, [ 'F', 'M' ], 'boxplot by: groups in sorted order' );
	is( $plot->{xlabel}, "'sex'",    'boxplot by: x is the grouping column' );
	is( $plot->{ylabel}, "'height'", 'boxplot by: y is the value column' );

	($plot) = convert( 'violin', df => \@aoh, y => [ 'weight', 'height' ], orientation => 'horizontal' );
	is_deeply( $plot->{'key.order'}, [ 'weight', 'height' ], 'violin: columns in the order "y" gave' );
	ok( !defined $plot->{xlabel} && !defined $plot->{ylabel}, 'violin with two columns: no one column to label the axis by' );

	($plot) = convert( 'boxplot', df => \@aoh, y => 'age', by => 'sex', orientation => 'horizontal' );
	is( $plot->{xlabel}, "'age'", 'boxplot horizontal: the values are on x' );
}

# ----------------------------------------------------------------------------
# 4. plot: lines in the order of x.
# ----------------------------------------------------------------------------
{
	my ($plot) = convert( 'plot', df => \@aoh, x => 'height', y => 'age' );
	is_deeply( $plot->{data}{age}, [ [ 155, 160, 165, 170, 175, 180 ], [ 28, 25, 35, 52, 41, 30 ] ], 'plot: one line, sorted by x' );
	is( $plot->{'show.legend'}, 0, 'plot: one line needs no legend' );

	($plot) = convert( 'plot', df => \%hoh, x => 'height', y => 'weight', by => 'sex' );
	is_deeply( $plot->{data}{F}, [ [ 155, 165 ], [ 50, 60 ] ], 'plot by: one line per group, Bo left out' );
	is_deeply( $plot->{'key.order'}, [ 'F', 'M' ], 'plot by: the groups in order' );
	ok( !exists $plot->{'show.legend'}, 'plot by: the legend is left on' );

	($plot) = convert( 'plot', df => \@aoh, x => 'height', y => [ 'weight', 'age' ] );
	is( scalar @{ $plot->{data}{age}[0] }, 6, 'plot with two y columns: each line keeps the rows it has values for' );
	is( scalar @{ $plot->{data}{weight}[0] }, 5, 'plot with two y columns: and loses only its own' );
}

# ----------------------------------------------------------------------------
# 5. colored_table: the frame is the table.
# ----------------------------------------------------------------------------
{
	my ($plot) = convert( 'colored_table', df => \%hoh, y => [ 'height', 'weight' ] );
	is_deeply( $plot->{data}{Bo}, { height => 160 }, 'colored_table: an undefined cell is left out, for the table to show as undefined' );
	($plot) = convert( 'colored_table', df => \@aoh, x => 'name' );
	is_deeply( [ sort keys %{ $plot->{data}{Al} } ], [ 'age', 'height', 'sex', 'weight' ], 'colored_table without "y": every column but x' );
}

# ----------------------------------------------------------------------------
# 6. What is refused, and how it is named.
# ----------------------------------------------------------------------------
converts_dying( 'bar', { df => \@aoh, x => 'name', y => 'hieght' }, qr/no column "hieght"; perhaps you meant "height"/, 'a misspelt column is named, with what was meant' );
converts_dying( 'bar', { df => \%hoa, x => 'name', y => 'hieght' }, qr/no column "hieght"/, 'and in a hash of arrays' );
converts_dying( 'bar', { df => \@aoh, y => 'height' }, qr/needs "x".*only a hash of hashes has row names/, 'bar without "x" needs row names' );
converts_dying( 'hist', { df => \@aoh, y => 'height' }, qr/takes its columns of "df" in "x" and "by", not in "y"/, 'a role the type does not read is refused' );
converts_dying( 'scatter', { df => \@aoh, x => 'height', y => [ 'weight', 'age' ] }, qr/"y" can name only one column for plot.type "scatter"/, 'only the "many" role takes several' );
converts_dying( 'boxplot', { df => \@aoh, y => [ 'weight', 'age' ], by => 'sex' }, qr/"by" splits one column/, '"by" with several columns is refused' );
converts_dying( 'scatter', { df => \@aoh, x => 'height', y => 'height' }, qr/"height" is named more than once/, 'a column named twice is refused' );
converts_dying( 'scatter', { df => \@aoh, x => 'height', y => 'weight', keys => [ 'weight', 'height' ] }, qr/"keys" cannot be given with "df"/, '"keys" would contradict x and y' );
converts_dying( 'hist2d', { df => \@aoh, x => 'height', y => 'weight', 'key.order' => [ 'weight', 'height' ] }, qr/"key.order" cannot be given with "df"/, 'so would "key.order" for hist2d' );
converts_dying( 'bar', { df => \@aoh, x => 'sex', y => 'height' }, qr/"M" appears in more than one row of "sex".*agg/, 'bar: a repeated label is refused' );
converts_dying( 'wide', { df => \@aoh, x => 'height', y => 'weight' }, qr/plot.type "wide" does not take "df"/, 'a type that cannot read a frame says so' );
converts_dying( 'bar', { df => \@aoh, data => { A => 1 }, x => 'name', y => 'age' }, qr/"df" and "data" cannot both be given/, '"df" with "data" is refused' );
converts_dying( 'bar', { df => { A => [1], B => { C => 1 } }, x => 'A', y => 'B' }, qr/all be ARRAY \(HoA.*or all HASH \(HoH/, 'a hash mixing arrays and hashes is refused' );
converts_dying( 'bar', { df => [ 1, 2 ], x => 0, y => 1 }, qr/rows must be ARRAY \(AoA\) or HASH \(AoH\)/, 'an array of plain values is refused' );
converts_dying( 'hist2d', { df => \@aoa, x => 5, y => 1 }, qr/0-based positions from 0 to 4/, 'an AoA column past the end is refused' );
converts_dying( 'hist2d', { df => { a => [ 1, 2 ], b => [1] }, x => 'a', y => 'b' }, qr/same number of rows, but they have "a" 2, "b" 1/, 'a ragged hash of arrays is refused' );
converts_dying( 'bar', { x => 'name', y => 'age' }, qr/"x", "y" name columns of "df", but no "df" was given/, '"x" and "y" without "df"' );

# ----------------------------------------------------------------------------
# 7. Through plt: the wrappers, subplots, "add" graphs, and the caller's data.
# ----------------------------------------------------------------------------
{
	my %spec   = ( 'plot.type' => 'scatter', df => \@aoh, x => 'height', y => 'weight' );
	my @before = map { { %{$_} } } @aoh;
	my $py;
	{
		local $SIG{__WARN__} = sub { };
		$py = gen(%spec);
	}
	like( $py, qr/ax0\.scatter\(/, 'plt: a scatter is drawn from "df"' );
	is_deeply( \@aoh, \@before, 'plt: the frame is left as it was' );
	ok( exists $spec{df} && exists $spec{x}, 'plt: the caller\'s hash keeps its "df" and "x"' );

	local $SIG{__WARN__} = sub { };
	my ( $out, $err, $file ) = capture {
		Matplotlib::Simple::bar( 'output.file' => out_file(), execute => 0, df => \%hoa, x => 'name', y => 'age' );
	};
	like( slurp($file), qr/ax0\.bar\(/, 'bar(): the wrapper takes "df"' );

	$py = gen(
		p => [
			{ 'plot.type' => 'hist', df => \@aoh, x => 'age' },
			[ { 'plot.type' => 'scatter', df => \@aoh, x => 'height', y => 'weight' }, { 'plot.type' => 'plot', df => \@aoh, x => 'height', y => 'age' } ],
		]
	);
	like( $py, qr/ax0\.hist\(/,    'p: a subplot takes "df"' );
	like( $py, qr/ax1\.plot\(/,    'p: and so does an overlay, from its own frame' );
	gen_dying( { plots => [ { 'plot.type' => 'hist', data => [1] } ], df => \@aoh }, qr/"df" belongs to a subplot/, '"df" at the top of a figure of subplots is refused' );
	gen_dying( { 'plot.type' => 'scatter', df => \@aoh, x => 'height', y => 'weight', notch => 1 }, qr/"notch".*isn't defined|notch/, 'the other options are still checked after "df" is turned into "data"' );
}

# ----------------------------------------------------------------------------
# 8. It renders.
# ----------------------------------------------------------------------------
SKIP: {
	skip( 'no matplotlib >= 3.10', 1 ) unless $mpl_available;
	my $file = File::Spec->catfile( $TMP, 'frame.svg' );
	my ( $out, $err, $died ) = capture {
		eval {
			plt(
				'output.file' => $file,
				p             => [
					{ 'plot.type' => 'bar',     df => \@aoh, x => 'name',   y => [ 'age', 'height' ] },
					{ 'plot.type' => 'boxplot', df => \%hoa, y => 'height', by => 'sex' },
					{ 'plot.type' => 'scatter', df => \%hoh, x => 'height', y => 'weight', color_key => 'age', by => 'sex' },
					{ 'plot.type' => 'hist2d',  df => \@aoa, x => 2,        y => 4 },
				],
			);
			1;
		} ? '' : "$@";
	};
	ok( !length $died && -s $file, 'bar, boxplot, scatter by group and hist2d from four shapes render' ) or diag("  died: $died$err");
}

done_testing();
