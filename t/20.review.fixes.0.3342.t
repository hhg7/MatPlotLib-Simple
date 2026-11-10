#!/usr/bin/env perl
#
# The fixes of 0.3343, one block each, in the form of t/14.review.fixes.0.32.t.
#
# They came out of an outside review of 0.3342 as it stood on 2026-11-09, and
# each was reproduced against the module before it was fixed. Blocks that also
# check behaviour the fix had to keep -- a PNG still carrying its Creator note,
# the methods beside a refused attribute still written, a flat "add" still
# drawn -- say so where they do it.
#
# Most of this is execute => 0 and reads the generated script as text, so it
# runs everywhere, including a Windows smoker with no python. Block 3 runs a
# stand-in interpreter, which is this perl, so it needs no python either.
# parses_ok needs python3, and the blocks that draw need python3 and matplotlib
# >= 3.10, and each skips without them. The gnuplot and ggplot2 checks read
# what those engines refuse and write, and run neither program.
#
require 5.010;
use strict;
use warnings FATAL => 'all';
use File::Temp 'tempdir';
use File::Spec;
use Capture::Tiny 'capture';
use Matplotlib::Simple;
# The interpreter the module itself runs; see t/07.review.fixes.t.
my @PY = Matplotlib::Simple::Matplotlib::python_command();
my $PY = join ' ', @PY;
use Test::More;

my $TMP = tempdir( CLEANUP => 1 );
my $seq = 0;

my $python_raw = ( scalar @PY ? do { no warnings 'exec'; qx/$PY --version 2>&1/ } // '' : '' );    # 'exec': see t/16.creator.t
my $python_available = ( $? == 0 && $python_raw =~ m/Python\s+3\.\d+/i ) ? 1 : 0;
my $mpl_available = 0;
if ($python_available) {
	# 3.10 is the floor t/01 and t/03 gate on. The generated figure passes
	# layout = "constrained", which matplotlib refuses before 3.5, so an older
	# one must skip these checks, not fail them.
	my $raw = qx/$PY -c "import matplotlib; print(matplotlib.__version__)" 2>&1/;
	if ( $? == 0 && $raw =~ m/^\s*(\d+)\.(\d+)/ ) {
		$mpl_available = ( $1 > 3 || ( $1 == 3 && $2 >= 10 ) ) ? 1 : 0;
	}
}
diag( $python_available ? "Python 3 found as \"$PY\" (parser gate ON)" : 'no Python 3 (parser gate skipped)' );
diag( $mpl_available ? 'matplotlib >= 3.10 found (render checks ON)' : 'no matplotlib >= 3.10 (render checks skipped)' );

my $PARSE = q{import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read())};

sub out_file {
	my ($ext) = @_;
	$ext = '.svg' if not defined $ext;
	return File::Spec->catfile( $TMP, 'gen' . $seq++ . $ext );
}

sub slurp {
	my ($file) = @_;
	open my $in, '<:encoding(UTF-8)', $file or die "can't read $file: $!";
	local $/;
	my $text = <$in>;
	close $in;
	return $text;
}

# Build one figure with execute => 0 and return the generated script as text.
# "output_file" is made here unless the caller names one, as block 1 does to
# choose the extension.
sub gen {
	my (%spec) = @_;
	$spec{output_file} = out_file() if not defined $spec{output_file};
	$spec{execute} = 0;
	my ( $out, $err, $file ) = capture { plt( \%spec ) };
	return ( slurp($file), $file );
}

# Only the message, never the Devel::Confess trace that follows it, is matched:
# the trace prints the arguments of every frame, so the name of a keyword or a
# key is in "$@" whether or not the message says it. Block 7 is about exactly
# that.
sub message_of {
	my ($spec) = @_;
	my ( $out, $err, $file ) = capture { eval { gen( %{$spec} ) } };
	my $message = "$@";
	$message =~ s/\n\t.*\z//s;
	return $message;
}

sub dies_with {
	my ( $spec, $like, $name ) = @_;
	my $message = message_of($spec);
	return ok( 0, "$name (did not die)" ) unless length $message;
	if ( !like( $message, $like, $name ) ) {
		diag("  died: $message");
	}
	return;
}

