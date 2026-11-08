# Translation parity — gnome-font-viewer-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream keys (msgctxt, msgid) | 207 (47 plain + 160 `"OpenType layout"`) |
| Port keys (`po/gnome-font-viewer-rb.pot`) | 211 (re-verified this round; grew by 2 vs. the previous round's count once the two previously-bare-literal strings were marked) |
| Keys in both, byte-identical | counted below — this round re-verifies which gaps are closed |

Method: `xgettext` run in the dev shell against upstream's actual
`po/POTFILES.in` set (`data/org.gnome.font-viewer.desktop.in.in`,
`.metainfo.xml.in`, `src/font-thumbnailer.c`, `font-view-application.c`,
`font-view-window.c`, `font-view-window.ui`, `main.c`, `open-type-layout.h`,
checked out from `origin/main` into a scratch dir) against the port's shipped
`po/gnome-font-viewer-rb.pot`. The `"OpenType layout"`-context 160 keys match
exactly in both sets — the port's `lib/open_type_layout.rb` carries that
whole table faithfully. **The gaps are all in the 47-key plain context.**

## 1. The key sets are not equal

The port's `po/POTFILES.in` (consumed by the `rxgettext` rake task — see
`Rakefile:177-194`) lists only the `lib/*.rb` files. It does **not** list
`data/org.gnome.font-viewer.desktop.in.in` or
`data/org.gnome.font-viewer.metainfo.xml.in`, even though both files are
present in the port's `data/` directory with upstream's exact text in them.
Upstream's own `po/POTFILES.in` lists both. Consequence: every string in
those two files is permanently invisible to the port's translation catalogue,
regardless of how `_()`-clean the Ruby ever gets. That is **6 keys lost
outright**:

| msgid | Where it actually lives in the port | Translated upstream? |
|---|---|---|
| `View fonts on your system` | `data/org.gnome.font-viewer.desktop.in.in` Comment=, `.metainfo.xml.in` `<summary>` | yes, in all 105 locales |
| `fonts;fontface;` | `data/org.gnome.font-viewer.desktop.in.in` Keywords= | yes (semicolons preserved per-locale) |
| `Main Window` | `.metainfo.xml.in` first screenshot `<caption>` | yes |
| `Font Preview` | `.metainfo.xml.in` second screenshot `<caption>` | yes |
| `Font Search` | `.metainfo.xml.in` third screenshot `<caption>` | yes |
| `The GNOME Project` (as it appears via `<developer_name>`/`<name>`) | same file | yes |

Fix: add both files to `po/POTFILES.in` and regenerate, exactly as upstream's
`po/POTFILES.in` already shows is required. This is not a binding limitation
— nothing stops a `.desktop.in.in`/`.metainfo.xml.in` file from being
`xgettext`'d; upstream's own build does it with the identical files.

## 2. Two bare-literal strings — RESOLVED since the last round

`349793a` wrapped both in `_()`, re-verified this round by reading the
current source directly:

- `lib/about_dialog.rb:21` — now `DEVELOPER_NAME = _('The GNOME Project')`.
  Byte-identical to upstream's `_("The GNOME Project")`.
- `lib/font_view_application.rb:37` — now `VERSION_NAME = _('GNOME Fonts')`.
  Byte-identical to upstream's `_ ("GNOME Fonts")`.

Both keys now appear in `po/gnome-font-viewer-rb.pot` and were merged into all
105 `po/*.po` files by the same commit (verified: `git show --stat 349793a`
touches all 105 `.po` files plus the two `lib/` files). **No longer a gap.**

## 2b. The thumbnailer's three metavars — RESOLVED since the last round

`349793a` also split `TEXT`, `SIZE` and `FONT-FILE OUTPUT-FILE` into their own
`_()`-marked constants (`lib/font_thumbnailer.rb:42-51`:
`TEXT_METAVAR = _('TEXT')`, `SIZE_METAVAR = _('SIZE')`,
`POSITIONAL_METAVAR = _('FONT-FILE OUTPUT-FILE')`), matching upstream's three
separate `N_()` markers one for one, and builds the `Usage:` banner by
interpolating `POSITIONAL_METAVAR` rather than inventing a new sentence
(`lib/font_thumbnailer.rb:53`: `USAGE = "Usage: #{PROGRAM_NAME} [OPTION…]
#{POSITIONAL_METAVAR}"`) — same shape as upstream, which also never marks the
banner itself. **No longer a gap.**

## 3. One upstream msgid was reworded and the spacing was restored this round — one sibling string still does not match

`src/font-view-window.c:197`:
```
msgid "%s %g — %g, default %g"
```
(note: thin spaces, U+2009, flank the em dash — not plain spaces)

`lib/font_loader.rb:101` (re-read this round):
```
AXIS_FORMAT = _("%<name>s %<minimum>g — %<maximum>g, default %<default>g")
```
Byte-checked with `od`: the em dash is flanked by U+2009 thin spaces
(`e2 80 89 e2 80 94 e2 80 89`), matching upstream's
`g_strdup_printf (_ ("%s %g — %g, default %g"), ...)` exactly. `349793a`
restored this; **the spacing half of this gap is closed**. The format is
still converted from positional (`%s`/`%g`) to named
(`%<name>s`/`%<minimum>g`) for Ruby's `sprintf`, which is legitimate and
necessary and is why this remains a different key from upstream's — this
report still records it as not byte-identical for that reason, but it is no
longer the compounded, double-broken gap the previous round found (wrong
spacing *and* wrong key shape); it is now only the key-shape difference that
every name-based `sprintf` conversion in this port necessarily has.

