# Test parity — gnome-font-viewer-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream automated tests | **0** |
| Port automated tests (`spec/*_spec.rb`) | **50**, added since the last round (`349793a`), all passing — re-run this session |
| Port drive-script checks (`test/drive_font_viewer.rb`) | **37**, up from 34 (`260f561` added `--version` and `app.quit`), all passing, re-run this session |

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

**Since the last round, this changed.** The port previously had no
`spec/*_spec.rb` files at all; `349793a` added four:
`font_loader_face_spec.rb`, `open_type_layout_spec.rb`, `info_page_spec.rb`,
`font_thumbnailer_spec.rb`. Re-running the dev shell's own advertised spec
command this session, against the current tree:

```
$ nix develop --command xvfb-run -a ruby -e \
    'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
...
50 examples, 0 failures
```

**This is now a real, executed suite**, not an empty one — the specific gap
the last round flagged ("a test suite that has zero tests in it has never
been executed") is closed. It covers `FontLoader::Face` (font_name,
contains_text?, characters_for_glyphs, charlist, describe_axis,
describe_named_styles, layout_features, sample_string), `OpenTypeLayout`
(name_for/names_for/describe), `InfoPage`'s text-shaping helpers
(`strip_whitespace`/`strip_version`/`compress`), and `FontThumbnailer`'s
fallback-text selection (`text_for`/`default_text`/`ascii_characters`/
`halved`).

**It is still not test *parity*, and the census above already explains why**:
these 50 examples were written for the port, not derived from any upstream
test (upstream has none to derive from), so they are `## Extra` by this
skill's own rule, not a bijection being satisfied. They are also narrower
than the component surface they're named after — `info_page_spec.rb` tests
only the private string-shaping helpers (`strip_whitespace`, `strip_version`,
`compress`), not a single row's label or displayed value, which stays the
gap the table below describes.

Separately, `test/drive_font_viewer.rb` **was run this session** (not merely
inherited as a claim):

```
nix develop --command xvfb-run -a ruby test/drive_font_viewer.rb
...
37 of 37 checks passed
DRIVE OK
```

This matches the runtime gate exactly (37/37, `drive_ok=true`) — that part of
the gate is real and was independently reproduced, not just taken on faith.
Two checks were added since the last round (`260f561`): `--version` exits
successfully and prints the version name/number, and firing `app.quit`
closes the main window.

## Why "37 checks, 16 components, drive OK" is not test parity

This round's runtime gate reports 37 checks passed, 0 failed, across 16
components (up from 34/9 last round — both numbers grew with the two new
checks, and the gate counts components more finely than the table below
groups them). The task brief is right to flag this as a gap in its own right
rather than a pass: a component no check exercises is unverified, not done.
Walking the 37 checks against the component inventory:

| Component | Exercised by the drive script? | What it never touches |
|---|---|---|
| Window / app shell | partial | `<Control>q`/`<Control>w` accelerators, Ctrl+F outside the focus-search action path, the whole `window_bubble_key_event` typeahead-redirect logic (arrow/Tab/space/Menu/Ctrl/Alt passthrough vs. everything else forwarded to the entry) |
| Overview page | yes | — |
| Preview page | yes | — |
| Info page | **thin** | checks only that the page is visible and the header repeats the font name; never asserts a single row's label or value — `Name`, `Location`, `Style`, `Type`, `Version`, `Copyright`, `Glyph Count`, `Color Glyphs`, `Layout Features`, `Variation Axes`, `Named Styles` are all unverified by any check, including the one row (`Variation Axes`) known from this round's other reports to carry a translation gap |
| About dialog | yes (visible only) | version text content (developer name is now covered by the translation re-verification above, but no *drive* check asserts the dialog's displayed developer-name text) |
| Error dialog | yes (heading only) | the body text (and the upstream `show_error` bug about body vs. heading noted in `component-inventory.md`) |
| Font installer | yes | retry-on-collision (`<n>` filename prefix on `EEXIST`), cancellation |
| Thumbnailer CLI | yes (success + two failure paths) | `--text`/`--size` option *values* actually changing the output, a `#fragment` face-index input, a font collection file |
| `FontInscription` / `FontPreviewWidget` custom drawing | **never** | no check asserts anything about what gets drawn — size, baseline, glyph coverage fallback, RTL — only that the widgets exist |
| `FontModel` | partial | "finds the installed fonts" is checked; the fontconfig-watch/live-reload behaviour (`items-changed` on external config change) is not |
| i18n / locale behaviour | **never** | no check runs the app under any locale other than the process default; the catalogue gaps in `TRANSLATION_PARITY.md` are invisible to the runtime gate entirely |
| App shutdown (`app.quit`) | **yes, new this round** | only that the window stops being visible; nothing asserts the process actually exits (return code) |
| `--version` | **yes, new this round** | only exit code and that the output contains the version name/number; nothing asserts `--version`'s absence from `--help` (the gap `component-parity.md` records) |

So "37 checks passed, 16 components" is an accurate count of what ran and an
overstatement of what it proves: several named components are touched by
exactly one shallow check (existence/visibility), and whole behaviour classes
(keyboard typeahead redirection, drawing correctness, locale handling) have
zero checks anywhere in the repository — unchanged from last round except for
the two items the new checks specifically cover.

## Scorecard

| Claim | Holds? |
|---|---|
| Upstream test census matches port test census | Yes, vacuously (0 = 0) |
| The port's actual test suite (`spec/`) has ever been run and found something | **Yes, now** — 50 examples, 0 failures, re-run this session (was empty last round) |
| The drive script passed and was independently reproduced | Yes — 37/37, this session |
| The suite amounts to full coverage of the app's actual behaviour surface | **No** — multiple components and whole behaviour classes (keyboard typeahead, custom drawing, locale/i18n, most info-page row content, retry-on-collision, `--text`/`--size` actually changing output) have no check anywhere, spec or drive |

**Verdict: gap, narrower than last round.** Not on the narrow census
(upstream ported nothing, so there is nothing to be missing), but on the
broader claim the runtime gate invites: 37 green checks plus 50 green
examples is real, reproduced progress — the "empty suite" finding from last
round is closed — but it is not a safety net for the behaviour classes listed
above, none of which gained a single check this round.