# The result is taken inside the capture block: "$@" read after capture()
# returns can still hold an earlier test's error.
sub lives {
	my ( $spec, $name ) = @_;
	my ( @r, $died );
	capture { $died = eval { @r = gen( %{$spec} ); 1 } ? '' : "$@" };
	$died =~ s/\n\t.*\z//s;
	ok( !length $died, $name ) or diag("  died: $died");
	return @r;
}

sub parses_ok {
	my ( $pyfile, $name ) = @_;
	SKIP: {
		skip( 'no Python 3 interpreter found', 1 ) unless $python_available;
		my ( $out, $err, $status ) = capture {
			system( @PY, '-c', $PARSE, $pyfile );
		};
		ok( $status == 0, $name ) or diag( '  ' . ( $err . $out ) );
	}
	return;
}

# Run a generated script with $tail appended, returning what it printed and
# its exit status. The caller has already skipped unless matplotlib is present.
sub run_py {
	my ( $pyfile, $tail ) = @_;
	my $script = File::Spec->catfile( $TMP, 'run' . $seq++ . '.py' );
	open my $o, '>:encoding(UTF-8)', $script or die "can't write $script: $!";
	print {$o} slurp($pyfile), "\n", $tail, "\n";
	close $o or die "can't close $script: $!";
	local $ENV{MPLBACKEND} = 'Agg';
	my ( $out, $err, $status ) = capture { system( @PY, $script ) };
	diag("  python: $err") if $status != 0;
	return ( $out, $status );
}

my %bars = ( A => 1, B => 2 );

# ----------------------------------------------------------------------------
# 1. The Creator note was handed to savefig for every format, and matplotlib
#    refuses it for those that keep no metadata, so no .jpg, .tif, .webp, .gif
#    or .pgf could be written: "metadata not supported for format 'jpeg'".
# ----------------------------------------------------------------------------
{
	my $takes = \&Matplotlib::Simple::Matplotlib::savefig_takes_metadata;
	foreach my $name ( 'a.png', 'a.PNG', 'a.pdf', 'a.svg', 'a.svgz', 'a.SVGZ', 'a.eps', 'a.ps', 'noext', 'a.',
	 '.hidden', 'dir.jpg/noext', 'dir.jpg\\noext', File::Spec->catfile( 'some.dir', 'fig.v2.png' ) ) {
		is( $takes->($name), 1, "savefig_takes_metadata: \"$name\" keeps the note" );
	}
	foreach my $name ( 'a.jpg', 'a.JPG', 'a.jpeg', 'a.tif', 'a.tiff', 'a.webp', 'a.gif', 'a.pgf', 'a.avif', 'a.raw',
	 'a.rgba', 'a.png.jpg', '.hidden.jpg', 'C:\\figs.png\\a.tif', File::Spec->catfile( 'some.png', 'fig.gif' ) ) {
		is( $takes->($name), 0, "savefig_takes_metadata: \"$name\" is saved without one" );
	}
	foreach my $ext ( '.jpg', '.jpeg', '.JPG', '.tif', '.tiff', '.webp', '.gif', '.pgf' ) {
		my ( $py, $file ) = gen( plot_type => 'bar', data => \%bars, output_file => out_file($ext) );
		like( $py, qr/^plt\.savefig\(output_file, bbox_inches = 'tight'\)/m, "$ext: savefig is given no metadata" );
		unlike( $py, qr/metadata\s*=/, "$ext: and none anywhere else in the script" );
		parses_ok( $file, "$ext: the script parses" );
	}
	# kept: the formats that hold a note still get it, as does a name with no
	# extension, which matplotlib saves as a PNG
	foreach my $ext ( '.png', '.PNG', '.pdf', '.svg', '.svgz', '.eps', '.ps', '' ) {
		my ($py) = gen( plot_type => 'bar', data => \%bars, output_file => out_file($ext) );
		like( $py, qr/^plt\.savefig\(output_file, bbox_inches = 'tight', metadata=\{'Creator': /m, '"' . $ext . '": savefig still carries the Creator note' );
	}
	# kept: in a figure of subplots too, which is written by the same lines
	my ($grid) = gen( plots => [ { plot_type => 'bar', data => \%bars }, { plot_type => 'pie', data => \%bars } ], ncols => 2, output_file => out_file('.tif') );
	like( $grid, qr/^plt\.savefig\(output_file, bbox_inches = 'tight'\)/m, 'subplots: a .tif is saved without metadata as well' );
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 4 ) unless $mpl_available;
		local $ENV{MPLBACKEND} = 'Agg';
		# .jpg and .tif are written by Pillow, which matplotlib requires; the
		# other formats depend on what that Pillow was built with.
		foreach my $ext ( '.jpg', '.tif' ) {
			my $image = out_file($ext);
			my $died;
			capture { $died = eval { plt( plot_type => 'bar', data => \%bars, output_file => $image ); 1 } ? '' : "$@" };
			$died =~ s/\n\t.*\z//s;
			ok( !length $died, "$ext: the figure is drawn" ) or diag("  died: $died");
			ok( ( -s $image ) ? 1 : 0, "$ext: and the file is written" );
		}
	}
}

