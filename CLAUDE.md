# Matplotlib::Simple

A Perl module that turns a Perl data structure into a Python 3 script using
matplotlib, writes that script to a temporary file, and (unless `execute => 0`)
runs it. The Perl side is a code generator; the real output is Python.

The global `~/.claude/CLAUDE.md` comment doctrine applies here in full. Perl
source is indented with tabs.

## Windows is a supported platform

This is the rule that governs every other decision in this file.

The distribution is uploaded to CPAN, and CPAN Testers smokes it on Strawberry
Perl under Win10 as well as on unix. **There is no CI in this repo, and no
Windows machine to test on** — the only Windows signal arrives as a FAIL report
by email, days after the release is already public and indexed. Portability is
therefore maintained by review, not by a test run: assume nothing you write
will be exercised on Windows before users see it.

0.312 shipped `File::Temp->new(DIR => '/tmp', ...)`. Windows has no `/tmp`, so
every single call to `plt()` died before writing a byte, and 131 of 166
subtests failed. One hardcoded path took down the whole distribution.

### Rules

**Never hardcode `/tmp`, or any absolute path, in `lib/` or `t/`.** Use
`File::Spec->tmpdir` (which is `/tmp` on unix, so unix behaviour is unchanged)
or `File::Temp`'s `tempdir`. This applies to test output files as much as to
the generated script: `'output.file' => '/tmp/foo.svg'` in a test is the same
bug wearing a different hat.

**Never interpolate a filesystem path into the generated Python.** A Windows
path is `C:\cpan\build\...`, and inside a Python string literal `\b` is a
backspace and `\c` is an invalid escape — a SyntaxWarning in Python 3.12 and a
SyntaxError from 3.15. An apostrophe anywhere in the path closes the literal
early on any platform. Two ways to get this right, both already in the module:

- `py_str($str)` renders a Perl string as an escaped Python literal. Use it for
  anything short that must land in the script as text — labels, metadata.
- `write_data({ data => ..., fh => ..., name => ... })` serialises to JSON,
  base64-encodes it, and emits a `json.loads(base64.b64decode(...))` line. Use
  it for data, and for the output filename, which already goes through it.

**Assume `/` and `\` are both path separators, and that a path may contain
spaces.** `%TEMP%` on the smoker is `C:\Users\smoker\AppData\Local\Temp`.
Perl accepts `/` on Windows and so does Python, so building a path with `/` is
fine; *parsing* one by splitting on `/` is not.

**Keep the platform gates in the test suite honest.** A test that needs
python3, matplotlib, or matplotlib_venn must `skip_all` or skip its block when
the dependency is absent — a Windows smoker usually has none of the three, and
a missing dependency must produce a SKIP, never a FAIL. Everything that does
not need Python (`execute => 0`, the option contract, the string escaping)
must still run there, because that is the part Windows actually breaks.

### Known Windows gaps

Both are latent: they cannot fail on a smoker with no Python, so they have
never shown up in a report. Fix them if you touch the surrounding code, and do
not add anything that depends on their current shape.

- The module runs `python3`, which does not exist in a stock Windows Python
  install — it is `python`, or the `py` launcher. On Windows the module is
  currently untested and non-functional whenever Python *is* present.
- `system('python3 ' . $fh->filename)` is the one-argument form, so it goes
  through the shell and splits on whitespace. A temp path containing a space
  breaks it. The list form `system('python3', $fh->filename)` does not.

## Layout

- `lib/Matplotlib/Simple.pm` — the entire module, including its POD.
- `t/01.all.tests.t` — end-to-end; needs python3 and matplotlib, `skip_all`
  without them.
- `t/02.interface.t` — the `p` calling interface, automatic subplot geometry,
  and a rendered-SVG sanity check.
- `t/03.coverage.t` — every plot type, option, and data shape; mostly
  `execute => 0`, with a render layer that needs matplotlib >= 3.10.
- `t/04.options.t` — the option contract: each documented option is accepted,
  reaches the generated Python, and is refused by the types that do not list it.
- `t/05.generated.python.t` — parses every generated script with Python's own
  parser. Needs python3 but not matplotlib.
- `t/utf8.mojibake.t` — labels arriving as raw utf8 bytes rather than wide
  characters.
- `Matplotlib-Simple-0.3*/` and the matching `.tar.gz` — snapshots of past
  releases, committed for reference. **Do not edit them and do not include them
  in a repo-wide search-and-replace**; `MANIFEST.SKIP` keeps them out of the
  next tarball.
- `*.pl` in the root — the author's scratch and example scripts, also excluded
  from the tarball.

## Running the tests

    prove -Ilib t/

The full suite is 562 tests in about 40 seconds on a machine with python3 and
matplotlib. `perl Makefile.PL && make test` also works.

## Releasing

`$VERSION` in `lib/Matplotlib/Simple.pm` is the source of truth — `dist.ini`
uses `[VersionFromModule]`. Bump it there, add a `Changes` entry under that
version, then:

    sh dzil.sh    # md2pod.pl, Makefile.PL, dzil release, dzil build

`md2pod.pl` regenerates `README.pod` from `README.md`; edit the markdown, not
the POD.

A `Changes` entry says what was wrong and what the user will now observe, in
the same voice as the existing entries — not "fixed a bug". When the entry is
about a platform, name the platform and the report that found it.
