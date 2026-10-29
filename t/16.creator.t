#!/usr/bin/env perl
#
# The note that a saved figure carries about how it was made: matplotlib's
# "Creator" metadata, which an SVG holds as <dc:creator><cc:Agent><dc:title>.
# It ends ", by <user> on <host>", both read by the generated script as it
# runs, so they name whoever ran it and where.
#
# An SVG carries that note and nothing else of matplotlib's: no DOCTYPE, which
# matplotlib 3.11.2 writes from the fixed string svgProlog in backend_svg.py,
# and no <dc:date>, <dc:format> or <dc:type>. Other formats keep matplotlib's
# metadata as it was.
#
# The first block reads the generated python as text and runs everywhere,
# including a Windows smoker with no python. The rest need python3 and
# matplotlib >= 3.10, and skip without them.
#
require 5.010;
use strict;
use warnings FATAL => 'all';
use File::Temp 'tempdir';
use File::Spec;
use Capture::Tiny 'capture';
use Cn::Plot;
# The interpreter the module itself runs; see t/07.review.fixes.t.
my @PY = Cn::Plot::Matplotlib::python_command();
my $PY = join ' ', @PY;
use Test::More;

my $TMP = tempdir( CLEANUP => 1 );
my $seq = 0;

my $python_raw = ( scalar @PY ? qx/$PY --version 2>&1/ : '' );
my $python_available = ( $? == 0 && $python_raw =~ m/Python\s+3\.\d+/i ) ? 1 : 0;
my $mpl_available = 0;
if ($python_available) {
	# 3.10 is the floor every render test gates on; see t/15.tooltips.t.
	my $raw = qx/$PY -c "import matplotlib; print(matplotlib.__version__)" 2>&1/;
	if ( $? == 0 && $raw =~ m/^\s*(\d+)\.(\d+)/ ) {
		$mpl_available = ( $1 > 3 || ( $1 == 3 && $2 >= 10 ) ) ? 1 : 0;
	}
}
diag( $mpl_available ? 'matplotlib >= 3.10 found (render checks ON)' : 'no matplotlib >= 3.10 (render checks skipped)' );

