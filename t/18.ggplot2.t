#!/usr/bin/env perl
#
# The ggplot2 engine, engine => 'ggplot2': the R script it writes, the plot
# types and keywords it refuses by name, and the figures it draws.
#
# Blocks 1 to 14 read the generated R as text and need no R at all, so they run
# on a Windows smoker, which is where escaping and paths break; 9 to 13 are
# about "style", the default "matplotlib" against "native". Block 15 parses
# every script written here with R's own parser, as t/05.generated.python.t
# does with Python's, and needs Rscript. Blocks 16 and 17 render, one in each
# style, and need Rscript with ggplot2 3.5.0 or newer -- the version the script
# itself asks for, $Cn::Plot::Ggplot2::min_ggplot2, which is the first with the
# "transform" argument of the position scales and geom_boxplot's
# "staplewidth"; what "native" adds, geom_bin_2d, after_stat and "orientation",
# is older. Without either, they SKIP. Block 18 needs nothing.
#
# The figures were compared by eye with matplotlib's from the same arguments,
# type by type, in PNGs drawn by both engines: that is not something a test
# can check, and was done by hand for 0.4.
#
require 5.010;
use strict;
use warnings FATAL => 'all';
use utf8;
use File::Temp 'tempdir';
use File::Spec;
use Capture::Tiny 'capture';
use Cn::Plot;
use Test::More;