# ----------------------------------------------------------------------------
# 2. The keyword lists held attributes, modules and constants beside the
#    methods, and each is written as a call: "dpi => 300" was fig.dpi(300),
#    "TypeError: 'float' object is not callable".
# ----------------------------------------------------------------------------
{
	my %listed = (
		ax  => { map { $_ => 1 } @Matplotlib::Simple::ax_methods },
		fig => { map { $_ => 1 } @Matplotlib::Simple::fig_methods },
		plt => { map { $_ => 1 } @Matplotlib::Simple::plt_methods },
	);
	my %gone = (
		ax => [ qw(axison callbacks child_axes collections containers dataLim fmt_xdata fmt_ydata
		 ignore_existing_data_limits legend_ name spines tables titleOffsetTrans transAxes transData
		 transLimits transScale use_sticky_edges viewLim xaxis yaxis) ],
		fig => [ qw(artists bbox bbox_inches canvas clipbox dpi dpi_scale_trans figbbox frameon images
		 lines mouseover number patch patches stale sticky_edges subfigs subplotpars suppressComposite
		 texts transFigure transSubfigure zorder) ],
		plt => [ qw(TYPE_CHECKING annotations backend_registry cbook cm color_sequences functools
		 importlib inspect logging matplotlib mlab np rcParams rcParamsDefault rcParamsOrig rcsetup sys
		 threading time) ],
	);
	foreach my $object ( sort keys %gone ) {
		my @still = grep { $listed{$object}{$_} } @{ $gone{$object} };
		is( scalar @still, 0, "no attribute or module is left among the $object methods" ) or diag("  still listed: @still");
	}
	# one of each list, as a single plot and inside a subplot
	foreach my $keyword ( [ dpi => 300 ], [ zorder => 2 ], [ spines => '"top"' ], [ xaxis => 1 ], [ rcParams => '"font.size"' ], [ np => 1 ] ) {
		my ( $name, $value ) = @{$keyword};
		dies_with( { plot_type => 'bar', data => \%bars, $name => $value }, qr/^"\Q$name\E" isn't defined/, "\"$name\" is refused in a single plot" );
		dies_with( { plots => [ { plot_type => 'bar', data => \%bars, $name => $value } ] }, qr/"\Q$name\E" isn't defined/, "\"$name\" is refused in a subplot" );
	}
	dies_with( { plot_type => 'bar', data => \%bars, dpi => 300 }, qr/perhaps you meant.*\bset_dpi\b/s, '"dpi" is answered with "set_dpi"' );
	# kept: the methods beside them are still keywords, and still written
	my ( $py, $file ) = lives( { plot_type => 'bar', data => \%bars, set_dpi => 50, set_facecolor => '"0.9"', set_axisbelow => 'True', grid => 'True' }, 'set_dpi, set_facecolor, set_axisbelow and grid are still accepted' );
	like( $py, qr/^fig\.set_dpi\(50\)/m,          'set_dpi is written as a figure method' );
	like( $py, qr/^fig\.set_facecolor\("0\.9"\)/m, 'set_facecolor is written as a figure method' );
	like( $py, qr/^ax0\.set_axisbelow\(True\)/m,   'set_axisbelow is written as an axes method' );
	like( $py, qr/^plt\.grid\(True\)/m,            'grid is written as a pyplot function' );
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 1 ) unless $mpl_available;
		my ( $out, $status ) = run_py( $file, '' );
		is( $status, 0, 'and the script that holds them runs' );
	}
}

