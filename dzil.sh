# Release Matplotlib-Simple.  Bump $VERSION in lib/Matplotlib/Simple.pm and
# write the Changes entry under it first (see CLAUDE.md), then:
#
#	sh dzil.sh
#
# "perl Makefile.PL" used to run second, which is why this script had to be run
# twice to leave the repository in a finished state.  The root Makefile.PL is
# not written by hand and is not gathered into the tarball -- dist.ini has
# [Git::GatherDir] exclude it and [MakeMaker] generate its own -- so the only
# place a current one appears is inside Matplotlib-Simple-$VERSION/, which
# "dzil build" writes at the *end* of this script.  Running "perl Makefile.PL"
# before that configured the working copy from the previous release's file, and
# bringing the root copy up to date meant releasing, copying the generated file
# back by hand, and running the script again.  Nobody did: the committed
# Makefile.PL was byte-identical to Matplotlib-Simple-0.301/Makefile.PL through
# five releases, pinning "VERSION" => "0.301" and declaring prerequisites
# (File::Path, Term::ANSIColor) that dist.ini had dropped while missing the
# Scalar::Util 1.22 it had gained -- so "perl Makefile.PL && make test", which
# README and CLAUDE.md both offer, tested against the wrong prerequisites.
# The copy and the configure now happen after the build, in the one run.
set -e

# Regenerates README.pod and the module's POD from README.md, and the example
# block of t/01.all.tests.t from mpl.examples.pl, so it has to run before
# anything is built out of those files.
perl md2pod.pl

# Builds, runs the test suite (TestRelease), asks for confirmation, uploads.
dzil release

# Again, without uploading: this is what leaves Matplotlib-Simple-$VERSION/ and
# its tarball in the working directory, which are committed as the snapshot of
# the release.  It overwrites an existing directory of the same name, so a
# re-run of this script is harmless.
dzil build

# dist.ini takes the distribution version from the module ([VersionFromModule]),
# so read it from the same place rather than from anything dzil leaves behind.
version=$(perl -ne 'if (/^our \$VERSION\s*=\s*["\x27]?([0-9._]+)["\x27]?\s*;/) { print $1; exit }' lib/Matplotlib/Simple.pm)
if [ -z "$version" ]; then
	echo "dzil.sh: no \$VERSION found in lib/Matplotlib/Simple.pm" >&2
	exit 1
fi
if [ ! -f "Matplotlib-Simple-$version/Makefile.PL" ]; then
	echo "dzil.sh: dzil build wrote no Matplotlib-Simple-$version/Makefile.PL" >&2
	exit 1
fi

# The root Makefile.PL is what someone cloning from GitHub runs, so it is the
# one just shipped rather than one from an earlier release.  Commit it with the
# rest of the release.
cp "Matplotlib-Simple-$version/Makefile.PL" Makefile.PL
perl Makefile.PL
