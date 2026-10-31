#!/usr/bin/env perl
# test.all.perls.pl - build & test Matplotlib::Simple against every perlbrew perl.
#
# Matplotlib::Simple claims MIN_PERL_VERSION 5.010, so every release has to
# compile and pass its tests on a perl that predates most of what modern perl
# makes habitual (`each @array`, postfix deref, /r, %h{...}, signatures, ...).
# CPAN Testers finds those regressions days after upload; this finds them now:
#
#     ./test.all.perls.pl                # full build + test, 4 perls at a time
#     ./test.all.perls.pl --syntax       # seconds, not minutes: compile only
#     ./test.all.perls.pl -p 5.10.1      # just the perl that broke
#     ./test.all.perls.pl -P 1           # one at a time, in this directory
#
# Each version runs in its own environment (no `perlbrew use` needed: the perl
# binary is invoked directly and PATH is rewritten for the child), and a
# pass/fail summary is printed at the end.  Exit status is non-zero if any
# version failed.
#
# By default four perls are tested at once (-P 4).  They cannot share the
# distribution root: there is one Makefile, one blib and one pm_to_blib, and a
# `make clean` from one perl pulls the tree out from under another's `make
# test`.  So each parallel child builds in a private copy of the tree under the
# log directory and reports its result back to the parent, which leaves the
# root's Makefile and blib exactly as they were.  The test suite also writes
# fixed names into File::Spec->tmpdir (t/01.all.tests.t's dies_ok.svg and
# outfile(), among others), so each child gets its own TMPDIR inside its tree as
# well.  --syntax only reads the tree, so its children all run in the root.
# The fork/throttle/reap loop is the one in ~/Scripts/stats/test.all.perls.pl.
#
# -P 1 is the old behaviour: one perl at a time, oldest first, in the
# distribution root, which is left built against the newest perl.
#
# Unlike a dist with XS, this one is pure perl: there is no OPTIMIZE/-Wall
# knob, `make` is nearly free, and the interesting failures are compile-time
# syntax errors -- hence the dedicated --syntax mode, which is also the only
# mode that is useful on a perl missing some of the prerequisites.
#
# The test suite shells out to python3/matplotlib, which is shared by every
# perl; a missing or broken python fails every version identically and is
# reported once, up front, so it is not mistaken for a perl problem.

use strict;
use warnings FATAL => 'all';
use feature 'say';
use Getopt::Long 'GetOptions';
# -P (how many perls at once) and -p (which perl) are different options, so the
# default case-folding of single-letter aliases has to go.
Getopt::Long::Configure('no_ignore_case');
use File::Spec;
use File::Copy 'copy';
# rmtree, not remove_tree: remove_tree arrived in File::Path 2.07, and perl
# 5.10.0 ships 2.04.
use File::Path 'rmtree';
use IO::Handle;
use Cwd 'getcwd';
use Data::Dumper;
use File::Find 'find';
use POSIX 'strftime';
use Time::HiRes 'time';

# This script deliberately restricts itself to what perl 5.10 understands, so
# it can be run by whichever perl happens to be first in PATH -- including the
# old one it is testing against.

my $PERLBREW_ROOT = $ENV{PERLBREW_ROOT} || File::Spec->catdir($ENV{HOME}, 'perl5', 'perlbrew');

# How many cores this machine has, or 0 when that cannot be determined.
sub cpu_count {
	if (open my $fh, '<', '/proc/cpuinfo') {           # linux
		my $n = grep { /^processor\s*:/ } <$fh>;
		close $fh;
		return $n if $n;
	}
	for my $probe (['getconf', '_NPROCESSORS_ONLN'],   # glibc, solaris, aix
		['sysctl', '-n', 'hw.ncpu']) {             # *bsd, darwin
		my $out = `@$probe 2>/dev/null`;
		return $1 if defined $out && $out =~ /(\d+)/ && $1 > 0;
	}
	return 0;
}

my ($help, $list, $install, $deps, $stop, $quiet, $jobs, $syntax, $all, $keep_work, @only);
my $clean   = 1;
my $minver  = 1;
my $log_dir = File::Spec->catdir('.build', 'multiperl');
my $ncpu    = cpu_count();
# Leave 4 cores for the rest of the machine, as the stats helper does.
my $budget  = $ncpu > 5 ? $ncpu - 4 : 1;
# Four perls at once, each with its own make -j and harness.  -P and -j
# multiply, so -j follows from -P rather than claiming the budget twice.
my $par          = 4;
my $par_default  = $par;
my $jobs_default = jobs_for($par);

