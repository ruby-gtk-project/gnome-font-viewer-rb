# Translation parity — gnome-font-viewer-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream keys (msgctxt, msgid) | 207 (47 plain + 160 `"OpenType layout"`) |
| Port keys (`po/gnome-font-viewer-rb.pot`) | 211 |
| Keys in both, byte-identical | counted below |

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

## 2. Two strings are hand-coded past the gettext layer, independent of (1)

These matter even once POTFILES.in is fixed, because the Ruby source itself
never calls `_()` on them:

- `lib/about_dialog.rb:19` — `DEVELOPER_NAME = 'The GNOME Project'`. Upstream:
  `_("The GNOME Project")` (used as `adw_show_about_dialog`'s
  `developer-name`). Bare Ruby string literal: **0 of 105 locales translate
  the About dialog's developer name**, even the ones that already have the
  string in their catalogue for the metainfo use above.
- `lib/font_view_application.rb:37` — `VERSION_NAME = 'GNOME Fonts'`. Upstream:
  `_ ("GNOME Fonts")`, printed by `--version`. Same defect: `--version`'s
  output is English-only in the port, in all 105 locales.

## 3. One upstream msgid was reworded and silently lost its translations

`src/font-view-window.c:197`:
```
msgid "%s %g — %g, default %g"
```
(note: thin spaces, U+2009, flank the em dash — not plain spaces)

`lib/info_page.rb:98` / `po/*.po`:
```
msgid "%<name>s %<minimum>g — %<maximum>g, default %<default>g"
```
(plain spaces, named placeholders)

These are two different keys. Verified directly in `po/fr.po`: the old
msgid's French translation (`"%s %g — %g, %g par défaut"`) is still in the
file but demoted to an obsolete `#~` entry (line 1084), and the new msgid
sits untranslated two lines below (`msgstr ""`, line 45). The same pattern
repeats in every locale — `de.po` has 17 obsolete entries, `es.po` 29,
`ja.po` 14, each one a translation this change discarded. Converting the
format string from positional (`%s`/`%g`) to named (`%<name>s`/`%<minimum>g`)
for Ruby's `sprintf` is legitimate and necessary; dropping the exact upstream
spacing in the process (thin spaces → plain spaces) is what actually broke
the key. The commit history (`2c88d46`, "Fix fuzzy axis/instance translation
entries after printf->%<name>s rewrite") shows an attempt to repair exactly
this kind of damage for a sibling string and missed this one.

A second, sibling string — upstream's `_("Instance %d")` — was rewritten the
same way, to `_('Instance %<position>d')`. Checked across `fr`, `de`, `es`,
`ja`, `ru` and `pl`: this one **was** re-translated by hand after the rewrite
(`"Instanz %<position>d"`, `"Instancia %<position>d"`, etc., all live, none
obsolete) — the key is still technically not byte-identical to upstream's
`"Instance %d"`, so it remains a key-set mismatch by the letter of the rule,
but it carries no lost-translation damage the way the variation-axis string
does. The axis string got the rewrite without the follow-up repair; this one
got both.

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

## Scorecard

| Claim | Holds? |
|---|---|
| Key sets equal | **No** — 6 keys unreachable (POTFILES.in gap), 2 keys never marked (bare literals), 1 key reworded into a different key (axis format string, + likely `Instance %d`), 14 keys added that upstream never had |
| Each key byte-identical | No, for the reworded ones above; yes for everything else checked including the 160-entry OpenType table |
| Languages ship unchanged | Yes — `LINGUAS` and the 105 `.po` files are present and match upstream's locale list |

**Verdict: gap.** The catalogue mechanics (LINGUAS, per-locale `.po` files,
the bulk of the OpenType feature table) are sound, which is most of the
*volume* of the translation surface — but every specific place this review
checked for a reworded or added string, it found one, and three of those
breaks (`%s %g…`/`%<name>s…`, the two bare-literal strings, and the missing
POTFILES.in entries) are independently verifiable with no ambiguity.
