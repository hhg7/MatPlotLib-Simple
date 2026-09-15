#!/usr/bin/env perl
# Regenerate SECURITY.md.  Run from the root of the repository:
#
#	perl security.policy.pl > SECURITY.md
#
# SECURITY.md is committed because the tarball needs it (CPANSec's security
# policy, which metacpan links from the distribution page, and the CPANTS
# "has_security_doc" metric) and because dzil has nothing that writes it here:
# Dist::Zilla::Plugin::SecurityPolicy is not installed and pulling in a build
# dependency for one static file is not worth it.  The text itself is not
# hand-written; it is whatever Software::Security::Policy::Individual
# generates, so that the wording tracks upstream's rather than drifting into a
# policy nobody reviewed.  Re-run this after upgrading that module.
#
# Every value below is a promise to whoever reports a vulnerability, so each
# one is a decision, not a default:
use strict;
use warnings FATAL => 'all';
use Software::Security::Policy::Individual;

my $policy = Software::Security::Policy::Individual->new({
	# The author, as dist.ini spells it.  There is one maintainer, so there
	# is nothing to disambiguate and no alias to forward.
	maintainer  => 'David E. Condon <dec986@gmail.com>',
	program     => 'Matplotlib::Simple',
	Program     => 'Matplotlib::Simple',
	# Time to a first reply, not to a fix.  7 days rather than the module's
	# 5-day default because this is a one-maintainer distribution with no CI
	# and no co-maintainer to cover a week away.
	timeframe   => '7 days',
	# Where the canonical copy of this file lives, so a reader of a stale
	# tarball can find the current policy.
	git_url     => 'https://github.com/hhg7/MatPlotLib-Simple',
	url         => 'https://github.com/hhg7/MatPlotLib-Simple/blob/main/SECURITY.md',
	# The module's own floor: lib/Matplotlib/Simple.pm says "require 5.010",
	# and t/ is kept running there (see test.all.perls.pl).  Raising it is a
	# breaking change, so it is stated rather than left to a rolling window.
	minimum_perl_version => '5.10',
});
print $policy->fulltext, "\n";
