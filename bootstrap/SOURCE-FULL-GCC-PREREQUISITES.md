# Source-native full compiler prerequisites

`source-full-gcc-prerequisites.nix` selects ISL 0.28, libxcrypt 4.5.2,
Which 2.21, ncurses 6.6 and Texinfo 7.1. It reconstructs the owned build
base with `source-native-compiler.nix`'s C/C++ compiler. Existing source
GMP, Perl, Python and tools are named explicitly in the composition.
The normal catalogue and default base retain their existing selections.

Build the production outputs:

```sh
nix build --impure --file bootstrap/source-full-gcc-prerequisites.nix \
  isl libxcrypt which ncurses texinfo --no-link
```

Each package has an `evidence` output containing build logs and statuses.
Upstream test logs remain raw, including skips and unsuccessful runs.
An installed production output alone does not imply an upstream suite passed.
The separate installed consumer suite exercises C/C++ interfaces, static ISL,
libxcrypt APIs, command selection, wide curses, terminfo, Info/HTML rendering
and the installed Perl parser XS:

```sh
nix build --impure --file bootstrap/source-full-gcc-prerequisite-tests.nix \
  consumer upstream --no-link
nix eval --impure --json --file bootstrap/source-full-gcc-prerequisite-tests.nix contracts
```

ISL declares GMP as a public development dependency, so a consumer selecting
ISL receives GMP's header and library directories through `base.environment`.
Ncurses retains its wide library, static C++ binding, panel/menu/form interfaces,
compiled terminfo database and terminal tools. Terminfo symbols are provided
by `libncursesw`; this selection does not install a separate `libtinfo`. Its terminfo functionality can
be tested without a terminal using `setupterm` and `newterm`.
Texinfo includes makeinfo, the Info reader, parser XS, Perl modules and
`texmf-dist/tex/texinfo/texinfo.tex`. Building its optional TeX-format tests
requires a separately provided TeX installation; this composition supplies none.

Recipes use explicit builder steps and output operations. Constructor arguments,
base/environment edits and named step edits remain available. Set C and C++
dialects independently in the ncurses recipe. Runtime observers require the
previous native compiler observers before classifying this extension; development
references do not grant permission to load older library generations.

Texinfo applies the existing wide-ncurses and locale-program patches. The local
`perl-5.44-precedence.patch` replaces four ambiguous negated string comparisons
with explicit nonempty filename comparisons. This preserves normal output
selection and supports the filename `0`, while keeping Perl warnings enabled.
Its XS subconfigure receives the selected environment's `CC` through upstream's
`PERL_EXT_CC` override; Perl's recorded construction compiler is not selected.