# ----------------------------------------------------------------------------
# 3. What a script wrote to STDERR was shown only when the script failed, so
#    matplotlib's warnings about a figure it did write never reached the caller.
#    The interpreter is a stand-in, this perl running a script of its own, so
#    that the check needs no python and does not turn on a warning's wording.
# ----------------------------------------------------------------------------
{
	my $standin = sub {
		my ( $name, $body ) = @_;
		my $file = File::Spec->catfile( $TMP, $name );
		open my $o, '>', $file or die "can't write $file: $!";
		print {$o} $body;
		close $o or die "can't close $file: $!";
		return $file;
	};
	my $run_with = sub {
		my ($interpreter) = @_;
		local $Matplotlib::Simple::Matplotlib::python_command = [ $^X, $interpreter ];
		my $died;
		my ( $out, $err ) = capture { $died = eval { plt( plot_type => 'bar', data => \%bars, output_file => out_file('.png') ); 1 } ? '' : "$@" };
		$died =~ s/\n\t.*\z//s;
		return ( $out, $err, $died );
	};
	my ( $out, $err, $died ) = $run_with->( $standin->( 'warns.pl', "print STDERR qq{UserWarning: stand-in warning\\n};\nprint STDOUT qq{stand-in report\\n};\nexit 0;\n" ) );
	is( $died, '', 'a script that warns and succeeds does not die' );
	like( $err, qr/^UserWarning: stand-in warning$/m, 'its STDERR reaches the caller\'s STDERR' );
	unlike( $out, qr/stand-in warning/, 'and not the caller\'s STDOUT' );
	# kept: its STDOUT is printed, as it was
	like( $out, qr/^stand-in report$/m, 'its STDOUT still reaches the caller\'s STDOUT' );
	unlike( $err, qr/stand-in report/, 'and not the caller\'s STDERR' );
	# a script with nothing to say adds nothing
	( $out, $err, $died ) = $run_with->( $standin->( 'quiet.pl', "exit 0;\n" ) );
	is( $died, '', 'a script that is silent does not die' );
	is( $err, '', 'and nothing is written to STDERR for it' );
	# kept: a script that fails still dies, with its STDERR shown once
	( $out, $err, $died ) = $run_with->( $standin->( 'fails.pl', "print STDERR qq{stand-in traceback\\n};\nexit 3;\n" ) );
	like( $died, qr/unexpectedly returned exit value 3/, 'a script that fails still dies with its exit value' );
	my @shown = ( $err =~ m/stand-in traceback/g );
	is( scalar @shown, 1, 'and its STDERR is shown once' );
	# with matplotlib itself: all bars at or below 0 on a log scale is a
	# figure matplotlib writes and warns about
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 2 ) unless $mpl_available;
		local $ENV{MPLBACKEND} = 'Agg';
		my $image = out_file('.png');
		my ( $o, $e ) = capture { $died = eval { plt( plot_type => 'bar', data => { A => -1, B => 0 }, logscale => 1, output_file => $image ); 1 } ? '' : "$@" };
		ok( ( !length $died ) && ( -s $image ), 'a log-scaled bar plot with no positive bar is still written' );
		like( $e, qr/Warning/, 'and matplotlib\'s warning about it is shown' );
	}
}

