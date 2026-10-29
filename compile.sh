#!/bin/sh
# Install Cn::Plot from this working copy into the perl on PATH, so that
# "use Cn::Plot" works from any directory on this computer:
#
#	./compile.sh            # install prerequisites, build, test, install
#	./compile.sh --notest   # the same without the suite, which takes ~2 minutes
#
# Here that perl is perlbrew's 5.44.0, whose site_perl belongs to this user,
# so nothing needs sudo.  It installs what is in lib/ now, committed or not;
# the module's version stays whatever $VERSION says, so the installed copy is
# told apart from a CPAN release only by its contents.  Not shipped: MANIFEST.SKIP
# keeps it out of the tarball, as it does dzil.sh.
set -e
cd "$(dirname "$0")"

# Built in a copy of Makefile.PL, lib/ and t/ alone, as the tarball would be.  Run
# in the repository, MakeMaker configures every release snapshot (each has its own
# Makefile.PL, and NORECURS=1 did not stop it), and installs every *.pl in the
# root as a module under Cn/ -- both happened on the first runs of this script.
# cpanm --installdeps configures with Makefile.PL as well, so it runs in the copy too.
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
cp -R Makefile.PL lib t "$build"
cd "$build"

# Only what Makefile.PL declares; already-installed modules are left alone.
cpanm --installdeps --notest .

perl Makefile.PL
make
if [ "$1" != "--notest" ]; then
	make test
fi
make install

# Read back from a directory with no lib/ in it, so it is the installed copy that answers.
cd /
perl -MCn::Plot -e 'print "Cn::Plot $Cn::Plot::VERSION is installed at $INC{q{Cn/Plot.pm}}\n"'