my $TMP = tempdir( CLEANUP => 1 );
my $seq = 0;
sub out_file {
	my ($ext) = @_;
	return File::Spec->catfile( $TMP, 'gg' . $seq++ . '.' . ( $ext // 'svg' ) );
}
sub slurp {
	my ($file) = @_;
	open my $in, '<:raw', $file or die "can't read $file: $!";
	local $/;
	my $text = <$in>;
	close $in;
	return $text;
}
my @scripts;    # every script written, for R's parser in block 10
# The script plt writes, with execute => 0, as text.
sub script_of {
	my (%args) = @_;
	my ( undef, undef, $file ) = capture { plt( engine => 'ggplot2', execute => 0, output_file => out_file(), %args ) };
	push @scripts, $file;
	return slurp($file);
}
# The message plt dies with, without its stack trace.
sub refusal {
	my (%args) = @_;
	my ( undef, undef ) = capture { eval { plt( engine => 'ggplot2', execute => 0, output_file => out_file(), %args ) } };
	return ( "$@" =~ s/ at \S+ line \d+.*//sr );
}

my @x = ( 1, 2, 3, 4, 5, 6 );
my @y = ( 2, 4, 3, 5, 7, 6 );
my %every_type = (
	bar           => { data => { A => 1, B => 2 } },
	barh          => { data => { A => 1, B => 2 } },
	boxplot       => { data => { A => [ 1, 2, 3, 4 ], B => [ 2, 3, 4, 9 ] } },
	colored_table => { data => { A => { A => 1, B => 2 }, B => { A => 3, B => 4 } } },
	hist          => { data => { A => [ 1, 2, 2, 3 ], B => [ 2, 3, 3, 4 ] } },
	hist2d        => { data => { x => \@x, y => \@y } },
	imshow        => { data => [ [ 1, 2 ], [ 3, 4 ] ] },
	pie           => { data => { A => 1, B => 2 } },
	plot          => { data => { A => [ \@x, \@y ] } },
	scatter       => { data => { x => \@x, y => \@y } },
	violin        => { data => { A => [ 1, 2, 3, 5 ], B => [ 2, 3, 4, 9 ] } },
	violinplot    => { data => { A => [ 1, 2, 3, 5 ] } },
	wide          => { data => { A => [ [ [ 0, 1, 2 ], [ 1, 2, 3 ] ], [ [ 0, 1, 2 ], [ 2, 3, 4 ] ] ] } },
);

# ----------------------------------------------------------------------------
# 1. Every type ggplot2 draws writes a self-contained figure.
# ----------------------------------------------------------------------------
# Each figure checks for ggplot2 itself, opens its own device and closes it,
# inside local(), so that several can share one script (block 14).
foreach my $type ( sort keys %every_type ) {
	my $r = script_of( plot_type => $type, %{ $every_type{$type} } );
	like( $r, qr/^if \(!requireNamespace\("ggplot2", quietly = TRUE\) \|\| utils::packageVersion\("ggplot2"\) < "3\.5\.0"\) \{\n\tmessage\(.*\n\tquit\(status = 1\)\n\}\nlocal\(\{\n/m, "$type: ggplot2 is checked for, and the figure drawn inside local()" );
	like( $r, qr/\tgrDevices::svg\(.*\n(?:.*\n)*\tinvisible\(grDevices::dev\.off\(\)\)\n\}\)\n\z/, "$type: the device is opened and closed by the figure" );
}

# ----------------------------------------------------------------------------
# 2. Types and keywords ggplot2 has no counterpart for are refused by name.
# ----------------------------------------------------------------------------
like( refusal( plot_type => 'hexbin', data => { x => \@x, y => \@y } ), qr/the ggplot2 engine does not draw plot_type "hexbin"/, 'hexbin is refused by name' );
like( refusal( plot_type => 'venn_proportional_area', data => { A => [ 1, 2 ], B => [ 2, 3 ] } ), qr/does not draw plot_type "venn_proportional_area"/, 'venn_proportional_area is refused by name' );
like( refusal( plot_type => 'bar', data => { A => 1 }, linewidth => 2 ), qr/does not draw "linewidth" for plot_type "bar"/, 'a keyword of the type that ggplot2 does not read is refused, naming the type' );
like( refusal( plot_type => 'plot', data => { A => [ \@x, \@y ] }, set_options => 'marker = "o"' ), qr/"set_options" for plot_type "plot"/, 'set_options, which is Python, is refused' );
like( refusal( plot_type => 'plot', data => { A => [ \@x, \@y ] }, legend => 'loc = "upper left"' ), qr/"legend" for plot_type "plot"/, 'legend, which is matplotlib\'s arguments, is refused' );
like( refusal( plot_type => 'scatter', data => { x => \@x, y => \@y }, tooltips => [ ('t') x 6 ] ), qr/"tooltips"/, 'tooltips are refused' );
like( refusal( plot_type => 'plot', data => { A => [ \@x, \@y ] }, twinx => 'A' ), qr/"twinx"/, 'twinx is refused' );
like( refusal( plot_type => 'bar', data => { A => 1 }, show => 1, output_file => out_file() ), qr/"show"/, 'show is refused: Rscript cannot hold a window open' );
like( refusal( plots => [ { plot_type => 'bar', data => { A => 1 } }, { plot_type => 'bar', data => { B => 1 } } ], ncols => 2, sharey => 1 ), qr/"sharey" for the figure/, 'sharey is refused for the figure' );
like( refusal( plot_type => 'bar', data => { A => 1 }, title => q{f'{x}'} ), qr/"title" is a Python f-string/, 'an f-string title is refused' );
like( refusal( plot_type => 'bar', data => { A => 1 }, title => q{'Counts', fontsize = 20} ), qr/"title" is given matplotlib's arguments, fontsize = 20/, 'a title with matplotlib\'s keyword arguments is refused' );
like( refusal( plot_type => 'bar', data => { A => 1 }, color => 'xkcd:sky blue' ), qr/"color" is not a color the ggplot2 engine knows/, 'an xkcd color is refused' );
like( refusal( plot_type => 'imshow', data => [ [1] ], cmap => 'nipy_spectral' ), qr/"cmap" "nipy_spectral" is not a colormap the ggplot2 engine has/, 'a colormap it has no table for is refused' );
like( refusal( plot_type => 'bar', data => { A => 1 }, output_file => out_file('jpg') ), qr/writes \.svg, \.png and \.pdf files, so it cannot write ".*\.jpg"/, 'an output format it has no device for is refused' );
like( refusal( plot_type => 'bar', data => { A => 1 }, xerr => 1 ), qr/"xerr" would be an error bar across the bars of a bar/, 'xerr on a bar is refused, yerr being the one it draws' );
like( refusal( plot_type => 'bar', data => { A => [ 1, 2 ] }, yerr => 1 ), qr/draws error bars on a bar chart of one bar per key/, 'error bars on grouped bars are refused' );
like( refusal( plot_type => 'pie', data => { A => 1 }, add => [ { plot_type => 'plot', data => [ [ 0, 1 ], [ 0, 1 ] ] } ] ), qr/a pie has no axes to share/, 'a pie with an "add" graph is refused' );
like( refusal( plot_type => 'hist2d', data => { x => \@x, y => \@y }, add => [ { plot_type => 'imshow', data => [ [1] ] } ] ), qr/one color scale per plot/, 'two scales of value colors on one plot are refused' );
like( refusal( plot_type => 'boxplot', data => { A => [ 1, 2 ] }, logscale => ['x'] ), qr/the x axis of this boxplot holds its keys/, 'a log scale on the axis of the keys is refused' );
like( refusal( plot_type => 'violin', data => { A => [ 2, 2, 2 ] } ), qr/"A" has no spread/, 'a violin of one value, which has no density, is refused' );
like( refusal( plot_type => 'hist', data => [ 1, 2 ], bins => 'auto' ), qr/a numpy estimator such as "auto" is matplotlib's alone/, 'a bins estimator is refused' );
like( refusal( plot_type => 'pie', data => { A => 1 }, autopct => '%s and %d' ), qr/"autopct" is a format with one number in it/, 'an autopct that is not one number is refused' );
like( refusal( plot_type => 'plot', data => { A => [ \@x, \@y ] }, set_xlim => 'right = 3' ), qr/"set_xlim" is two finite numbers/, 'set_xlim in keyword form is refused' );

# ----------------------------------------------------------------------------
# 3. Each keyword declared is read, and reaches the script.
# ----------------------------------------------------------------------------
{
	my $r = script_of( plot_type => 'bar', data => { A => 1, B => 2 }, title => 'Two, three', xlabel => 'Key', set_ylabel => 'Value', color => 'tab:orange',
		edgecolor => 'black', width => 0.5, yerr => { A => 0.1, B => [ 0.2, 0.3 ] }, set_ylim => '0, 5', yscale => 'log' );
	like( $r, qr/labs\(title = "Two, three", x = "Key", y = "Value"\)/, 'bar: title and labels, in either form' );
	like( $r, qr/fill = c\("#ff7f0e", "#ff7f0e"\), colour = c\("#000000", "#000000"\)/, 'bar: color and edgecolor, as hex' );
	like( $r, qr/xmin = c\(-0\.25, 0\.75\), xmax = c\(0\.25, 1\.25\)/, 'bar: width' );
	like( $r, qr/geom_linerange\(data = data\.frame\(p = c\(0, 1\), lo = c\(0\.9, 1\.8\), hi = c\(1\.1, 2\.3\)/, 'bar: yerr, one number or a [ lower, upper ] pair per key' );
	like( $r, qr/coord_cartesian\(ylim = c\(0, 5\)\)/, 'bar: set_ylim' );
	like( $r, qr/scale_y_continuous\(transform = "log10"\)/, 'bar: yscale' );
	$r = script_of( plot_type => 'bar', data => { A => [ 1, 2 ], B => [ 3, 4 ] }, stacked => 'True', label => [ 'one', 'two' ], key_order => [ 'B', 'A' ], color => [ 'red', 'blue' ] );
	like( $r, qr/breaks = c\(0, 1\), labels = c\("B", "A"\)/, 'bar: key_order' );
	like( $r, qr/ymin = c\(0, 0, 3, 1\), ymax = c\(3, 1, 7, 3\)/, 'bar: stacked, each series on the last' );
	like( $r, qr/scale_fill_manual\(name = NULL, values = stats::setNames\(c\("#ff0000", "#0000ff"\), c\("one", "two"\)\)/, 'bar: label and color, per series, in the legend' );
	like( script_of( plot_type => 'barh', data => { A => 1 }, log => 'True' ), qr/scale_x_continuous\(transform = "log10"[,)]/, 'barh: log puts the value axis, x, on a log scale' );

	$r = script_of( plot_type => 'boxplot', data => { A => [ 1, 2, 3, 4 ], B => [ 1000, 2000 ] }, colors => { A => 'red', B => 'green' }, notch => 1, showcaps => 0, showfliers => 0, showmeans => 0, orientation => 'horizontal', logscale => ['x'] );
	like( $r, qr/fill = "#ff0000".*notch = TRUE, staplewidth = 0, outlier\.shape = NA.*orientation = "y"/, 'boxplot: colors, notch, showcaps, showfliers, orientation' );
	unlike( $r, qr/shape = 17/, 'boxplot: showmeans => 0 draws no mean' );
	like( $r, qr/labels = c\("A \(4\)", "B \(2\)"\)/, 'boxplot: each key is labelled with its count' );
	like( $r, qr/scale_x_continuous\(transform = "log10"\)/, 'boxplot: logscale, on the axis of values' );

	$r = script_of( plot_type => 'violin', data => { A => [ 1, 2, 3, 5 ] }, color => 'purple', edgecolor => 'red', medians => 0, whiskers => 0, key_order => ['A'] );
	like( $r, qr/fill = "#800080", colour = "#ff00004d"/, 'violin: color, and edgecolor at the bodies\' alpha' );
	is( () = $r =~ m/geom_segment/g, 1, 'violin: medians => 0 and whiskers => 0 leave only the extrema' );

	$r = script_of( plot_type => 'hist', data => { A => [ 1, 2, 3 ], B => [ 1, 1 ] }, bins => { A => 2, B => [ 0, 1, 2 ] }, alpha => 0.25, color => { A => 'red', B => 'blue' }, show_legend => 0, orientation => 'horizontal' );
	like( $r, qr/ymin = c\(1, 2, 0, 1\), ymax = c\(2, 3, 1, 2\), xmin = c\(0, 0, 0, 0\), xmax = c\(1, 2, 0, 2\)/, 'hist: bins per set, a count or edges, binned as numpy bins them; orientation' );
	like( $r, qr/fill = c\("#ff0000", "#ff0000", "#0000ff", "#0000ff"\), alpha = 0\.25/, 'hist: color per set, alpha, and no legend' );

	$r = script_of( plot_type => 'hist2d', data => { x => \@x, y => \@y }, xbins => 2, ybins => 3, cmap => 'viridis_r', cb_logscale => 1, cblabel => 'n', cmin => 1, xmin => 0, xmax => 8, density => 0, show_colorbar => 1 );
	like( $r, qr/xmin = c\(0, 0, 0, 4, 4, 4\)/, 'hist2d: xbins, xmin, xmax' );
	like( $r, qr/scale_fill_gradientn\(name = "n", colours = c\("#fde725".*transform = "log10", guide = ggplot2::guide_colourbar/, 'hist2d: cmap reversed, cblabel, cb_logscale' );
	like( script_of( plot_type => 'hist2d', data => { x => \@x, y => \@y }, colorbar_on => 0 ), qr/guide = "none"/, 'hist2d: colorbar_on => 0' );

	$r = script_of( plot_type => 'imshow', data => [ [ 1, 'nan' ], [ 3, 4 ] ], vmin => 0, cb_max => 10, cmap => 'gray' );
	like( $r, qr/v = c\(1, NaN, 3, 4\)/, 'imshow: a NaN cell is NaN, drawn empty' );
	like( $r, qr/limits = c\(0, 10\)/, 'imshow: vmin and cb_max' );
	$r = script_of( plot_type => 'imshow', data => [ [qw(H E)], [qw(E C)] ], stringmap => { H => 'helix', E => 'strand', C => 'coil' } );
	like( $r, qr/scale_fill_manual\(.*breaks = c\("C", "E", "H"\), labels = c\("coil", "strand", "helix"\)/, 'imshow: stringmap, in sorted order of the strings' );

	$r = script_of( plot_type => 'colored_table', data => { A => { B => 2 }, B => { A => 3 } }, mirror => 1, show_numbers => 1, undef_color => 'white', default_undefined => undef, row_labels => [ 'first', 'second' ], cb_min => 0, cb_max => 5 );
	like( $r, qr/labels = c\("first", "second"\)/, 'colored_table: row_labels' );
	like( $r, qr/na\.value = "#ffffff"/, 'colored_table: undef_color' );
	like( $r, qr/geom_text\(data = data\.frame\(x = c\(1, 2, 1, 2\), y = c\(1, 1, 2, 2\), t = c\("", "2", "3", ""\)/, 'colored_table: mirror fills only the empty cells; show_numbers' );

	$r = script_of( plot_type => 'pie', data => { A => 1, B => 3 }, autopct => '%1.1f%%', labeldistance => 1.2, pctdistance => 0.5, key_order => [ 'B', 'A' ] );
	like( $r, qr/t = c\("75\.0%", "25\.0%"\)/, 'pie: autopct, and key_order' );

	$r = script_of( plot_type => 'plot', data => { A => [ \@x, \@y ], B => [ 1, 2 ] }, show_legend => 0, logscale => ['y'], set_xscale => 'log', key_order => [ 'B', 'A' ] );
	like( $r, qr/data\.frame\(x = c\(0, 1\), y = c\(1, 2\).*data\.frame\(x = c\(1, 2/s, 'plot: key_order, and a set of y values alone drawn against 0 .. n-1' );
	unlike( $r, qr/scale_colour_manual/, 'plot: show_legend => 0' );
	like( $r, qr/scale_x_continuous\(transform = "log10"\).*scale_y_continuous\(transform = "log10"\)/s, 'plot: logscale and set_xscale' );

	$r = script_of( plot_type => 'scatter', data => { a => \@x, b => \@y, c => \@y }, keys => [ 'c', 'a' ], color_key => 'b', cmap => 'plasma', cb_min => 1, cb_max => 9, cblabel => 'B' );
	like( $r, qr/x = c\(2, 4, 3, 5, 7, 6\), y = c\(1, 2/, 'scatter: keys order x and y' );
	like( $r, qr/scale_colour_gradientn\(name = "B", colours = c\("#0d0887".*limits = c\(1, 9\)/, 'scatter: color_key, cmap, cb_min, cb_max, cblabel' );
	like( $r, qr/labs\(title = NULL, x = "c", y = "a"\)/, 'scatter: the axes are labelled with their keys' );
	$r = script_of( plot_type => 'scatter', data => { S => { x => \@x, y => \@y }, T => { x => 1, y => 2 } }, key_order => [ 'T', 'S' ], show_legend => 1 );
	like( $r, qr/breaks = c\("T", "S"\)/, 'scatter: sets in key_order, in the legend' );

	$r = script_of( plot_type => 'wide', data => { G => [ [ [ 0, 2 ], [ 0, 2 ] ], [ [ 0, 1 ], [ 1, 2 ] ] ] }, color => { G => 'red' }, show_legend => 0 );
	like( $r, qr/geom_polygon\(.*fill = "#ff0000"/, 'wide: color' );
	unlike( $r, qr/scale_colour_manual/, 'wide: show_legend => 0' );

	$r = script_of( plots => [ { plot_type => 'bar', data => { A => 1 } }, { plot_type => 'pie', data => { A => 1 } } ], ncols => 2, suptitle => 'All', scale => 2, scaley => 0.5 );
	like( $r, qr/grDevices::svg\(.*, width = 12\.8, height = 4\.8\)/, 'scale and scaley set the size, from matplotlib\'s 6.4 x 4.8 inches' );
	like( $r, qr/grid::grid\.text\("All".*\n\tprint\(p0, vp = grid::viewport\(layout\.pos\.row = 2, layout\.pos\.col = 1\)\)\n\tprint\(p1, vp = grid::viewport\(layout\.pos\.row = 2, layout\.pos\.col = 2\)\)/, 'suptitle above a grid of subplots' );
}

# ----------------------------------------------------------------------------
# 4. Text is escaped, and the script is pure ASCII.
# ----------------------------------------------------------------------------
# Rscript reads a script in the native encoding, which on Windows need not be
# UTF-8, so nothing outside ASCII is written as it is.
{
	my $r = script_of( plot_type => 'bar', data => { q{a"b} => 1, q{c\d} => 2, "e\nf" => 3, "ρ" => 4, "😀" => 5, q{it's} => 6 }, title => "τ\t1" );
	unlike( $r, qr/[^\x00-\x7f]/, 'the script is ASCII only' );
	like( $r, qr/labels = c\("a\\"b", "c\\\\d", "e\\nf", "it's", "\\u\{3c1\}", "\\U\{1f600\}"\)/, 'double quotes, backslashes, newlines and non-ASCII keys are escaped' );
	like( $r, qr/title = "\\u\{3c4\}\\t1"/, 'and so is the title' );
	like( script_of( plot_type => 'bar', data => { A => 1 }, title => q{"a, \u03c1"} ), qr/title = "a, \\u\{3c1\}"/, 'a Python string literal as a title is read as Python reads it' );
}

# ----------------------------------------------------------------------------
# 5. A Windows path, with an apostrophe and a percent sign, survives.
# ----------------------------------------------------------------------------
{
	my $path = q{C:\new\x's dir\100% out.svg};
	my ( undef, undef, $file ) = capture { plt( engine => 'ggplot2', execute => 0, plot_type => 'bar', data => { A => 1 }, output_file => $path ) };
	push @scripts, $file;
	like( slurp($file), qr/grDevices::svg\("C:\\\\new\\\\x's dir\\\\100%% out\.svg"/, 'the backslashes are escaped and the % doubled, which every R device reads as a format' );
}

# ----------------------------------------------------------------------------
# 6. Every data shape of every type is drawn.
# ----------------------------------------------------------------------------
{
	my @shapes = (
		[ 'bar, hash of arrays', plot_type => 'bar', data => { A => [ 1, 2 ], B => [ 3, 4 ] } ],
		[ 'bar, hash of hashes', plot_type => 'bar', data => { A => { x => 1, y => 2 }, B => { x => 3 } } ],
		[ 'barh, hash of hashes', plot_type => 'barh', data => { A => { x => 1, y => 2 }, B => { x => 3 } } ],
		[ 'boxplot, one array', plot_type => 'boxplot', data => [ 1, 2, 3, 'nan', undef ] ],
		[ 'violin, one array', plot_type => 'violin', data => [ 1, 2, 3, 7 ] ],
		[ 'hist, one array', plot_type => 'hist', data => [ 1, 2, 3, 'nan' ] ],
		[ 'plot, one [ x, y ] pair', plot_type => 'plot', data => [ \@x, \@y ] ],
		[ 'plot, an array of pairs', plot_type => 'plot', data => [ [ \@x, \@y ], [ \@y, \@x ] ] ],
		[ 'plot, a NaN and an infinity', plot_type => 'plot', data => { A => [ [ 1, 2, 3 ], [ 1, 'nan', 'inf' ] ] } ],
		[ 'scatter, three keys', plot_type => 'scatter', data => { x => \@x, y => \@y, z => \@x } ],
		[ 'scatter, sets colored by value', plot_type => 'scatter', data => { A => { x => \@x, y => \@y, z => \@x }, B => { x => \@y, y => \@x, z => \@y } } ],
		[ 'scatter, a set of one point each', plot_type => 'scatter', data => { A => { x => 1, y => 2 }, B => { x => 2, y => 1 } } ],
		[ 'wide, one unlabelled group', plot_type => 'wide', data => [ [ [ 0, 1 ], [ 1, 2 ] ], [ [ 1, 0 ], [ 2, 3 ] ] ] ],
		[ 'imshow, a 1 x 1 image', plot_type => 'imshow', data => [ [5] ] ],
		[ 'imshow, eleven categories', plot_type => 'imshow', data => [ [ 'a' .. 'k' ] ], stringmap => { map { $_ => uc } 'a' .. 'k' } ],
	);
	foreach my $shape (@shapes) {
		my ( $name, %args ) = @{$shape};
		my $r = eval { script_of(%args) };
		ok( defined $r && $r =~ m/ggplot2::ggplot\(\)/, "$name is drawn" ) or diag($@);
	}
}

# ----------------------------------------------------------------------------
# 7. "add" graphs share the axes, and matplotlib's color cycle.
# ----------------------------------------------------------------------------
{
	my $r = script_of( plot_type => 'violin', data => { A => [ 1, 2, 5 ] }, add => [ { plot_type => 'plot', data => [ [ 1, 2 ], [ 0, 1 ] ] } ] );
	like( $r, qr/geom_path\(.*colour = "#1f77b4".*geom_violin\(.*fill = "#ff7f0e"/s, 'the line takes C0 and is drawn first; the violin takes the next color, C1' );
}

# ----------------------------------------------------------------------------
# 8. The binning and the summaries are numpy's.
# ----------------------------------------------------------------------------
{
	is( Cn::Plot::Ggplot2::bin_index( [ 0, 1, 2 ], 2 ), 1, 'the last bin holds its right edge' );
	is( Cn::Plot::Ggplot2::bin_index( [ 0, 1, 2 ], 1 ), 1, 'every other bin holds its left edge alone' );
	ok( !defined Cn::Plot::Ggplot2::bin_index( [ 0, 1, 2 ], 2.5 ), 'a value outside the edges is in no bin' );
	is( Cn::Plot::Ggplot2::percentile( [ 1, 2, 3, 4 ], 0.25 ), 1.75, 'percentile is numpy\'s linear one' );
	my ( $base, $mean, $sd ) = Cn::Plot::Ggplot2::wide_summary( [ [ [ 0, 2 ], [ 0, 2 ] ], [ [ 1, 0 ], [ 2, 1 ] ] ] );
	is_deeply( [ @{$mean}[ 0, 50, 100 ] ], [ 0.5, 1.5, 2 ], 'wide: the runs are sorted by x, and a point only one run reaches is that run' );
	is( $sd->[0], 0.5, 'wide: the standard deviation is the population one' );
}

# ----------------------------------------------------------------------------
# 9. style => 'matplotlib' is the default, and its scripts are as they were.
# ----------------------------------------------------------------------------
# The native constructs are absent from every matplotlib-style script, and
# naming the style writes what leaving it out writes. The digests are of
# scripts the engine wrote before "style" was added in 0.4 (SHA-256, line 1 --
# the note naming where and by whom it was written -- left out). They pin the
# figures "native" must not disturb; overlay, logbar and wide are not among
# them, as their matplotlib style was fixed in the same change (block 13). To
# see the digests the engine writes now, run
#
#	CN_PLOT_PRINT_PINS=1 prove -Ilib t/18.ggplot2.t
use Digest::SHA 'sha256_hex';
my %native_only = (
	'geom_col'       => qr/geom_col\(/,
	'geom_histogram' => qr/geom_histogram\(/,
	'geom_bin_2d'    => qr/geom_bin_2d\(/,
	'hue'            => qr/hue_pal|scale_\w+_hue|scale_shape_discrete/,
	'gradient'       => qr/scale_\w+_gradient\(/,
	'stat_summary'   => qr/stat_summary\(/,
	'geom_errorbar'  => qr/geom_errorbar\(/,
);
my @pin_v = map { sin($_) * 3 + $_ / 10 } 1 .. 40;
my %pinned = (
	grouped => [ '702054ed51109ad8c85948142501e12d3e75cd16b73dcdda006c7524183b67ab', { plot_type => 'bar', data => { '2023' => { A => 3, B => 5 }, '2024' => { A => 4, B => 3 } }, title => 'g' } ],
	simple  => [ '9c703af457597a515eba21472d3c47e070bda25fa4bbccf18103974c0cb50da5', { plot_type => 'bar', data => { a => 1, b => 2 }, yerr => { a => 0.1, b => 0.2 } } ],
	boxplot => [ 'e1aa1678a3ba050b2e59e17c408c382ebe73a37d374db4cc71c2ddd213e68988', { plot_type => 'boxplot', data => { A => [@pin_v], B => [ map { $_ * 2 } @pin_v ] }, showmeans => 1 } ],
	violin  => [ '2d3625ca40d103bffd9fbf42261ca01bc1e8e2eebd32ed50b1374405755bb834', { plot_type => 'violin', data => { A => [@pin_v], B => [ map { $_ * 2 } @pin_v ] } } ],
	hist    => [ '42e6e261696eacfbac5f7a14d44a87fee4f7f77f39b4d930d4843e5c732c9a4f', { plot_type => 'hist', data => { A => [@pin_v], B => [ map { $_ + 1 } @pin_v ] }, bins => 7 } ],
	hist2d  => [ '7100485ffc0adede2f1683704c25415b0bea14017416b2015a357745eaa82038', { plot_type => 'hist2d', data => { x => [@pin_v], y => [ reverse @pin_v ] }, xbins => 5, ybins => 4 } ],
	scatter => [ '01d65bb949f875b9539ffc9193ddf50e821bf4fd6d2702ffac4c854145ec61e3', { plot_type => 'scatter', data => { x => [ 1 .. 5 ], y => [ 2, 4, 1, 3, 5 ], z => [ 5, 4, 3, 2, 1 ] } } ],
	sets    => [ 'c714ad1bc36799cffae5c17060e3d4e621e30bad2b8f520fce9f92cc77c98713', { plot_type => 'scatter', data => { P => { x => [ 1, 2 ], y => [ 3, 4 ] }, Q => { x => [ 2, 3 ], y => [ 1, 2 ] } } } ],
	table   => [ '1b49dd5ef9d4d5102ef374065835a067909802dc80412581c0f5f559cf48793c', { plot_type => 'colored_table', data => { H => { H => 1, C => 2 }, C => { C => 3 } }, mirror => 1, show_numbers => 1 } ],
	pie     => [ '3da0cba46d91efaeef5da16eef8939bc9913b0dff2026cd4f1621b0222c7a87a', { plot_type => 'pie', data => { a => 1, b => 2, c => 3 }, autopct => '%1.1f%%' } ],
	imshow  => [ '872563916ae435d00ead733a2579e1591ca4cabcdc96b2cd4a9a774a42c87bc4', { plot_type => 'imshow', data => [ [ 1, 2 ], [ 3, 4 ] ], cmap => 'viridis' } ],
	plot    => [ 'ddde7e170241b716a3f8d1392a8d4822a61874bf51eb73038577a7e87115f8c4', { plot_type => 'plot', data => { s => [ [ 1, 2, 3 ], [ 1, 4, 9 ] ], t => [ 3, 2, 1 ] } } ],
);
sub pinned_script {
	# The script of a pinned figure, as the digests were taken: written to
	# "x.svg", with its first line left out.
	my ( $args, @style ) = @_;
	my ( undef, undef, $file ) = capture { plt( %{$args}, engine => 'ggplot2', execute => 0, output_file => 'x.svg', @style ) };
	push @scripts, $file;
	return slurp($file) =~ s/\A[^\n]*\n//r;
}
{
	foreach my $name ( sort keys %pinned ) {
		my ( $digest, $args ) = @{ $pinned{$name} };
		my $script = pinned_script($args);
		diag("$name => '" . sha256_hex($script) . "'") if $ENV{CN_PLOT_PRINT_PINS};
		is( sha256_hex($script), $digest, "$name: the matplotlib-style script is the one written before \"style\" was added" );
		is( pinned_script( $args, style => 'matplotlib' ), $script, "$name: style => 'matplotlib' writes what no style writes" );
	}
	foreach my $type ( sort keys %every_type ) {
		my $r = script_of( plot_type => $type, %{ $every_type{$type} }, style => 'matplotlib' );
		my @found = grep { $r =~ $native_only{$_} } sort keys %native_only;
		is_deeply( \@found, [], "$type: the matplotlib style uses nothing of the native style's" );
	}
}

# ----------------------------------------------------------------------------
# 10. style => 'native' draws with ggplot2's own stats, scales and theme.
# ----------------------------------------------------------------------------
{
	my %native = map { $_ => script_of( plot_type => $_, %{ $every_type{$_} }, style => 'native' ) } sort keys %every_type;
	unlike( $native{$_}, qr/theme_bw|#1f77b4/, "$_: native has neither the matplotlib style's theme nor its C0" ) foreach sort keys %native;
	like( $native{bar}, qr/geom_col\(data = data\.frame\(k = factor\(c\("A", "B"\), levels = c\("A", "B"\)\)/, 'bar: geom_col, on a discrete axis of the keys in their order' );
	unlike( $native{bar}, qr/fill = /, 'bar: in ggplot2\'s own fill' );
	like( $native{barh}, qr/geom_col\(.*aes\(x = v, y = k\), orientation = "y"/, 'barh: the keys on the y axis' );
	like( $native{boxplot}, qr/geom_boxplot\(data = .*aes\(x = k, y = v\), na\.rm = TRUE\)/, 'boxplot: stat_boxplot, with its defaults' );
	unlike( $native{boxplot}, qr/staplewidth|stat_summary/, 'boxplot: no caps and no mean, as ggplot2 draws none' );
	like( $native{violin}, qr/geom_violin\(data = .*aes\(x = k, y = v\), na\.rm = TRUE\)/, 'violin: stat_ydensity, with its own bandwidth' );
	unlike( $native{violin}, qr/\bbw = |geom_segment|stat_summary/, 'violin: no bandwidth of Scott\'s, and no medians or whiskers unless asked for' );
	like( $native{hist}, qr/geom_histogram\(data = .*aes\(x = v, fill = s\), bins = 10, position = "identity", alpha = 0\.5/, 'hist: stat_bin over every set at once, 10 bins, overlaid' );
	like( $native{hist}, qr/scale_fill_hue\(name = NULL, limits = c\("A", "B"\)/, 'hist: the sets in ggplot2\'s hue scale' );
	like( $native{hist2d}, qr/geom_bin_2d\(.*fill = ggplot2::after_stat\(count\)\), bins = c\(15, 15\)/, 'hist2d: stat_bin_2d, xbins by ybins' );
	like( $native{hist2d}, qr/scale_fill_gradient\(na\.value = NA\)/, 'hist2d: ggplot2\'s own gradient and title' );
	like( $native{scatter}, qr/geom_point\(data = .*aes\(x = x, y = y\), na\.rm = TRUE\)/, 'scatter: ggplot2\'s own point, color and size' );
	like( $native{plot}, qr/scale_colour_hue\(name = NULL, limits = c\("A"\)/, 'plot: the lines in the hue scale' );
	like( $native{pie}, qr/fill = scales::hue_pal\(\)\(2\)\[c\(1, 1/, 'pie: the wedges in the hue scale' );
	like( $native{pie}, qr/theme_void\(\)/, 'pie: on theme_void, as a ggplot2 pie is' );
	like( $native{imshow}, qr/scale_fill_gradient\(\)/, 'imshow: ggplot2\'s own gradient' );
	unlike( $native{imshow}, qr/expand = c\(0, 0\)/, 'imshow: padded, as ggplot2 pads a raster' );
	unlike( $native{colored_table}, qr/colour = "#000000"|position = "top"/, 'colored_table: without matplotlib\'s table borders and column labels on top' );
	like( $native{wide}, qr/geom_polygon\(.*fill = s\).*scale_fill_hue\(.*guide = "none"\)/s, 'wide: the band in the hue of its group, with one legend, of the lines' );
	my $three = script_of( plot_type => 'scatter', data => { x => \@x, y => \@y, z => \@y }, style => 'native' );
	like( $three, qr/scale_colour_gradient\(name = "z"\)/, 'scatter by value: ggplot2\'s gradient, titled by the color key' );
}

# ----------------------------------------------------------------------------
# 11. A color or colormap given is drawn under "native" too.
# ----------------------------------------------------------------------------
{
	my $r = script_of( plot_type => 'bar', data => { A => 1, B => 2 }, color => { A => 'red', B => 'tab:blue' }, style => 'native' );
	like( $r, qr/geom_col\(.*fill = c\("#ff0000", "#1f77b4"\)/, 'bar: each bar in the color given' );
	$r = script_of( plot_type => 'hist', data => { A => [ 1, 2 ], B => [ 2, 3 ] }, color => { A => 'red' }, style => 'native' );
	like( $r, qr/scale_fill_manual\(name = NULL, values = replace\(stats::setNames\(scales::hue_pal\(\)\(2\), c\("A", "B"\)\), c\(1\), c\("#ff0000"\)\)/, 'hist: a set given a color keeps it, and the rest take the hue' );
	$r = script_of( plot_type => 'scatter', data => { x => \@x, y => \@y, z => \@y }, cmap => 'viridis', style => 'native' );
	like( $r, qr/scale_colour_gradientn\(name = "z", colours = c\("#440154"/, 'scatter: the colormap given' );
	$r = script_of( plot_type => 'boxplot', data => { A => [ 1, 2, 3 ], B => [ 2, 3, 4 ] }, colors => { A => 'red', B => 'green' }, style => 'native' );
	like( $r, qr/geom_boxplot\(.*fill = c\("#ff0000", "#008000"\)/, 'boxplot: each box in the color given' );
	$r = script_of( plot_type => 'colored_table', data => { A => { A => 1, B => 2 } }, undef_color => 'black', style => 'native' );
	like( $r, qr/na\.value = "#000000"/, 'colored_table: "undef_color" is the color of a missing cell' );
}

# ----------------------------------------------------------------------------
# 12. The keywords of each type reach ggplot2's own stats under "native".
# ----------------------------------------------------------------------------
{
	my %box = ( plot_type => 'boxplot', data => { A => [ 1, 2, 3, 9 ] }, style => 'native' );
	like( script_of( %box, notch => 'True', showcaps => 'False', showfliers => 'False', showmeans => 1 ), qr/notch = TRUE, staplewidth = 0, outlier\.shape = NA.*stat_summary\(.*fun = mean/s, 'boxplot: notch, showcaps, showfliers and showmeans' );
	like( script_of( %box, showcaps => 1 ), qr/staplewidth = 0\.5/, 'boxplot: showcaps draws caps' );
	my %vio = ( plot_type => 'violin', data => { A => [ 1, 2, 3, 9 ] }, style => 'native' );
	like( script_of( %vio, medians => 1, whiskers => 1, edgecolor => 'red' ), qr/geom_violin\(.*colour = "#ff0000".*geom_boxplot\(.*width = 0\.1.*stat_summary\(.*fun = stats::median/s, 'violin: whiskers as a narrow box, medians as a line, edgecolor' );
	my %h2 = ( plot_type => 'hist2d', data => { x => \@x, y => \@y }, style => 'native' );
	like( script_of( %h2, density => 1, cmin => 2, cmax => 9 ), qr/after_stat\(ifelse\(density < 2 \| density > 9, NA, density\)\)/, 'hist2d: density, cmin and cmax' );
	like( script_of( %h2, xmin => 0, xbins => 4 ), qr/breaks = list\(x = seq\(0, 6, length\.out = 5\)\)/, 'hist2d: a range given is the bins\' breaks' );
	like( script_of( %h2, logscale => ['x'], xmin => 1, xmax => 100, xbins => 2 ), qr/x = seq\(0, 2, length\.out = 3\)/, 'hist2d: on a log axis, the breaks are in log units' );
	my %hi = ( plot_type => 'hist', data => { A => [ 1, 2, 3 ] }, style => 'native' );
	like( script_of( %hi, bins => [ 0, 2, 4 ] ), qr/breaks = c\(0, 2, 4\)/, 'hist: bin edges are its breaks' );
	like( script_of( %hi, bins => 4, orientation => 'horizontal' ), qr/aes\(y = v\), bins = 4, position = "identity", orientation = "y"/, 'hist: a count of bins, and the horizontal orientation' );
	unlike( script_of(%hi), qr/alpha|fill/, 'hist: one set alone is ggplot2\'s own grey, opaque' );
	like( script_of( plot_type => 'hist', data => { A => [ 1, 2 ], B => [ 3, 4 ] }, bins => { A => 2, B => 3 }, style => 'native' ), qr/bins = 2,.*bins = 3,/s, 'hist: bins by set are a layer per set' );
	my $r = script_of( plot_type => 'bar', data => { A => 1, B => 2 }, yerr => [ 0.1, 0.2 ], width => 0.5, edgecolor => 'k', log => 1, style => 'native' );
	like( $r, qr/width = 0\.5, colour = c\("#000000", "#000000"\).*geom_errorbar\(.*width = 0\.25/s, 'bar: width, edgecolor and yerr' );
	like( $r, qr/scale_y_continuous\(transform = "log10"\)/, 'bar: log' );
	$r = script_of( plot_type => 'bar', data => { A => [ 1, 2 ], B => [ 3, 4 ] }, style => 'native' );
	like( $r, qr/position = "dodge".*scale_fill_hue\(.*guide = "none"\)/s, 'bar: series with no name are dodged, and told apart by color without a legend' );
	like( script_of( plot_type => 'bar', data => { A => { x => 1 }, B => { x => 2 } }, stacked => 1, style => 'native' ), qr/position = "stack"/, 'bar: stacked' );
	like( script_of( plot_type => 'imshow', data => [ [ 'a', 'b' ] ], stringmap => { a => 'A', b => 'B' }, style => 'native' ), qr/scale_fill_hue\(name = NULL, limits = c\("a", "b"\), breaks = c\("a", "b"\), labels = c\("A", "B"\)/, 'imshow: a stringmap\'s categories in the hue scale' );
}

# ----------------------------------------------------------------------------
# 13. What only "native" refuses, and the three matplotlib-style fixes.
# ----------------------------------------------------------------------------
{
	my %bar_and_line = ( plot_type => 'bar', data => { A => 1, B => 2 }, add => [ { plot_type => 'plot', data => [ [ 0, 1 ], [ 1, 2 ] ] } ] );
	like( refusal( %bar_and_line, style => 'native' ), qr/in style "native" the ggplot2 engine puts the keys of a bar, boxplot or violin on a discrete axis, so the bar cannot share the x axis with the plot/, 'native: a bar cannot share its discrete axis with a line' );
	ok( eval { script_of(%bar_and_line); 1 }, 'matplotlib style: it can, every position being a number' );    # not refusal(): $@ after capture() can be an earlier call's
	like( refusal( plot_type => 'bar', data => { A => 1 }, style => 'ggplot' ), qr/"style" is one of/, 'a style that is not one is refused by plt' );
	# matplotlib keeps a cycle of lines and one of patches per axes, so a
	# scatter over a line starts at C0 as the line does
	my $r = script_of( plot_type => 'scatter', data => { x => [ 1, 2 ], y => [ 2, 1 ] }, add => [ { plot_type => 'plot', data => { fit => [ [ 0, 2 ], [ 0, 2 ] ] } } ] );
	like( $r, qr/geom_point\(.*colour = "#1f77b4"/, 'an overlay: the scatter takes C0, as the line does' );
	# a bar on a log axis stands on the bottom edge, 5% of the decades below
	# the lowest top, as in matplotlib
	$r = script_of( plot_type => 'bar', data => { a => 1, b => 10, c => 1000 }, log => 1 );
	like( $r, qr/ymin = c\(0\.70794578438\d*, 0\.70794578438\d*, 0\.70794578438\d*\)/, 'a log bar: every bar stands at 10 ** -0.15, below the lowest top of 1' );
	like( $r, qr/scale_y_continuous\(transform = "log10", expand = ggplot2::expansion\(mult = c\(0, 0\.05\)\)\)/, 'a log bar: with no margin below it' );
	$r = script_of( plot_type => 'wide', data => { A => [ [ [ 0, 1, 2 ], [ 1, 2, 3 ] ], [ [ 0, 1, 2 ], [ 2, 3, 4 ] ] ] } );
	like( $r, qr/geom_polygon\(/, 'wide: the band is a polygon' );
	unlike( $r, qr/geom_ribbon/, 'wide: not a ribbon, whose seams streaked a PNG' );
}

# ----------------------------------------------------------------------------
# 14. Several figures through one "fh" are each drawn.
# ----------------------------------------------------------------------------
my $fh = File::Temp->new( DIR => $TMP, SUFFIX => '.R', UNLINK => 0 );
my @shared = ( out_file(), out_file() );
my $shared_script;
{
	capture { plt( engine => 'ggplot2', fh => $fh, execute => 0, plot_type => 'bar', data => { A => 1 }, output_file => $shared[0] ) };
	$fh->flush;
	my $r = slurp( $fh->filename );
	is( () = $r =~ m/^local\(\{$/mg, 1, 'the first figure is written' );
	$shared_script = $fh->filename;
}

# ----------------------------------------------------------------------------
# 15. R parses every script written above.
# ----------------------------------------------------------------------------
my @R = ( Cn::Plot::program_from_env('CN_PLOT_RSCRIPT') // 'Rscript' );
my ( $r_out, undef, $r_status ) = capture {
	no warnings 'exec';
	# single quotes only: see CLAUDE.md on list-form system on Win32
	system( @R, '-e', q{cat(R.version$major, R.version$minor, if (requireNamespace('ggplot2', quietly = TRUE)) as.character(utils::packageVersion('ggplot2')) else 'none')} );
};
my $r_available = ( $r_status == 0 && $r_out =~ m/^\d+ \S+ (\S+)/ ) ? 1 : 0;
my $gg_version = $r_available ? ( $r_out =~ m/ (\S+)$/ )[0] : 'none';
my $gg_available = 0;
if ( $gg_version =~ m/^(\d+)\.(\d+)/ ) {
	my ( $want_major, $want_minor ) = $Cn::Plot::Ggplot2::min_ggplot2 =~ m/^(\d+)\.(\d+)/;
	$gg_available = ( $1 > $want_major || ( $1 == $want_major && $2 >= $want_minor ) ) ? 1 : 0;
}
diag( $r_available ? "Rscript found, ggplot2 $gg_version (render checks " . ( $gg_available ? 'ON' : 'OFF' ) . ')' : 'no Rscript (parse and render checks skipped)' );
SKIP: {
	skip( 'no Rscript', 1 ) unless $r_available;
	my $checker = File::Spec->catfile( $TMP, 'parse.R' );
	open my $o, '>', $checker or die "can't write $checker: $!";
	print {$o} "bad <- character(0)\nfor (f in commandArgs(trailingOnly = TRUE)) if (inherits(try(parse(f), silent = TRUE), 'try-error')) bad <- c(bad, f)\ncat(length(bad), bad, sep = '\\n')\n";
	close $o or die "can't close $checker: $!";
	my ( $out, $err ) = capture { system( @R, $checker, @scripts ) };
	is( ( split /\n/, $out )[0], '0', 'R parses all ' . scalar(@scripts) . ' scripts' ) or diag("$out$err");
}

# ----------------------------------------------------------------------------
# 16. Rendered: every type, and both figures of the shared script.
# ----------------------------------------------------------------------------
# Well-formed XML, checked by balancing the tags, since no XML parser is a
# prerequisite; svg() writes text as glyph paths, so the labels are not in it
# to look for.
sub well_formed {
	my ($xml) = @_;
	$xml =~ s/<\?.*?\?>|<!--.*?-->|<!\[CDATA\[.*?\]\]>//gs;
	my @open;
	while ( $xml =~ m{<(/?)([A-Za-z_][\w:.-]*)[^>]*?(/?)>}g ) {
		my ( $close, $name, $empty ) = ( $1, $2, $3 );
		next if $empty;
		if ($close) {
			return 0 unless @open && pop(@open) eq $name;
		} else {
			push @open, $name;
		}
	}
	return @open ? 0 : 1;
}
SKIP: {
	skip( "no ggplot2 >= $Cn::Plot::Ggplot2::min_ggplot2", 2 * scalar( keys %every_type ) + 3 ) unless $gg_available;
	foreach my $type ( sort keys %every_type ) {
		my $file = out_file();
		my ( $out, $err, $ok ) = capture { eval { plt( engine => 'ggplot2', plot_type => $type, %{ $every_type{$type} }, output_file => $file ); 1 } };
		ok( $ok && -s $file, "$type: the SVG is written" ) or diag("$@$err");
		ok( -s $file && well_formed( slurp($file) ), "$type: and is well-formed" );
	}
	capture { plt( engine => 'ggplot2', fh => $fh, plot_type => 'pie', data => { A => 1 }, output_file => $shared[1] ) };
	is( () = slurp($shared_script) =~ m/^local\(\{$/mg, 2, 'the second figure is added to the shared script' );
	ok( -s $shared[0], 'the first figure, written with execute => 0, is drawn when the script runs' );
	ok( -s $shared[1], 'and so is the second' );
}

# ----------------------------------------------------------------------------
# 17. Rendered in style "native": every type.
# ----------------------------------------------------------------------------
SKIP: {
	skip( "no ggplot2 >= $Cn::Plot::Ggplot2::min_ggplot2", 2 * scalar( keys %every_type ) ) unless $gg_available;
	foreach my $type ( sort keys %every_type ) {
		my $file = out_file();
		my ( $out, $err, $ok ) = capture { eval { plt( engine => 'ggplot2', style => 'native', plot_type => $type, %{ $every_type{$type} }, output_file => $file ); 1 } };
		ok( $ok && -s $file, "$type, native: the SVG is written" ) or diag("$@$err");
		ok( -s $file && well_formed( slurp($file) ), "$type, native: and is well-formed" );
	}
}

# ----------------------------------------------------------------------------
# 18. An Rscript that is not there is reported as failing to start.
# ----------------------------------------------------------------------------
{
	local $ENV{CN_PLOT_RSCRIPT} = File::Spec->catfile( $TMP, 'no such Rscript' );
	my ( undef, undef ) = capture { eval { plt( engine => 'ggplot2', plot_type => 'bar', data => { A => 1 }, output_file => out_file() ) } };
	like( "$@", qr/no such Rscript\S* .* failed to start/, 'a missing interpreter named by CN_PLOT_RSCRIPT is reported as failing to start' );
}
done_testing();