# ----------------------------------------------------------------------------
# 4. An "add" inside an "add" graph was left out of the figure by the
#    matplotlib engine without a word.
# ----------------------------------------------------------------------------
{
	my %line   = ( plot_type => 'plot',    data => { L => [ [ 0, 1 ], [ 1, 2 ] ] } );
	my %points = ( plot_type => 'scatter', data => { X => [ 0, 1 ], Y => [ 2, 2 ] } );
	my $nested = qr/^"add" graph 0 has an "add" of its own, which is not drawn/;
	foreach my $engine ( 'matplotlib', 'gnuplot', 'ggplot2' ) {
		dies_with( { plot_type => 'bar', data => \%bars, engine => $engine, add => [ { %line, add => [ {%points} ] } ] }, $nested, "$engine: a nested \"add\" is refused" );
	}
	dies_with( { plot_type => 'bar', data => \%bars, add => [ {%line}, { %points, add => [] } ] }, qr/^"add" graph 1 has an "add" of its own/, 'an empty nested "add" is refused too, by its place' );
	dies_with(
		{ plots => [ { plot_type => 'bar', data => \%bars }, { plot_type => 'bar', data => \%bars, add => [ { %line, add => [ {%points} ] } ] } ], ncols => 2 },
		qr/^"add" at subplot 1 graph 0 has an "add" of its own/,
		'a nested "add" in a subplot is refused, naming the subplot'
	);
	dies_with( { p => [ [ { plot_type => 'bar', data => \%bars }, { %line, add => [ {%points} ] } ] ] }, qr/graph 0 has an "add" of its own/, 'a nested "add" in "p" is refused' );
	# kept: every graph listed in the one "add" is drawn
	my ( $py, $file ) = lives( { plot_type => 'bar', data => \%bars, add => [ {%line}, {%points} ] }, 'a flat "add" of two graphs is accepted' );
	like( $py, qr/^ax0\.plot\(/m,    'the first added graph is drawn' );
	like( $py, qr/^ax0\.scatter\(/m, 'the second added graph is drawn' );
	like( $py, qr/^ax0\.bar\(/m,     'and the plot they were added to' );
	parses_ok( $file, 'the script parses' );
	# kept: "p" gathers the graphs of a subplot into the same flat "add"
	( $py, $file ) = lives( { p => [ [ { plot_type => 'bar', data => \%bars }, {%line}, {%points} ] ] }, '"p" with three graphs on one subplot is accepted' );
	like( $py, qr/^ax0\.plot\(.*^ax0\.scatter\(/ms, 'and draws both additions' );
}

# ----------------------------------------------------------------------------
# 5. An error bar along the axis of labels -- "yerr" on a barh, "xerr" on a bar
#    -- died in python as "ConversionError: Failed to convert value(s) to axis
#    units" whenever it was written as a lower and an upper row, as the hash
#    form always was.
# ----------------------------------------------------------------------------
{
	my ( $py, $file ) = lives( { plot_type => 'barh', data => \%bars, yerr => { A => 1, B => 0.5 } }, 'barh: a "yerr" hash of one number per key is accepted' );
	like( $py, qr/^ax0\.barh\(labels, vals\s*, yerr = \[1,0\.5\]\)/m, 'barh: and written as one row' );
	parses_ok( $file, 'barh: the script parses' );
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 1 ) unless $mpl_available;
		my ( $out, $status ) = run_py( $file, '' );
		is( $status, 0, 'barh: and the figure is drawn' );
	}
	($py) = lives( { plot_type => 'barh', data => \%bars, yerr => { A => [ 1, 1 ], B => [ 0.5, '5e-1' ] } }, 'barh: "yerr" pairs that are equal are accepted' );
	like( $py, qr/, yerr = \[1,0\.5\]\)/, 'barh: and written as one row' );
	( $py, $file ) = lives( { plot_type => 'bar', data => \%bars, xerr => [ [ 0.1, 0.2 ], [ 0.1, 0.2 ] ] }, 'bar: two equal rows of "xerr" are accepted' );
	like( $py, qr/^ax0\.bar\(labels, vals\s*, xerr = \[0\.1,0\.2\]\)/m, 'bar: and written as one row' );
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 1 ) unless $mpl_available;
		my ( $out, $status ) = run_py( $file, '' );
		is( $status, 0, 'bar: and the figure is drawn' );
	}
	my $refused = qr/^"yerr" on a barh lies along the axis of its labels.*give one number per bar, or "xerr"/s;
	dies_with( { plot_type => 'barh', data => \%bars, yerr => { A => [ 1, 2 ], B => 1 } }, $refused, 'barh: a "yerr" hash with a lower and an upper error is refused by name' );
	dies_with( { plot_type => 'barh', data => \%bars, yerr => [ [ 1, 1 ], [ 1, 2 ] ] }, $refused, 'barh: two rows of "yerr" that differ are refused' );
	dies_with( { plot_type => 'bar', data => \%bars, xerr => { A => [ 1, 2 ], B => 1 } }, qr/^"xerr" on a bar lies along the axis of its labels.*or "yerr"/s, 'bar: an "xerr" hash with a lower and an upper error is refused by name' );
	# kept: along the bars a lower and an upper row are drawn as before
	($py) = lives( { plot_type => 'bar', data => \%bars, yerr => { A => [ 1, 2 ], B => 1 } }, 'bar: a "yerr" hash with a lower and an upper error is accepted' );
	like( $py, qr/, yerr = \[\[1,1\],\[2,1\]\]\)/, 'bar: and written as two rows' );
	($py) = lives( { plot_type => 'bar', data => \%bars, yerr => { A => 1, B => 1 } }, 'bar: a "yerr" hash of one number per key is accepted' );
	like( $py, qr/, yerr = \[\[1,1\],\[1,1\]\]\)/, 'bar: and written as two rows, as it was' );
	($py) = lives( { plot_type => 'barh', data => \%bars, xerr => [ [ 1, 1 ], [ 2, 1 ] ] }, 'barh: two rows of "xerr" are accepted' );
	like( $py, qr/, xerr = \[\[1,1\],\[2,1\]\]\)/, 'barh: and written as two rows' );
	# kept: one number, and one row, across the bars
	($py) = lives( { plot_type => 'barh', data => \%bars, yerr => 0.2 }, 'barh: one "yerr" for every bar is accepted' );
	like( $py, qr/, yerr = 0\.2\)/, 'barh: and written as given' );
	($py) = lives( { plot_type => 'barh', data => \%bars, yerr => [ 0.1, 0.2 ] }, 'barh: a row of "yerr" is accepted' );
	like( $py, qr/, yerr = \[0\.1,0\.2\]\)/, 'barh: and written as given' );
	# kept: a grouped plot is drawn at numbers, and takes two rows either way
	( $py, $file ) = lives( { plot_type => 'barh', data => { A => [ 1, 2 ], B => [ 2, 3 ] }, yerr => [ [ 0.1, 0.2 ], [ 0.3, 0.2 ] ] }, 'grouped barh: two rows of "yerr" that differ are accepted' );
	like( $py, qr/, yerr = \[\[0\.1,0\.2\],\[0\.3,0\.2\]\]/, 'grouped barh: and written as two rows' );
	SKIP: {
		skip( 'matplotlib >= 3.10 not found', 1 ) unless $mpl_available;
		my ( $out, $status ) = run_py( $file, '' );
		is( $status, 0, 'grouped barh: and the figure is drawn' );
	}
}

