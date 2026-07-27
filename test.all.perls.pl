#!/usr/bin/env perl
# test.all.perls.pl - build & test Matplotlib::Simple against every perlbrew perl.
#
# Matplotlib::Simple claims MIN_PERL_VERSION 5.010, so every release has to
# compile and pass its tests on a perl that predates most of what modern perl
# makes habitual (`each @array`, postfix deref, /r, %h{...}, signatures, ...).
# CPAN Testers finds those regressions days after upload; this finds them now:
#
#     ./test.all.perls.pl                # full build + test, oldest perl first
#     ./test.all.perls.pl --syntax       # seconds, not minutes: compile only
#     ./test.all.perls.pl -p 5.10.1      # just the perl that broke
#
# Each version runs in its own environment (no `perlbrew use` needed: the perl
# binary is invoked directly and PATH is rewritten for the child), the tree is
# cleaned between versions, and a pass/fail summary is printed at the end.
# Exit status is non-zero if any version failed.
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
use File::Spec;
use IO::Handle;
use Cwd 'getcwd';
use File::Find 'find';
use POSIX 'strftime';
use Time::HiRes 'time';

# This script deliberately restricts itself to what perl 5.10 understands, so
# it can be run by whichever perl happens to be first in PATH -- including the
# old one it is testing against.

my $PERLBREW_ROOT = $ENV{PERLBREW_ROOT} || File::Spec->catdir($ENV{HOME}, 'perl5', 'perlbrew');

my ($help, $list, $install, $deps, $stop, $quiet, $jobs, $syntax, $all, @only);
my $clean   = 1;
my $minver  = 1;
my $log_dir = File::Spec->catdir('.build', 'multiperl');

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
	'log-dir=s'     => \$log_dir,
	'quiet|q'       => \$quiet,
	'list|l'        => \$list,
	'help|h'        => \$help,
) or usage(1);
usage(0) if $help;

sub usage {
	my $rc = shift;
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
      --stop-on-fail   abort at the first version that fails
  -j, --jobs N         parallel make, and HARNESS_OPTIONS=j<N> for the tests
      --log-dir DIR    where per-version logs go (default: $log_dir)
  -q, --quiet          only write logs; do not echo build output
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

# numeric sort so the oldest perl is exercised first and the tree is left
# built against the newest one.
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
		printf "%-14s %s%s\n", $t, File::Spec->catfile($perls_dir, $t, 'bin', 'perl'),
			(too_old($t) ? "  (< MIN_PERL_VERSION $min_perl" . ($all ? ', tested anyway)' : ', skipped)') : '');
	}
	exit 0;
}

# ------------------------------------------------------------------ logging --

sub mkdirp {
	my @parts = File::Spec->splitdir(shift);
	my $path = '';
	for my $p (@parts) {
		$path = length($path) ? File::Spec->catdir($path, $p) : $p;
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

# --------------------------------------------------------------- main loop --

my (@results, @skipped);
my $t_all = time;

for my $version (@targets) {
	if (too_old($version) && !$all) {
		push @skipped, $version;
		say "-- $version: SKIP (older than MIN_PERL_VERSION $min_perl; --all to test anyway)";
		next;
	}

	my $root = File::Spec->catdir($perls_dir, $version);
	my $bin  = File::Spec->catdir($root, 'bin');
	my $perl = File::Spec->catfile($bin, 'perl');

	my $log = File::Spec->catfile($log_dir, "$version.$stamp.log");
	open my $logfh, '>', $log or die "$0: cannot write $log: $!\n";
	$logfh->autoflush(1);

	print "\n", '=' x 72, "\n";
	printf "== %s   (log: %s)\n", $version, $log;
	print '=' x 72, "\n";
	print $logfh "== $version at " . strftime('%F %T', localtime) . "\n";

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

	if ($clean && !$syntax && !$failed) {
		# leave a clean tree behind before the next perl takes over
		run_cmd(['make', 'clean'], $logfh) unless $version eq $targets[-1];
	}

	$r{seconds} = time - $t0;
	$r{failed}  = $failed;
	$r{status}  = $failed ? $status : 'PASS';
	close $logfh;

	printf "-- %s: %s in %.1fs%s\n", $version,
		($failed ? "$status at '$failed'" : 'ok'),
		$r{seconds},
		(defined $r{files} ? " ($r{files})" : '');
	print '-- ', $r{error}, "\n" if defined $r{error};
	print '-- ', join('  ', map { sprintf '%s %.1fs', $_->{label}, $_->{seconds} }
	                        @{ $r{steps} }), "\n";
	push @results, \%r;

	if ($failed && $stop) {
		my %done = map { $_->{version} => 1 } @results;
		$done{$_} = 1 for @skipped;
		my @rest = grep { !$done{$_} } @targets;
		print "-- --stop-on-fail: skipping @rest\n" if @rest;
		last;
	}
}

# ----------------------------------------------------------------- summary --

my $bad = grep { $_->{failed} } @results;
print "\n", '=' x 72, "\n";
printf "%-14s %-9s %-8s %-8s %-5s %s\n", qw(PERL REPORTED STATUS TIME WARN DETAIL);
print '-' x 72, "\n";
for my $r (@results) {
	printf "%-14s %-9s %-8s %7.1fs %-5s %s\n",
		$r->{version},
		$r->{reported},
		$r->{status},
		$r->{seconds},
		($r->{warnings} || 0),
		($r->{failed}
			? ($r->{error} || "failed at '$r->{failed}'") . " - see $r->{log}"
			: ($syntax ? 'compiles' : ($r->{result} ? "Result: $r->{result}" : 'no test summary'))),
		;
}
printf "%-14s %-9s %-8s\n", $_, '-', 'SKIP' for @skipped;
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

exit($bad || $not_run ? 1 : 0);
