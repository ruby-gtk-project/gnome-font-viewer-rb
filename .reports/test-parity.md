# Test parity — gnome-font-viewer-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream automated tests | **0** |
| Port automated tests (`spec/*_spec.rb`) | **0** |
| Port drive-script checks (`test/drive_font_viewer.rb`) | 34, all passing, run this session |

## The census

`git ls-tree -r --name-only origin/main` and `origin/main`'s `meson.build` /
`src/meson.build` were read directly: there is no `test()` target anywhere in
the build, no `tests/` directory, nothing under `src/` named `*test*`.
**Upstream ships zero automated tests.** The bijection the skill asks for
(every upstream test maps to exactly one port test) is therefore vacuously
satisfiable — 0 maps to 0 — and by the letter of the census this unit is
"ported."

That is the whole of what the census can say, and it is not the whole
picture, because of what sits next to the census:

## What exists instead, and whether it was ever run

The port has **no `spec/*_spec.rb` files at all.** `spec/` contains only
`spec_helper.rb` (harness wiring) and `README.md` (harness documentation).
Running the dev shell's own advertised spec command confirms this directly:

```
$ nix develop --command xvfb-run -a ruby -e \
    'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
```

finds and runs zero examples (there is nothing under `spec/` for RSpec to
collect). **A test suite that has zero tests in it has never been executed
in any meaningful sense — there is nothing to execute.** This is a gap in
its own right, independent of the 0-upstream-tests fact: upstream's having no
unit tests does not mean the port is excused from having any. The usual shape
of a from-scratch GTK port (see the `ruby-gtk-testing` skill and the sibling
pilot port) is unit specs over the non-widget logic — here that would be
`FontLoader`'s sfnt/Type1 parsing, `strip_whitespace`/`strip_version`,
`FontModel`'s weight/slant mapping, `FontThumbnailer`'s fallback-text
selection — none of which has a single example.

Separately, `test/drive_font_viewer.rb` **was run this session** (not merely
inherited as a claim):

```
nix develop --command xvfb-run -a ruby test/drive_font_viewer.rb
...
34 of 34 checks passed
DRIVE OK
```

This matches the runtime gate exactly (34/34, `drive_ok=true`) — that part of
the gate is real and was independently reproduced, not just taken on faith.

## Why "34 checks, 9 components, drive OK" is not test parity

The task brief is right to flag this as a gap in its own right rather than a
pass: a component no check exercises is unverified, not done. Walking the 34
checks against the component inventory:

| Component | Exercised by the drive script? | What it never touches |
|---|---|---|
| Window / app shell | partial | `<Control>q`/`<Control>w` accelerators, Ctrl+F outside the focus-search action path, the whole `window_bubble_key_event` typeahead-redirect logic (arrow/Tab/space/Menu/Ctrl/Alt passthrough vs. everything else forwarded to the entry) |
| Overview page | yes | — |
| Preview page | yes | — |
| Info page | **thin** | checks only that the page is visible and the header repeats the font name; never asserts a single row's label or value — `Name`, `Location`, `Style`, `Type`, `Version`, `Copyright`, `Glyph Count`, `Color Glyphs`, `Layout Features`, `Variation Axes`, `Named Styles` are all unverified by any check, including the one row (`Variation Axes`) known from this round's other reports to carry a translation gap |
| About dialog | yes (visible only) | developer name / version text content |
| Error dialog | yes (heading only) | the body text (and the upstream `show_error` bug about body vs. heading noted in `component-inventory.md`) |
| Font installer | yes | retry-on-collision (`<n>` filename prefix on `EEXIST`), cancellation |
| Thumbnailer CLI | yes (success + two failure paths) | `--text`/`--size` option values actually changing the output, a `#fragment` face-index input, a font collection file |
| `FontInscription` / `FontPreviewWidget` custom drawing | **never** | no check asserts anything about what gets drawn — size, baseline, glyph coverage fallback, RTL — only that the widgets exist |
| `FontModel` | partial | "finds the installed fonts" is checked; the fontconfig-watch/live-reload behaviour (`items-changed` on external config change) is not |
| i18n / locale behaviour | **never** | no check runs the app under any locale other than the process default; the catalogue gaps in `TRANSLATION_PARITY.md` are invisible to the runtime gate entirely |

So "34 checks passed, 9 components" is an accurate count of what ran and an
overstatement of what it proves: several named components are touched by
exactly one shallow check (existence/visibility), and whole behaviour classes
(keyboard typeahead redirection, drawing correctness, locale handling) have
zero checks anywhere in the repository.

## Scorecard

| Claim | Holds? |
|---|---|
| Upstream test census matches port test census | Yes, vacuously (0 = 0) |
| The port's actual test suite (`spec/`) has ever been run and found something | **No** — it is empty |
| The drive script passed and was independently reproduced | Yes — 34/34, this session |
| 34 checks amount to coverage of the app's actual behaviour surface | **No** — multiple components and whole behaviour classes (keyboard typeahead, custom drawing, locale/i18n, info-page row content, retry-on-collision) have no check |

**Verdict: gap.** Not on the narrow census (upstream ported nothing, so there
is nothing to be missing), but on the broader claim the runtime gate invites:
a passing drive script is not a test suite, the port's real test suite is
empty and has never found a single example to run, and several components
the gate counts as "covered" are covered by a visibility check alone.
