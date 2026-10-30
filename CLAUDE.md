# Matplotlib::Simple

A Perl module that turns a Perl data structure into a script that draws it --
Python 3 with matplotlib by default, or with `engine => 'gnuplot'` or
`engine => 'ggplot2'` a gnuplot or R script -- writes that script to a
temporary file, and (unless `execute => 0`) runs it. The Perl side is a code
generator; the real output is the script.

Until 0.33 it drew with matplotlib alone. The split into a front end and
engines is described under [Engines](#engines).

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
the generated script: `output_file => '/tmp/foo.svg'` in a test is the same
bug wearing a different hat.

**Never interpolate a filesystem path, or any text, into a generated script.**
A Windows path is `C:\cpan\build\...`, and inside a Python string literal `\b`
is a backspace and `\c` is an invalid escape — a SyntaxWarning in Python 3.12
and a SyntaxError from 3.15. An apostrophe anywhere in the path closes the
literal early on any platform. Each engine has its escaper, and every label,
key and output path goes through it:

- matplotlib: `py_str($str)` (in `lib/Matplotlib/Simple.pm`, since `frame_to_data` uses
  it too) renders a Perl string as an escaped Python literal; use it for
  anything short that must land in the script as text — labels, metadata.
  `write_data({ data => ..., fh => ..., name => ... })` serialises to JSON,
  base64-encodes it, and emits a `json.loads(base64.b64decode(...))` line. Use
  it for data, and for the output filename, which already goes through it.
- gnuplot: `gp_str`. Data goes into datablocks of numbers only; text reaches
  the script through `gp_str` in tics and label commands, under `noenhanced`
  so that `@ & ^ _ {` read as written.
- ggplot2: `r_str`, which writes every non-ASCII character as `\u{...}` so that
  the script is pure ASCII and Rscript reads it the same in any native
  encoding, as it must on Windows. `svg()`, `png()` and `cairo_pdf()` read a
  `%` in the file name as a format, so the output path has its `%`s doubled.
  The data are R literals: the engine depends on ggplot2 and base R alone,
  not jsonlite or base64enc.

**Assume `/` and `\` are both path separators, and that a path may contain
spaces.** `%TEMP%` on the smoker is `C:\Users\smoker\AppData\Local\Temp`.
Perl accepts `/` on Windows and so does Python, so building a path with `/` is
fine; *parsing* one by splitting on `/` is not.

**Keep the platform gates in the test suite honest.** A test that needs
python3, matplotlib, matplotlib_venn, gnuplot or R with ggplot2 must
`skip_all` or skip its block when the dependency is absent — a Windows smoker
usually has none of them, and a missing dependency must produce a SKIP, never
a FAIL. `t/17` gates its renders on gnuplot 5.2 (`reset session` and the
`bins` filter, read from gnuplot's NEWS; only 6.0 has run them), and `t/18` on
ggplot2 3.5.0 (the `transform` argument of the position scales and
`geom_boxplot(staplewidth=)`), which the R script also checks for itself. Everything that does
not need Python (`execute => 0`, the option contract, the string escaping)
must still run there, because that is the part Windows actually breaks.

**Ask the module which Python to run; never name `python3` in a test.** Every
gate uses `my @PY = Matplotlib::Simple::Matplotlib::python_command()`, which is what `plt`
itself runs, so a Windows smoker that *does* have Python tests the module with
it rather than skipping. Run it in the list form, `system(@PY, ...)`, and keep
double quotes out of the arguments: Perl on Win32 builds the command line for
list-form `system` by wrapping arguments with spaces in double quotes, and does
not escape double quotes already inside them. That is why the parser checks
spell `encoding='utf-8'` with single quotes.

### Which Python the module runs

`python_command()` decides. Everywhere but MSWin32 it is `python3`, unsearched,
as it has always been. On MSWin32, where a stock install has no `python3`, it
is the first of `python`, `py -3` and `python3` whose `--version` says
Python 3; `--version` is checked rather than trusting that the name resolves,
because Windows 10 and 11 install a Microsoft Store stub as `python.exe` that
prints "Python was not found" and exits 9009. The answer is cached in the
package variable `$Matplotlib::Simple::Matplotlib::python_command` (undef = not yet
looked for, `[]` = none found), which `t/08.python.interpreter.t` sets to drive
the search with stand-in interpreters under `local $^O = 'MSWin32'`. Until
0.315 the module ran `python3` unconditionally, so on Windows it could not run
its script wherever Python *was* installed; that never showed up in a report
because the smokers have no Python.

`$ENV{MATPLOTLIB_SIMPLE_PYTHON}`, when set and not empty, comes before all of
that (as of 0.317): it is the interpreter, as one path, neither searched for
nor checked, and never split on spaces. It exists for machines whose `python3` is too old,
such as an HPC cluster whose system Python is 3.6.8 with matplotlib 3.0, where
a venv or `module load` provides a newer one. The tests that drive the search
`local`ise it away so that a caller's setting cannot decide them. gnuplot
and R are found the same way, through `program_from_env`:
`$ENV{MATPLOTLIB_SIMPLE_GNUPLOT}` or `gnuplot`, `$ENV{MATPLOTLIB_SIMPLE_RSCRIPT}` or `Rscript`,
with no search on Windows.

### A matplotlib gate is a version gate

The generated script asks for `layout = 'constrained'`, which matplotlib
refuses before 3.5, so "matplotlib imports" is not a sufficient gate for
anything that renders. Every test that runs a script requires matplotlib
>= 3.10, parsed from `matplotlib.__version__`. Until 0.317, `t/07` and `t/09`
checked only the import, and 9 tests failed against matplotlib 3.0 on that
cluster, which stopped the module from installing.

An older gap, closed in 0.313: `system('python3 ' . $fh->filename)` in the
one-argument form went through the shell and split on whitespace, so a temp
path containing a space broke it. The call is now
`system(@python, $fh->filename)`. Do not write the one-argument form back.

## `write_data` runs on whichever JSON backend is installed

JSON::MaybeXS uses Cpanel::JSON::XS if it can, else JSON::XS (>= 3.0), else
JSON::PP, and they disagree about a scalar that is both a number and a string.
JSON::XS 4.04 writes such a dualvar as a string; Cpanel::JSON::XS 4.43 and
JSON::PP 4.16 write it as a number. Perl hands out dualvars where you would not
expect one -- `scalar @empty` is a 0 that also carries the string "0" -- and a
single string in an image makes numpy read the whole of it as text. That broke
`imshow` with a `stringmap` on HitList's conda install in 0.318, and was first
blamed on numpy 2.5.3.

So a number bound for `write_data` is built as a number (`0 .. $#list`, or
`0 + $x`), and a change to what reaches it is run under JSON::XS as well as the
default. Hiding Cpanel::JSON::XS makes JSON::MaybeXS fall back to JSON::XS:

    echo 'unshift @INC, sub { die "hidden\n" if $_[1] eq "Cpanel/JSON/XS.pm" }; 1;' > /path/HideXS.pm
    PERL5OPT="-I/path -MHideXS" prove -Ilib t/