A sibling string — upstream's `_("Instance %d")` — was rewritten the same
way, to `_('Instance %<position>d')` (`lib/font_loader.rb:104`, unchanged
this round). Checked across `fr`, `de`, `es`, `ja`, `ru` and `pl`: this one
**was** re-translated by hand after the rewrite (`"Instanz %<position>d"`,
`"Instancia %<position>d"`, etc., all live, none obsolete) — the key is
still technically not byte-identical to upstream's `"Instance %d"`, so it
remains a key-set mismatch by the letter of the rule, but it carries no
lost-translation damage. **Still open, unchanged since last round.**

## 4. Fourteen keys exist in the port with no upstream counterpart

`lib/info_page.rb`'s `CONTENT_TYPE_DESCRIPTIONS` marks fourteen new strings
(`TrueType font`, `OpenType font`, `SFNT font`, `Font collection`, `WOFF
font`, `WOFF2 font`, `TrueType XML font`, `PostScript Type 1 font`, `PCF
font`, `BDF font`, `SNF font`, `Speedo font`, `Linux PSF console font`,
`Embedded OpenType font`). None of these is a key in upstream's catalogue —
upstream's `Type` row comes from `g_content_type_get_description()`, backed by
shared-mime-info's own translation catalogue, not `gnome-font-viewer`'s. The
substitution is reasonable (no Ruby binding exposes that GIO call) and is
documented in the source, but by `translation-parity`'s own rule ("the key
sets are equal... not the same strings roughly") these are still **extra
keys**, and per the project's own `.po` files they ship with `msgstr ""` in
every locale that doesn't happen to already have that exact English string —
i.e. they are English-only in the port, upstream's equivalent copy was
localised by shared-mime-info, and the two never actually said the same thing
in any language: this is a translation regression even though it is a
component the port had no better way to build.

## 6. `--version`'s own `GOptionEntry` description — never reaches the catalogue

Upstream's `main.c` declares `--version` as a `GOptionEntry` with
`N_("Show the application's version")` as its description, which appears in
upstream's `--help` output and is a key in upstream's catalogue. The port's
`lib/font_view_application.rb#run` (still unchanged this round, re-read at
lines 59-66) special-cases `argv.include?('--version')` ahead of
`OptionParser`/`Gio::Application` entirely, so there is no help-entry
component on the port side for this string to attach to. Checked
`po/gnome-font-viewer-rb.pot`: the key is absent. **Gap**, tied to the same
component gap `component-parity.md` records on the application unit.

## 5. Languages / catalogue mechanics — no gap found

- `po/LINGUAS`: 105 entries, byte-for-byte identical ordering to upstream's
  105 (upstream's own `LINGUAS` file currently lists 105 locales, not the 107
  an earlier draft of `.reports/component-inventory.md` stated — recounted
  directly for this report).
- `po/*.po` file count: 105, one per `LINGUAS` entry, matching upstream 1:1.
- The 160 `"OpenType layout"`-context feature names: full parity, msgctxt and
  msgid both byte-identical in every case checked.
- `lib/translation.rb` wires `bindtextdomain`/`textdomain` the way
  `main.c` does.

## This round's deltas

Re-run against the current tree (`git log` shows two commits landed since the
reports were last written: `349793a` "Fix translation gaps and add unit
specs...", `260f561` "test: drive --version..."). Verified by reading the
current source and the commit diffs, not by trusting the commit message:

| From last round | State now |
|---|---|
| `DEVELOPER_NAME` bare literal | **fixed** — `_()`-wrapped, re-verified |
| `VERSION_NAME` bare literal | **fixed** — `_()`-wrapped, re-verified |
| Axis format string: wrong spacing (plain spaces, not thin spaces) | **fixed** — byte-checked, matches upstream's U+2009-flanked em dash |
| Axis format string: named vs. positional placeholders | **still open** — different key from upstream by necessity of the `sprintf` conversion, as explained above |
| Thumbnailer `TEXT`/`SIZE`/usage metavars merged into one invented string | **fixed** — three separate `_()` markers matching upstream's three `N_()` markers |
| POTFILES.in omits `.desktop.in.in`/`.metainfo.xml.in` (6 keys) | **unchanged, still open** |
| `Instance %d` → `Instance %<position>d` key mismatch | **unchanged, still open** |
| 14 invented `CONTENT_TYPE_DESCRIPTIONS` keys | **unchanged, still open** |
| `--version`'s own `GOptionEntry` help string | **unchanged, still open** (new row this round, §6 above — present last round only as a `component-parity.md` finding, now also recorded here as the translation-key gap it also is) |

## Scorecard

| Claim | Holds? |
|---|---|
| Key sets equal | **No** — 6 keys unreachable (POTFILES.in gap), 1 key never marked (`--version`'s help string), 1 key reworded into a different key by necessity (`Instance %d`), 14 keys added that upstream never had. (The two bare-literal gaps and the axis-string spacing gap from last round are fixed.) |
| Each key byte-identical | Yes for everything checked except `Instance %<position>d` and the axis format's named-vs-positional shape (both necessary consequences of porting a C format string to Ruby's `sprintf`, not porting mistakes) |
| Languages ship unchanged | Yes — `LINGUAS` and the 105 `.po` files are present and match upstream's locale list |

**Verdict: gap.** Four of the seven gaps this review previously confirmed are
now fixed and independently re-verified. Three remain open: the POTFILES.in
omission (6 keys), the `Instance %d` key-shape mismatch (1 key), and the 14
invented content-type keys — plus one gap newly written down here that was
previously recorded only on the component side, the missing `--version` help
string (1 key). None of the open items is excused anywhere in the source or
in this file; each is stated as a plain gap.