# ----------------------------------------------------------------------------
# 6. The gnuplot engine did arithmetic with "bins" before it checked it, so
#    numpy's "bins => 'auto'" died as 'Argument "auto" isn't numeric in numeric
#    gt (>)'.
# ----------------------------------------------------------------------------
{
	my %sets    = ( A => [ 1, 2, 2, 3, 3, 3, 4 ], B => [ 2, 3, 4, 4, 5 ] );
	my $refused = qr/^"bins" is a whole number of bins, or an array of their edges, for the gnuplot engine, not "auto"/;
	dies_with( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => 'auto' }, $refused, 'gnuplot: bins => "auto" is refused by name' );
	dies_with( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => { A => 5, B => 'auto' } }, $refused, 'gnuplot: and so is a set\'s own' );
	dies_with( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => 2.5 }, qr/^"bins" is a whole number of bins.*not "2\.5"/, 'gnuplot: a fraction of a bin is still refused' );
	unlike( message_of( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => 'auto' } ), qr/isn't numeric/, 'gnuplot: perl\'s own warning is not the message' );
	# kept: a number of bins, and none, are written as they were
	my ($gp) = lives( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => 5 }, 'gnuplot: bins => 5 is accepted' );
	like( $gp, qr/using 1 bins=5 with boxes/, 'gnuplot: and written' );
	($gp) = lives( { plot_type => 'hist', data => \%sets, engine => 'gnuplot' }, 'gnuplot: a hist with no "bins" is accepted' );
	like( $gp, qr/using 1 bins=10 with boxes/, 'gnuplot: and drawn with 10' );
	($gp) = lives( { plot_type => 'hist', data => \%sets, engine => 'gnuplot', bins => [ 1, 2, 3, 4, 5 ] }, 'gnuplot: even edges are accepted' );
	like( $gp, qr/using 1 bins binrange \[1\.5:4\.5\] binwidth=1 with boxes/, 'gnuplot: and written as a range and a width' );
	# kept: matplotlib takes numpy's estimators
	my ($py) = lives( { plot_type => 'hist', data => \%sets, bins => 'auto' }, 'matplotlib: bins => "auto" is accepted' );
	like( $py, qr/bins = 'auto'/, 'matplotlib: and written as a string' );
}