Block 29 of `t/12.review.fixes.0.319.t` tries each installed backend in turn.

## The module does not use `autodie`

The module (then `lib/Matplotlib/Simple.pm`) opened with `use autodie ':all'`
until 0.313, when it was removed at the maintainer's request. The behaviour was required not to
change with it, and that is the standing rule: **every builtin `autodie` was
checking has to check itself**, so that nothing which used to die now quietly
returns false and carries on.

`:all` is the union of every tag in `%TAGS` (perl 5.44.0's `Fatal.pm` line 89,
autodie 2.37): `open`, `close`, `binmode`, `mkdir`, `unlink`, `opendir`,
`rename`, `system`, `exec` and the rest. The module only ever called two of
them, and both now check their own result:

- `binmode($fh, ':encoding(UTF-8)') or die ...`, keeping autodie's own wording,
  `Can't binmode($fh, ':encoding(UTF-8)'): <$!>`.
- `system(@python, $fh->filename)`, whose return value is sorted into the
  same three cases autodie distinguished — failed to start, died to a signal,
  non-zero exit. Since 0.33 that is `run_script` in `lib/Matplotlib/Simple.pm`, which
  every engine runs its interpreter through, and the `binmode` is in
  `script_handle` there; the two traps below are about that code.

If you add a call from that list, check it in the same edit. `die` on failure;
do not add `autodie` back.