sub out_file {
	my ($ext) = @_;
	return File::Spec->catfile( $TMP, 'gen' . $seq++ . '.' . ( $ext // 'svg' ) );
}

sub slurp {
	my ($file) = @_;
	open my $in, '<:encoding(UTF-8)', $file or die "can't read $file: $!";
	local $/;
	my $text = <$in>;
	close $in;
	return $text;
}

sub creator {
	my ($svg) = @_;
	return $svg =~ m{<dc:creator>\s*<cc:Agent>\s*<dc:title>(.*?)</dc:title>}s ? $1 : '';
}

my %bar = ( plot_type => 'bar', data => { A => 1, B => 2 } );

# ----------------------------------------------------------------------------
# 1. The script reads the user and the host itself.
# ----------------------------------------------------------------------------
my ( undef, undef, $script ) = capture { plt( {%bar, output_file => out_file(), execute => 0} ) };
my $py = slurp($script);
like( $py, qr/^\s*creator_user = getpass\.getuser\(\)$/m, 'the user is read by the script, from getpass' );
like( $py, qr/^creator_host = platform\.node\(\) or 'unknown host'/m, 'the host is read by the script, from platform.node' );
like( $py, qr/^plt\.savefig\(.*'Creator':.*\+ ', by ' \+ creator_user \+ ' on ' \+ creator_host(?:, 'Date': None.*)?\}\)$/m, 'both end the Creator note' );

# ----------------------------------------------------------------------------
# 2. Rendered: the SVG names this user and this host.
# ----------------------------------------------------------------------------
SKIP: {
	skip( 'no matplotlib >= 3.10', 3 ) unless $mpl_available;
	local $ENV{MPLBACKEND} = 'Agg';
	# The same calls, run by the same interpreter with the same environment.
	my ( $who ) = capture { system( @PY, '-c', 'import getpass, platform; print(getpass.getuser()); print(platform.node())' ) };
	my ( $user, $host ) = split /\r?\n/, $who;
	my $file = out_file();
	capture { plt( {%bar, output_file => $file} ) };
	is( creator( slurp($file) ) =~ m/, by (.*) on (.*)\z/ ? "$1|$2" : '', "$user|$host", 'the SVG ends its note with the user and the host' );
	# getpass.getuser() made to fail, as it does with no LOGNAME, USER, LNAME
	# or USERNAME and no password database.
	$file = out_file();
	( undef, undef, $script ) = capture { plt( {%bar, output_file => $file, execute => 0} ) };
	my ( undef, $err, $status ) = capture {
		system( @PY, '-c', 'import getpass, runpy, sys; getpass.getuser = lambda: (_ for _ in ()).throw(OSError(1)); runpy.run_path(sys.argv[1])', $script );
	};
	is( $status, 0, 'a user that cannot be found does not stop the figure being saved' ) or diag("  python: $err");
	like( creator( -e $file ? slurp($file) : '' ), qr/, by unknown user on \Q$host\E\z/, 'and is named "unknown user"' );
}

# ----------------------------------------------------------------------------
# 3. Only an SVG's script asks for less metadata and cuts the DOCTYPE.
# ----------------------------------------------------------------------------
for my $ext (qw(svg SVGZ)) {
	( undef, undef, $script ) = capture { plt( {%bar, output_file => out_file($ext), execute => 0} ) };
	$py = slurp($script);
	like( $py, qr/^plt\.savefig\(.*'Creator':.*, 'Date': None, 'Format': None, 'Type': None\}\)$/m, ".$ext: Date, Format and Type are left out" );
	like( $py, qr/re\.sub\(rb'<!DOCTYPE/, ".$ext: the DOCTYPE is cut" );
}
for my $ext (qw(png pdf)) {
	( undef, undef, $script ) = capture { plt( {%bar, output_file => out_file($ext), execute => 0} ) };
	$py = slurp($script);
	unlike( $py, qr/'Date': None/, ".$ext: matplotlib's metadata is left as it was" );
	unlike( $py, qr/DOCTYPE/, ".$ext: and there is no DOCTYPE to cut" );
}

# ----------------------------------------------------------------------------
# 4. Rendered: the SVG holds the Creator, and no DOCTYPE, date, format or type.
# ----------------------------------------------------------------------------
SKIP: {
	skip( 'no matplotlib >= 3.10', 12 ) unless $mpl_available;
	local $ENV{MPLBACKEND} = 'Agg';
	my $plain = out_file();
	my $zipped = out_file('svgz');
	# A tooltip SVG is written back by ElementTree, which is a second way of
	# writing the file and must give the same result.
	my $tipped = out_file();
	capture {
		plt( {%bar, output_file => $plain} );
		plt( {%bar, output_file => $zipped} );
		plt( {plot_type => 'scatter', data => { x => [1, 2], y => [3, 4] }, tooltips => ['a', 'b'], output_file => $tipped} );
	};
	my ( $unzipped, $gz_err, $gz_status ) = capture { system( @PY, '-c', 'import gzip, sys; sys.stdout.buffer.write(gzip.open(sys.argv[1]).read())', $zipped ) };
	is( $gz_status, 0, '.svgz could be read' ) or diag("  python: $gz_err");
	for my $case ( [ '.svg', -e $plain ? slurp($plain) : '' ], [ '.svgz', $unzipped ], [ 'tooltips', -e $tipped ? slurp($tipped) : '' ] ) {
		my ( $name, $svg ) = @$case;
		unlike( $svg, qr/<!DOCTYPE/, "$name: no DOCTYPE" );
		unlike( $svg, qr/<dc:(?:date|format|type)\b/, "$name: no dc:date, dc:format or dc:type" );
		like( creator($svg), qr/ called using "plt" in .*, by .+ on .+\z/, "$name: the Creator is kept" );
	}
	my $pdf = out_file('pdf');
	my ( undef, $pdf_err ) = capture { plt( {%bar, output_file => $pdf} ) };
	unlike( $pdf_err, qr/Unknown infodict keyword/, '.pdf: matplotlib does not warn about the metadata' );
	ok( -s $pdf, '.pdf: and it is written' );
}

done_testing();