# ----------------------------------------------------------------------------
# 7. A "color_key" that is not a key of the data was reported as a miscount of
#    the keys, which never named it. t/04.options.t expected its name and saw
#    it only in the Devel::Confess trace under the message.
# ----------------------------------------------------------------------------
{
	my %three = ( A => [ 1 .. 5 ], B => [ 1 .. 5 ], C => [ 1 .. 5 ] );
	foreach my $engine ( 'matplotlib', 'gnuplot', 'ggplot2' ) {
		foreach my $shape ( [ 'one set', {%three} ], [ 'a set of several', { S => {%three}, T => {%three} } ] ) {
			my ( $what, $data ) = @{$shape};
			my $message = message_of( { plot_type => 'scatter', data => $data, color_key => 'Missing', engine => $engine } );
			like( $message, qr/"Missing" isn't defined/, "$engine, $what: a \"color_key\" that is not in the data is named" );
			unlike( $message, qr/\bleave\b/, "$engine, $what: and not reported as a miscount of the keys" );
		}
	}
	# with two keys as well, where the count was right and the name was given
	dies_with( { plot_type => 'scatter', data => { X => [ 1, 2 ], Y => [ 1, 2 ] }, color_key => 'Missing' }, qr/^"Missing" isn't defined for this scatter/, 'two keys: a "color_key" that is not in the data is named, as it was' );
	# kept: a "color_key" that is in the data, and leaves the wrong number of
	# keys for x and y, is still a miscount
	dies_with( { plot_type => 'scatter', data => \%three, keys => [ 'A', 'B' ], color_key => 'A' }, qr/needs one key for x and one for y, but "keys" and "color_key" leave the 1 above/, 'a "color_key" that is also one of two "keys" is still a miscount' );
	# kept: and one that is right colors the points
	my ( $py, $file ) = lives( { plot_type => 'scatter', data => \%three, color_key => 'A' }, 'a "color_key" that is in the data is accepted' );
	like( $py, qr/^z = \[1,2,3,4,5\]/m, 'and its values are the color axis' );
	like( $py, qr/fig\.colorbar\(im, label = 'A'/, 'and it labels the colorbar' );
	parses_ok( $file, 'the script parses' );
	( $py, $file ) = lives( { plot_type => 'scatter', data => { S => {%three}, T => {%three} }, color_key => 'B' }, 'several sets: a "color_key" that is in each is accepted' );
	parses_ok( $file, 'several sets: the script parses' );
}

done_testing();