### Two traps, both of which bit once

- `warnings FATAL => 'all'` makes a failed exec fatal *at* the `system()` call,
  so `system` never returns -1 and the "failed to start" branch is unreachable.
  The call carries a statement-scoped `no warnings 'exec'` so that all three
  failure modes come out of one place, worded one way. Don't drop it without
  moving the message.
- `$!` has to be read **inside** the `capture { }` block. `Capture::Tiny` does
  its own file operations on the way out and overwrites it; read after
  `capture` returns, the message came out as `failed to start:` with nothing
  after it.

### `autodie` was hiding the Python traceback

autodie's `system` threw from *inside* `capture { }`, so the `$exit != 0`
branch under it — the one that prints the captured STDOUT and STDERR — was
never reached. A generated script that failed to run reported
`"python3" unexpectedly returned exit value 1 at .../Capture/Tiny.pm line 382`
and discarded the Python error, which is the only thing that says which option
was at fault. Removing `autodie` is what made that branch live. Keep the
captured output in the message.

### The test suite still uses it, at `:default`

`t/01.all.tests.t` uses `autodie ':default'`, and so do `t/debug.pl` and
`t/make.SHA.sum.pl` (neither of which ships — `MANIFEST.SKIP` excludes every
`.pl` but `Makefile.PL`).

**Do not put `:all` back in a test.** `:all` loads `IPC::System::Simple` at
compile time whether or not any `system()` is ever fatalised — verified by
hiding the module from `@INC`, where `use autodie ':default'` loads and
`use autodie ':all'` dies with "IPC::System::Simple required for
Fatalised/autodying system()". `t/01.all.tests.t` asked for `:all` while
calling only `open`, `close`, `mkdir` and `unlink`, all of which `:default`
covers, so the tag cost a non-core prerequisite and bought nothing.
`IPC::System::Simple` was dropped from `dist.ini` in 0.313; a test that needs
`:all` has to put it back.

`autodie` itself is declared under `[Prereqs / TestRequires]`, not as a runtime
prerequisite: `lib/` has not used it since 0.313. It is still declared at all
because it is core only from perl 5.010001, and this distribution supports
5.010.

That is the general rule for `dist.ini`: **`[Prereqs]` is what the modules
under `lib/` load, and nothing else.** Anything only `t/` needs
— `autodie`, `Test::More`, `Test::Exception` — goes under
`[Prereqs / TestRequires]`, so that installing the module does not drag in the
suite's dependencies. The check is cheap: hide the test-only modules from
`@INC` and render a plot.

    perl -e 'BEGIN { unshift @INC, sub {
        die "hidden\n" if $_[1] =~ m{^(autodie|Test/More|Test/Exception)\.pm$} } }
        use lib "lib"; use Matplotlib::Simple;
        bar(output_file => "/tmp/x.svg", data => { A => 1, B => 2 })'

The scripts in the repository root and in `t/` that are not `.t` files
(`md2pod.pl` uses `Test::More`, `Markdown::To::POD`, `HTML::Table` and more)
declare nothing: they do not ship, so their dependencies are the author's
problem, not an installer's.

## Engines