sub jobs_for {
	my $p = shift;
	my $j = int($budget / ($p || 1));
	return $j > 1 ? $j : 1;
}

GetOptions(
	'perl|p=s@'     => \@only,
	'syntax|c'      => \$syntax,
	'install!'      => \$install,
	'deps!'         => \$deps,
	'clean!'        => \$clean,
	'minver!'       => \$minver,
	'all|a'         => \$all,
	'stop-on-fail!' => \$stop,
	'jobs|j=i'      => \$jobs,
	'parallel|P:i'  => \$par,
	'keep-work!'    => \$keep_work,
	'log-dir=s'     => \$log_dir,
	'quiet|q'       => \$quiet,
	'list|l'        => \$list,
	'help|h'        => \$help,
) or usage(1);
usage(0) if $help;

sub usage {
	my $rc = shift;
	my $cpus = $ncpu ? "$ncpu CPUs - 4" : 'CPU count unknown';
	print STDERR <<"END";
usage: $0 [options]

Builds and tests the distribution in the current directory against each perl
installed under $PERLBREW_ROOT (oldest first).

options:
  -p, --perl VERSION   only this perl (repeatable); accepts "5.10.1" or
                       "perl-5.10.1".  default: every installed perl
  -c, --syntax         compile lib/*.pm and t/*.t only (perl -c); skips
                       Makefile.PL/make/make test.  Fast, and the one mode
                       that still says something useful when a perl is
                       missing prerequisites
  -l, --list           list the perls that would be tested, then exit
  -a, --all            also test perls older than MIN_PERL_VERSION
                       (default: those are reported as SKIP)
      --install        "make install" after a clean test run (default: no,
                       so this does not scatter the module across perls)
      --no-clean       skip "make clean" before each version
      --deps           cpanm any missing PREREQ_PM for that perl first
      --no-minver      skip the Perl::MinimumVersion advisory pass
      --stop-on-fail   abort at the first version that fails (with -P: launch
                       no more perls; the running ones finish)
  -P, --parallel [N]   test N perls at once, each in a private copy of the tree
                       under --log-dir/work with its own TMPDIR, leaving the
                       distribution root untouched.  bare -P, or -P 0, uses one
                       child per perl, capped at the CPU count; -P 1 builds
                       serially in the distribution root.  default: $par_default
      --keep-work      keep the private tree of a perl that passed (the tree of
                       one that failed is always kept, for inspection)
  -j, --jobs N         parallel make, and HARNESS_OPTIONS=j<N> for the tests;
                       0 builds and tests serially.  -P and -j multiply, so the
                       default is the CPU budget ($cpus) divided by -P
                       (default: $jobs_default at -P $par_default, $budget at -P 1)
      --log-dir DIR    where per-version logs go (default: $log_dir)
  -q, --quiet          only write logs; do not echo build output.  implied by
                       -P > 1, where interleaved output would be unreadable
  -h, --help           this message

exit status: 0 if every perl tested cleanly, else 1.
END
	exit $rc;
}

# ---------------------------------------------------------------- discovery --

my $perls_dir = File::Spec->catdir($PERLBREW_ROOT, 'perls');
die "$0: no perlbrew perls directory at $perls_dir\n" unless -d $perls_dir;

opendir my $dh, $perls_dir or die "$0: cannot read $perls_dir: $!\n";
my @installed = grep { -x File::Spec->catfile($perls_dir, $_, 'bin', 'perl') }
                grep { !/^\.\.?$/ } readdir $dh;
closedir $dh;

# numeric sort so the oldest perl is exercised first and, in a serial run, the
# tree is left built against the newest one.
sub vkey {
	my $v = shift;
	$v =~ s/^perl-//;
	my @p = ($v =~ /(\d+)/g);
	push @p, 0 while @p < 3;
	return sprintf '%05d%05d%05d', @p[0 .. 2];
}
@installed = sort { vkey($a) cmp vkey($b) } @installed;

my @targets = @installed;
if (@only) {
	my @want = map { my $x = $_; $x =~ s/^(?!perl-)/perl-/; $x } map { split /,/ } @only;
	my %have = map { $_ => 1 } @installed;
	my @missing = grep { !$have{$_} } @want;
	die "$0: not installed under perlbrew: @missing\n(installed: @installed)\n" if @missing;
	@targets = sort { vkey($a) cmp vkey($b) } @want;
}
die "$0: no perls found in $perls_dir\n" unless @targets;

die "$0: no Makefile.PL in " . getcwd() . " - run this from the distribution root\n"
	unless -f 'Makefile.PL';

# Everything worth scraping lives in Makefile.PL, which dzil regenerates from
# dist.ini, so this stays in sync with the dist instead of duplicating it.
my $makefile_pl = do {
	open my $fh, '<', 'Makefile.PL' or die "$0: cannot read Makefile.PL: $!\n";
	local $/;
	<$fh>;
};

my @prereqs = do {
	my %seen;
	my ($block) = $makefile_pl =~ /"PREREQ_PM"\s*=>\s*\{(.*?)\}/s;
	defined $block ? (grep { !$seen{$_}++ } ($block =~ /"([\w:]+)"\s*=>/g)) : ();
};
my ($min_perl) = $makefile_pl =~ /"MIN_PERL_VERSION"\s*=>\s*"([\d._]+)"/;
my ($dist_ver) = $makefile_pl =~ /"VERSION"\s*=>\s*"([\d._]+)"/;

# 5.010 -> 00005 00010 00000, comparable with vkey()
sub minkey {
	my $v = shift;
	return '0' unless defined $v;
	my ($maj, $rest) = $v =~ /^(\d+)\.(\d+)/ or return '0';
	my ($min, $pat) = $rest =~ /^(\d{1,3})(\d*)$/ ? ($1 + 0, ($2 || 0) + 0) : ($rest + 0, 0);
	return sprintf '%05d%05d%05d', $maj, $min, $pat;
}
my $min_key = minkey($min_perl);
sub too_old { return vkey($_[0]) lt $min_key }

my @lib_pm;
find({ no_chdir => 1, wanted => sub { push @lib_pm, $File::Find::name if /\.pm$/ } }, 'lib')
	if -d 'lib';
@lib_pm = sort @lib_pm;
my @tests = sort glob 't/*.t';
die "$0: no modules found under lib/\n" unless @lib_pm;

if ($list) {
	for my $t (@targets) {
		printf "%-16s %s%s\n", $t, File::Spec->catfile($perls_dir, $t, 'bin', 'perl'),
			(too_old($t) ? "  (< MIN_PERL_VERSION $min_perl" . ($all ? ', tested anyway)' : ', skipped)') : '');
	}
	exit 0;
}

my @skipped = grep { too_old($_) && !$all } @targets;
my @run     = grep { !too_old($_) || $all } @targets;

# ------------------------------------------------------------- parallelism --

# bare -P (or -P 0) means "all of them", within reason: more perls than cores
# only makes every perl slower.
$par = 0 if $par < 0;
$par ||= do {
	my $cap = $ncpu || 4;   # an unknown CPU count stays conservative rather
	                        # than fanning out over however many perls exist
	@run < $cap ? scalar @run : $cap;
};
$par = @run if $par > @run;
$par = 1 if $par < 1;    # every perl was too old: nothing will run anyway
$jobs = jobs_for($par) unless defined $jobs;   # -j follows -P unless asked for

my $in_parallel = $par > 1 && @run > 1;
my $work_root   = File::Spec->catdir($log_dir, 'work');
if ($in_parallel) {
	# children chdir into their own tree, so these paths must not be relative
	$log_dir   = File::Spec->rel2abs($log_dir);
	$work_root = File::Spec->rel2abs($work_root);
	$quiet     = 1;   # N interleaved build logs on one terminal is noise
}

# ------------------------------------------------------------------ logging --

sub mkdirp {
	my @parts = File::Spec->splitdir(shift);
	my $path;   # undef, not '': splitdir gives an absolute path a leading '',
	            # and catdir('', 'home') is '/home' where 'home' would be a
	            # directory of that name in the cwd.
	for my $p (@parts) {
		$path = defined $path ? File::Spec->catdir($path, $p) : $p;
		next if !length($path) || -d $path;
		mkdir $path or die "$0: mkdir $path: $!\n";
	}
}
mkdirp($log_dir);
my $stamp = strftime '%Y%m%d-%H%M%S', localtime;

# ------------------------------------------------------------- child runner --

# Run @cmd with STDERR folded into STDOUT, echoing to the terminal and to
# $logfh (either may be omitted).  Returns ($exit_code, \@lines).  Nothing is
# passed through a shell, so no argument needs quoting.
sub run_cmd {
	my ($cmd, $logfh, $silent) = @_;
	$silent = 1 if $quiet;
	print $logfh "\n\$ @$cmd\n"  if $logfh;
	print "\$ @$cmd\n"           unless $silent;

	my $pid = open my $fh, '-|';
	die "$0: fork failed: $!\n" unless defined $pid;
	if (!$pid) {                              # child
		open STDERR, '>&', \*STDOUT or die "$0: dup STDERR: $!\n";
		$| = 1;
		{ exec { $cmd->[0] } @$cmd; }
		print "exec @$cmd failed: $!\n";
		exit 127;
	}

	my @lines;
	while (defined(my $line = <$fh>)) {
		push @lines, $line;
		print $logfh $line if $logfh;
		print $line        unless $silent;
	}
	close $fh;
	my $status = $?;
	my $code = $status == -1   ? -1
		 : ($status & 127) ? 128 + ($status & 127)
		 :                   ($status >> 8);
	return ($code, \@lines);
}

# A perl too old for the syntax being used and a perl merely missing a
# prerequisite fail identically as far as exit codes go, but only the first is
# a bug in this distribution -- keep them apart in the summary.
sub classify {
	my $lines = shift;
	my (@missing, $err);
	for my $l (@$lines) {
		push @missing, $1 if $l =~ /Can't locate (\S+?)\.pm in \@INC/;
		push @missing, $1 if $l =~ /you may need to install the (\S+?) module/i;
		# autodie ':all' reports its own missing back end this way
		push @missing, $1 if $l =~ /^([\w:]+) required for Fatalised/;
		$err = $l if !defined $err && $l =~ /\bat .*? line \d+/ && $l !~ /^\s*#/;
	}
	if (@missing) {
		my %seen;
		my @mods = grep { !$seen{$_}++ } @missing;
		s{/}{::}g for @mods;
		return ('DEPS', 'missing: ' . join(' ', @mods));
	}
	if (defined $err) {
		chomp $err;
		$err =~ s/\s+/ /g;
		return ('FAIL', $err);
	}
	return ('FAIL', undef);
}

# --------------------------------------------------------------- prologue ---

STDOUT->autoflush(1);
my @short = @targets;
s/^perl-// for @short;
say '=' x 72;
printf "== Matplotlib::Simple %s   MIN_PERL_VERSION %s\n",
	(defined $dist_ver ? $dist_ver : '?'), (defined $min_perl ? $min_perl : '?');
printf "== %d module(s), %d test file(s), %d perl(s): %s\n",
	scalar @lib_pm, scalar @tests, scalar @targets, join ' ', @short;
say '=' x 72;

# python3 is shared by every perl, so a broken python is not a perl failure --
# say so once here rather than letting it look like four identical regressions.
{
	my ($code, $lines) = run_cmd(
		['python3', '-c', 'import matplotlib; print(matplotlib.__version__)'], undef, 1);
	my $first = @$lines ? $lines->[0] : '';
	chomp $first;
	if ($code == 0 && $first =~ /^\d/) {
		say "-- python3 matplotlib $first";
	} elsif ($syntax) {
		say "-- python3/matplotlib unusable ($first) - harmless in --syntax mode";
	} else {
		say '-- WARNING: python3/matplotlib unusable, every perl will fail the same way:';
		say "--   $_" for map { my $l = $_; chomp $l; $l } @$lines;
	}
}

# Perl::MinimumVersion, run under whichever perl is running this script, names
# the construct that raised the floor -- which is the actual question when a
# CPAN Testers report says 5.10.1 will not compile.  Advisory only: it is a
# static heuristic, so the real answer is still `make test` under an old perl.
if ($minver) {
	my $probe = <<'END_PROBE';
my $max;
for my $f (@ARGV) {
	my $p = Perl::MinimumVersion->new($f) or next;
	my $v = $p->minimum_version           or next;
	printf "%-44s %s\n", $f, $v;
	$max = $v if !defined($max) || $v > $max;
}
print "MINIMUM $max\n" if defined $max;
END_PROBE
	my ($code, $lines) = run_cmd(
		[$^X, '-MPerl::MinimumVersion', '-e', $probe, @lib_pm, @tests], undef, 1);
	if ($code != 0) {
		say '-- Perl::MinimumVersion not installed; skipping the static floor check';
	} else {
		my $max;
		for my $l (@$lines) {
			if ($l =~ /^MINIMUM (\S+)/) { $max = $1; next }
			print "-- $l" unless $quiet;
		}
		if (defined $max) {
			printf "-- Perl::MinimumVersion floor: %s (declared %s)%s\n",
				$max, (defined $min_perl ? $min_perl : '?'),
				(defined $min_perl && minkey($max) gt minkey($min_perl)
					? '  <== raises the floor above MIN_PERL_VERSION' : '');
		}
	}
}

say "-- $_: SKIP (older than MIN_PERL_VERSION $min_perl; --all to test anyway)" for @skipped;

# ------------------------------------------------------------ build one perl --

# Build and test the distribution in the current directory with one perl.
# Returns the result hashref, and prints its own progress unless $silent: a
# parallel child is silent and the parent reports for it.  $tmpdir, when given,
# becomes the children's TMPDIR.
sub build_one {
	my ($version, $silent, $tmpdir) = @_;
	my $root = File::Spec->catdir($perls_dir, $version);
	my $bin  = File::Spec->catdir($root, 'bin');
	my $perl = File::Spec->catfile($bin, 'perl');

	my $log = File::Spec->catfile($log_dir, "$version.$stamp.log");
	# Re-create the log directory rather than trusting that it survived a
	# matrix run that takes minutes.
	mkdirp($log_dir);
	open my $logfh, '>', $log or die "$0: cannot write $log: $!\n";
	$logfh->autoflush(1);

	unless ($silent) {
		print "\n", '=' x 72, "\n";
		printf "== %s   (log: %s)\n", $version, $log;
		print '=' x 72, "\n";
	}
	print $logfh "== $version at " . strftime('%F %T', localtime)
		. ' in ' . getcwd() . "\n";

	# Emulate `perlbrew use $version` for the children: this perl's bin first,
	# every other perlbrew perl stripped out, and local::lib / PERL5LIB
	# leftovers from the calling shell removed so nothing bleeds across
	# versions.
	local %ENV = %ENV;
	my @path = grep { index($_, File::Spec->catdir($perls_dir, '')) != 0 }
	           split /:/, ($ENV{PATH} || '/usr/bin:/bin');
	$ENV{PATH}          = join ':', $bin, @path;
	$ENV{PERLBREW_ROOT} = $PERLBREW_ROOT;
	$ENV{PERLBREW_PERL} = $version;
	$ENV{PERLBREW_PATH} = $bin;
	delete @ENV{qw(PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MM_OPT PERL_MB_OPT
	               PERLBREW_LIB PERL_MM_USE_DEFAULT)};
	$ENV{HARNESS_OPTIONS} = "j$jobs" if $jobs;
	$ENV{TMPDIR} = $tmpdir if defined $tmpdir;

	my $t0 = time;
	my %r = (version => $version, log => $log, steps => [], warnings => 0);

	# sanity: the interpreter really is the version we think it is
	my ($vc, $vout) = run_cmd([$perl, '-e', 'printf "%vd\n", $^V'], $logfh);
	$r{reported} = $vc == 0 && @$vout ? do { my $s = $vout->[0]; chomp $s; $s } : '?';

	my @steps;
	if ($deps && @prereqs) {
		my @missing;
		for my $mod (@prereqs) {
			my ($c) = run_cmd([$perl, "-M$mod", '-e', '1'], $logfh);
			push @missing, $mod if $c != 0;
		}
		if (@missing) {
			my $cpanm = -x File::Spec->catfile($bin, 'cpanm')
			          ? File::Spec->catfile($bin, 'cpanm')
			          : File::Spec->catfile($PERLBREW_ROOT, 'bin', 'cpanm');
			push @steps, ['deps', [$perl, $cpanm, '--notest', @missing]];
		}
	}

	# Compile first, always: a syntax error that only this perl rejects is the
	# regression this script exists to catch, and finding it here means not
	# waiting out a build to read the same message.
	push @steps, ["-c $_", [$perl, '-Ilib', '-c', $_]] for @lib_pm;

	if ($syntax) {
		push @steps, ["-c $_", [$perl, '-Ilib', '-c', $_]] for @tests;
	} else {
		push @steps, ['clean', ['make', 'clean'], 1] if $clean && -f 'Makefile'; # 1 = failure tolerated
		push @steps, ['Makefile.PL',  [$perl, 'Makefile.PL']];
		push @steps, ['make',         ['make', $jobs ? ("-j$jobs") : ()]];
		push @steps, ['make test',    ['make', 'test']];
		push @steps, ['make install', ['make', 'install']] if $install;
	}

	my ($failed, $status);
	for my $step (@steps) {
		my ($label, $cmd, $soft) = @$step;
		my $t_step = time;
		my ($code, $lines) = run_cmd($cmd, $logfh);
		my $secs = time - $t_step;
		printf $logfh "-- step '%s' exited %d after %.1fs\n", $label, $code, $secs;

		if ($label eq 'make test') {
			for my $l (@$lines) {
				$r{files}  = $1 if $l =~ /^(Files=\d+.*)/;
				$r{result} = $1 if $l =~ /^Result:\s*(\S+)/;
				$r{passed} = 1  if $l =~ /^All tests successful/;
			}
		}
		# residual warnings are worth surfacing even on success
		$r{warnings} += grep { /\bwarning:|^Warning:/ } @$lines;

		push @{ $r{steps} }, { label => $label, code => $code, seconds => $secs };
		next if $code == 0 || $soft;
		$failed = $label;
		($status, $r{error}) = classify($lines);
		last;
	}

	if ($clean && !$syntax && !$failed && !$in_parallel) {
		# leave a clean tree behind before the next perl takes over.  in
		# parallel mode the whole private tree goes instead, so this would
		# only be a `make clean` nobody reads.
		run_cmd(['make', 'clean'], $logfh) unless $version eq $run[-1];
	}

	$r{seconds} = time - $t0;
	$r{failed}  = $failed;
	$r{status}  = $failed ? $status : 'PASS';
	close $logfh;

	report_one(\%r) unless $silent;
	return \%r;
}

# the progress lines a finished perl prints, from the parent in either mode
sub report_one {
	my $r = shift;
	printf "-- %s: %s in %.1fs%s\n", $r->{version},
		($r->{failed} ? "$r->{status} at '$r->{failed}'" : 'ok'),
		$r->{seconds},
		(defined $r->{files} ? " ($r->{files})" : '');
	print '-- ', $r->{error}, "\n" if defined $r->{error};
	print '-- ', join('  ', map { sprintf '%s %.1fs', $_->{label}, $_->{seconds} }
	                        @{ $r->{steps} }), "\n" if @{ $r->{steps} };
}

# ------------------------------------------------------------ private trees --

# What must not be copied into a private build tree: the build products of
# whichever perl last used the source tree (a blib built by another perl is
# exactly what the private trees exist to avoid), the repository, the coverage
# database, the release snapshots and their tarballs, the log/work tree itself,
# and output.images, which t/01.all.tests.t creates for itself.  The file
# patterns are MANIFEST.SKIP's.
my %SKIP_DIR  = map { $_ => 1 } qw(.git .build blib cover_db output.images);
my @SKIP_FILE = (qr/^Makefile(?:\.old)?$/, qr/^pm_to_blib$/, qr/^blibdirs$/,
	qr/^MYMETA\./, qr/^Matplotlib-Simple-.*\.tar\.gz$/);

sub copy_tree {
	my ($src, $dst) = @_;
	mkdirp($dst);
	opendir my $dh, $src or die "$0: cannot read $src: $!\n";
	my @entries = grep { !/^\.\.?$/ } readdir $dh;
	closedir $dh;
	for my $e (@entries) {
		my $s = File::Spec->catfile($src, $e);
		my $d = File::Spec->catfile($dst, $e);
		if (-d $s) {
			next if $SKIP_DIR{$e} || $e =~ /^Matplotlib-Simple-[\d.]+$/;
			# a --log-dir inside the tree would copy itself forever
			my $abs = File::Spec->rel2abs($s);
			next if $abs eq $work_root || $abs eq $log_dir;
			copy_tree($s, $d);
			next;
		}
		next if grep { $e =~ $_ } @SKIP_FILE;
		copy($s, $d) or die "$0: copy $s -> $d: $!\n";
		chmod((stat $s)[2] & 07777, $d);
	}
}

# The child's result has to cross a fork, and %r is plain data, so Dumper out /
# eval in beats any IPC here: it also leaves the numbers next to the log when
# something needs explaining afterwards.
sub write_result {
	my ($file, $r) = @_;
	mkdirp($log_dir);
	open my $fh, '>', $file or die "$0: cannot write $file: $!\n";
	local $Data::Dumper::Indent   = 0;
	local $Data::Dumper::Sortkeys = 1;
	print $fh Data::Dumper->Dump([$r], ['R']);
	close $fh or die "$0: close $file: $!\n";
}

sub read_result {
	my $file = shift;
	open my $fh, '<', $file or return undef;
	local $/;
	my $src = <$fh>;
	close $fh;
	my $R;
	eval $src;                      # our own Dumper output, nobody else's
	return ref $R eq 'HASH' ? $R : undef;
}

# ------------------------------------------------------------------ drivers --

sub run_serial {
	my @queue = @_;
	my @out;
	for my $version (@queue) {
		my $r = build_one($version);
		push @out, $r;
		next unless $r->{failed} && $stop;
		my %done = map { $_->{version} => 1 } @out;
		my @rest = grep { !$done{$_} } @queue;
		print "-- --stop-on-fail: skipping @rest\n" if @rest;
		last;
	}
	return @out;
}

# Fork up to $par children, each in its own copy of the tree (or, for
# --syntax, in the root, which perl -c only reads), reaping them as they finish
# and starting the next perl in the freed slot.
sub run_parallel {
	my @order = @_;
	my @queue = @order;
	my $src   = getcwd();
	my %kid;                        # pid => { version, work, result, log }
	my (@out, $halt);

	my $reaper = sub {
		my ($pid, $status) = @_;
		my $kid = delete $kid{$pid} or return;
		my $r   = read_result($kid->{result});
		if (!$r) {
			# The child died without reporting: exec failure, signal, OOM, or
			# a log directory that disappeared under it.  Naming a log file
			# that was never created sends the reader looking for evidence
			# that is not there, so distinguish the two.
			my $log = -e $kid->{log} ? $kid->{log}
				: "$kid->{log} (never written)";
			$r = { version => $kid->{version}, log => $log, status => 'FAIL',
				reported => '?', steps => [], warnings => 0, seconds => 0,
				failed => sprintf('child exited %d%s', $status >> 8,
					($status & 127) ? ' on signal ' . ($status & 127) : '') };
		}
		push @out, $r;
		report_one($r);
		$halt = 1 if $r->{failed} && $stop;
		if (defined $kid->{work}) {
			if ($r->{failed} || $keep_work) {
				print "-- $kid->{version}: build tree kept at $kid->{work}\n";
			}
			else {
				rmtree($kid->{work});
			}
		}
	};

	local $SIG{INT} = local $SIG{TERM} = sub {
		my $sig = shift;
		print "\n-- $sig: stopping " . keys(%kid) . " running build(s)\n";
		# each child leads its own process group (see the fork below), so one
		# signal per group takes its make, its harness and its python3s with
		# it; signalling the child perl alone would orphan those.
		kill 'TERM', map { -$_ } keys %kid;
		sleep 1;
		kill 'KILL', map { -$_ } keys %kid;
		exit 130;
	};

	while (@queue || %kid) {
		while (@queue && keys(%kid) < $par && !$halt) {
			my $version = shift @queue;
			my $result  = File::Spec->catfile($log_dir, "$version.$stamp.result");
			my $log     = File::Spec->catfile($log_dir, "$version.$stamp.log");
			my ($work, $tmpdir);   # both undef = run in the root, with the caller's TMPDIR
			unless ($syntax) {
				$work   = File::Spec->catdir($work_root, "$version.$stamp");
				$tmpdir = File::Spec->catdir($work, '.tmp');
				rmtree($work) if -d $work;
				printf "-- %-16s starting (tree: %s)\n", $version, $work;
				copy_tree($src, $work);
				mkdirp($tmpdir);
			}
			else {
				printf "-- %-16s starting\n", $version;
			}

			my $pid = fork;
			die "$0: fork failed: $!\n" unless defined $pid;
			if (!$pid) {                              # child
				$SIG{$_} = 'DEFAULT' for qw(INT TERM);
				setpgrp 0, 0;   # so ^C reaches this whole build, once, via
						# the parent's handler and not the terminal
				# Catch a die in here and put the reason where the parent
				# actually looks, which is the result file; otherwise it
				# reaches the parent as nothing but an exit status.
				my $r = eval {
					if (defined $work) { chdir $work or die "chdir $work: $!\n" }
					build_one($version, 1, $tmpdir);
				};
				unless ($r) {
					my $why = $@ || 'build_one returned nothing';
					chomp $why;   # $r->{failed} is printed inside quotes
					$r = { version => $version, log => $log, status => 'FAIL',
						reported => '?', steps => [], warnings => 0,
						seconds => 0, failed => $why };
				}
				# last resort: the result file is unwritable, so the only
				# place left to say why is the terminal.
				eval { write_result($result, $r); 1 }
					or print STDERR "$0: $version: $@";
				exit 0;
			}
			$kid{$pid} = { version => $version, work => $work,
				result => $result, log => $log };
		}
		last unless %kid;
		my $pid = waitpid -1, 0;
		last if $pid <= 0;
		$reaper->($pid, $?);
	}

	print "-- --stop-on-fail: skipping @queue\n" if $halt && @queue;
	# report in version order, not in the order they happened to finish
	my %by = map { $_->{version} => $_ } @out;
	return map { $by{$_} } grep { $by{$_} } @order;
}

# --------------------------------------------------------------- main loop --

my @results;
my $t_all = time;

if ($in_parallel) {
	printf "-- %d perl(s), %d at a time%s; per-version output goes to the logs\n",
		scalar @run, $par, ($jobs && !$syntax ? " with make -j$jobs each" : '');
	print "-- note: --deps has the children sharing one ~/.cpanm; if a "
		. "prerequisite install misbehaves, run once with -P 1 --deps first\n"
		if $deps;
	@results = run_parallel(@run);
}
else {
	@results = run_serial(@run);
}

# ----------------------------------------------------------------- summary --

my $bad = grep { $_->{failed} } @results;
print "\n", '=' x 72, "\n";
printf "%-16s %-9s %-8s %-8s %-5s %s\n", qw(PERL REPORTED STATUS TIME WARN DETAIL);
print '-' x 72, "\n";
for my $r (@results) {
	printf "%-16s %-9s %-8s %7.1fs %-5s %s\n",
		$r->{version},
		$r->{reported},
		$r->{status},
		$r->{seconds},
		($r->{warnings} || 0),
		# Send the reader to the log only when there is one to read.
		($r->{failed}
			? ($r->{error} || "failed at '$r->{failed}'") . ' - '
				. (-e $r->{log} ? "see $r->{log}" : "log gone: $r->{log}")
			: ($syntax ? 'compiles' : ($r->{result} ? "Result: $r->{result}" : 'no test summary'))),
		;
}
printf "%-16s %-9s %-8s\n", $_, '-', 'SKIP' for @skipped;
print '-' x 72, "\n";
my $not_run = @targets - @results - @skipped;
my @unusable = grep { $_->{status} eq 'DEPS' } @results;
printf "%d/%d perl(s) passed%s%s in %.1fs.  Logs in %s\n",
	scalar(@results) - $bad, scalar(@results),
	(@skipped  ? sprintf(' (%d skipped as older than %s)', scalar @skipped, $min_perl) : ''),
	($not_run  ? " ($not_run not run)" : ''),
	time - $t_all, $log_dir;
# a perl without the prerequisites proves nothing either way about this dist
printf "%d perl(s) could not be tested for missing prerequisites, not for anything\n"
	. "wrong here; re-run with --deps to cpanm them: %s\n",
	scalar @unusable, join ' ', map { $_->{version} } @unusable
	if @unusable;
print "-- built in private trees; this directory is untouched (-P 1 to build here)\n"
	if $in_parallel && !$syntax;

exit($bad || $not_run ? 1 : 0);