`plt` is a front end. `lib/Matplotlib/Simple.pm` takes the caller's arguments, folds `p`
and `df` into plots, runs every check that does not depend on what draws the
figure, and then hands it to the module `%engine_module` names for `engine`
(matplotlib unless it says otherwise), whose `render($args, $context)` writes
the script, runs it, and returns its path. The interface is in the comment
above `%engine_module`.

The keywords are matplotlib's names throughout, because they were
Matplotlib::Simple's, and a program written for it must run unchanged. That
decides the rest:

- **An engine declares what it draws, and the front end refuses the rest by
  name** (`check_engine`): `%types` (each type and the keywords of `%opt` it
  reads for it), `@plot_keywords` and `@figure_keywords`. Nothing is ever
  silently left out of a figure. Declare a keyword only once the engine
  draws it; a combination the engine cannot draw is refused from its
  `render`, by name. `Matplotlib::Simple::Matplotlib` sets `$draws_everything` instead.
- **Values are read as matplotlib reads them**, by the front end's readers:
  `plain_text` (text that would be Python to matplotlib is read as Python),
  `color_hex` (matplotlib's color names, from `Colors.pm`, never the engine's
  own, which differ), `colormap_colors`, `axis_limits` and `axis_scale`. An
  engine never writes a caller's value without one of them.
- **`style`** is `'native'` (the default, matching the engine: its own
  palette, statistics and theme) or `'matplotlib'` (the engine draws what
  matplotlib draws, its statistics computed in Perl as numpy and scipy compute
  them). The tests of an engine's matplotlib style name it, since 0.33's
  default changed from it before release. What the caller
  gave -- data, key order, a `color` or `cmap`, labels, ranges, log scales,
  size -- is drawn the same under both. Under matplotlib the two styles must
  write the same script, byte for byte; `t/19` checks it. A change to an
  engine's matplotlib style is checked by rendering the same figure with
  matplotlib and comparing the PNGs by eye: the test suite checks that a
  figure is drawn and what its script says, not what it looks like.
- `engine` and `style` belong to the whole figure, and are refused in a
  subplot or an `add` graph (`refuse_subplot_choices`).

The helpers of `Matplotlib::Simple::Matplotlib` reach the front end's checks and keyword
lists through aliases made in its `BEGIN` block, so a list changed in
`lib/Matplotlib/Simple.pm` is the list the helpers check against. `lib/Matplotlib/Simple.pm`
requires the matplotlib engine at its end, after its own subs are compiled;
the other engines are loaded when a figure first asks for one.

## Layout

- `lib/Matplotlib/Simple.pm` — the front end and the POD: `plt` and its wrappers, every
  check of the arguments, `p` and `df`, and the subs the engines share.
- `lib/Matplotlib/Simple/Matplotlib.pm` — the matplotlib engine, the default: every
  `*_helper`, `plot_args`, `write_data`, `python_command` and `render`.
- `lib/Matplotlib/Simple/Gnuplot.pm`, `lib/Matplotlib/Simple/Ggplot2.pm` — the other two engines.
- `lib/Matplotlib/Simple/Colors.pm` — matplotlib's named colors and 36 colormaps, for the
  engines that are not matplotlib. Generated by `make.colors.pl` in the root
  from the python3 on PATH; re-run it with `perl make.colors.pl`, never edit
  the module by hand.
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
- `t/06.escaping.and.validation.t` — data keys as text that must be escaped,
  and data that must be refused by name rather than reaching Python.
- `t/07.review.fixes.t` — one block per fix of 0.315, including that `plt`
  leaves the caller's hashes and data exactly as it was given them.
- `t/08.python.interpreter.t` — which Python `plt` runs on MSWin32 and
  elsewhere, and that it passes the script path whole.
- `t/09.review.fixes.0.316.t` — one block per fix of 0.316, in the form of
  `t/07.review.fixes.t`.
- `t/10.review.fixes.0.317.t` — one block per fix of 0.317, in the same form.
- `t/11.data.frames.t` — `df`: each of the four frame shapes turned into each
  plot type's `data`, mostly by calling `frame_to_data` directly, so it runs
  without Python.
- `t/12.review.fixes.0.319.t` — one block per fix of 0.319, in the form of
  `t/10.review.fixes.0.317.t`.
- `t/13.plot.y.only.t` — `plot` with hash sets given as y values alone, drawn
  against 0 .. n-1, in the form of `t/12.review.fixes.0.319.t`.
- `t/14.review.fixes.0.32.t` — one block per fix of 0.32, in the form of
  `t/12.review.fixes.0.319.t`.
- `t/15.tooltips.t` — `scatter`'s `tooltips`: the option contract without
  Python, and, rendered, that each `<title>` lands on its own point and that
  the script which draws the label on hovering is in the SVG. Whether a
  browser *shows* it is not tested: that was checked by hand in headless
  Chromium and Firefox, moving the pointer over each point and taking a
  screenshot, because a `<title>` alone showed nothing in either in 0.321.
- `t/16.creator.t` — the `Creator` note in a saved figure (an SVG's
  `dc:title`), which ends with the user and host that ran the script, and
  that an SVG carries no DOCTYPE and no other `dc:` metadata. Also the same
  note in an SVG from gnuplot, which Perl adds once gnuplot has run
  (`creator_svg`), and from ggplot2, whose R script adds it itself
  (`creator_code`); both lay it out with `svg_creator_metadata` in
  `lib/Matplotlib/Simple.pm`, as matplotlib does. `t/18` leaves the R script's part out
  of its pinned digests.
- `t/17.gnuplot.t`, `t/18.ggplot2.t` — each engine: its option contract,
  escaping and every data shape with `execute => 0`, so they run on Windows;
  then, gated on the engine, every type rendered in both styles. `t/18` also
  runs R's parser over every script it writes, and pins the checksums of a
  dozen matplotlib-style scripts (`MATPLOTLIB_SIMPLE_PRINT_PINS=1` prints the current
  ones).
- `t/19.engines.t` — the front end's part: `engine` and `style`,
  `check_engine`'s refusals, the readers of text, colors, colormaps and axis
  ranges, and that every module carries Matplotlib::Simple's `$VERSION`. Needs nothing
  but Perl.
- `t/utf8.mojibake.t` — labels arriving as raw utf8 bytes rather than wide
  characters.
- `Matplotlib-Simple-0.3*/` and the matching
  `.tar.gz` — snapshots of past releases, committed for reference. **Do not edit them and do not include them
  in a repo-wide search-and-replace**; `MANIFEST.SKIP` keeps them out of the
  next tarball.
- `*.pl` in the root — the author's scratch and example scripts, also excluded
  from the tarball.

## Running the tests

    prove -Ilib t/

The full suite is 2122 tests in about 125 seconds on a machine with python3,
matplotlib, gnuplot and R with ggplot2. `perl Makefile.PL && make test` also
works.

## Releasing

`$VERSION` in `lib/Matplotlib/Simple.pm` is the source of truth — `dist.ini` uses
`[VersionFromModule]`. Bump it there **and in the four modules under
`lib/Matplotlib/Simple/`** — PAUSE indexes each package by its own version, and
`t/19.engines.t` fails until they agree — add a `Changes` entry under that
version, then:

    sh dzil.sh    # md2pod.pl, Makefile.PL, dzil release, dzil build

`md2pod.pl` regenerates the POD at the end of `lib/Matplotlib/Simple.pm` from
`README.md`, and the example block of `t/01.all.tests.t` from `mpl.examples.pl`;
edit those two, not what is generated from them. There is no `README.pod`:
it was only ever a scratch copy, which the tarball never shipped, and was
removed in 0.319.

A `Changes` entry says what was wrong and what the user will now observe, in
the same voice as the existing entries — not "fixed a bug". When the entry is
about a platform, name the platform and the report that found it.
