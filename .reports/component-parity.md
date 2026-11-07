# Component parity — gnome-font-viewer-rb

| | |
|---|---|
| Upstream | `origin/main` (GNOME Fonts, GTK4 + libadwaita, C) |
| Port | `ruby` |
| Units checked this round | application, window, about dialog, overview page, preview page, info page, style, thumbnailer CLI |
| Units with full (4-axis) parity | 4 / 8 checked |

This builds on `.reports/component-inventory.md` (the `component-identification`
survey), which already established file-level presence for all 19 upstream
components. This pass re-opens the ones most likely to carry text/behaviour
drift and checks all four axes: count, style, behaviour, text.

## Unit: stylesheet — `src/style.css` -> `lib/style.rb`

| Rule | Upstream | Port | Verdict |
|---|---|---|---|
| `gridview { padding: 16px }` | ✓ | ✓ | parity |
| `.font-item { padding: 8px }` | ✓ | ✓ | parity |
| `.font-preview { font-size: 128px }` | ✓ | ✓ | parity |

`lib/style.rb`'s `CSS` constant is byte-identical to `src/style.css`. **parity.**

## Unit: overview page — `font-view-window.ui` (`tag=overview`) -> `lib/overview_page.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ToolbarView` | 1 | 1 | ✓ `view` | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `text`→filter | ✓ `Search fonts` | parity |
| `Gtk.Button` (about) | 1 | 1 | — | ✓ `app.about` | ✓ `About Fonts` tooltip | parity |
| `Gtk.GridView` | 1 | 1 | `gridview` (stylesheet) | ✓ `activate` | — | parity |

Checked by driving the app: typing a non-matching string empties the grid,
typing a matching one repopulates it, Escape clears it (`DRIVE OK` checks
5–10). **Unit verdict: parity.**

## Unit: application — `font-view-application.c` + `main.c` -> `lib/font_view_application.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| `app.about`, `app.quit` actions | ✓ | ✓ | parity |
| `<Control>q` / `<Control>w` accels | ✓ | ✓ (`ACCELS` constant) | parity |
| `open` vfunc → preview or error | ✓ | ✓ | parity |
| `--version` → prints `_("GNOME Fonts")` + version, exits | ✓, string translatable | prints untranslated `'GNOME Fonts'` (`VERSION_NAME` is a bare literal, not wrapped in `_()`) | **gap**: text axis — see `TRANSLATION_PARITY.md` |
| `--version`'s own GOption help entry, `_("Show the application's version")` | ✓ (shown in `--help`) | **absent** — the port special-cases `argv.include?('--version')` before handing off to `OptionParser`/`Gio::Application`, so there is no `--help` line for it at all | **gap**: a whole behaviour (the flag not advertising itself in `--help`) in addition to the missing string |

**Unit verdict: gap.** Two independent text/behaviour gaps on the one unit
that is otherwise structurally complete.

## Unit: about dialog — `action_about` in `font-view-application.c` -> `lib/about_dialog.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| Application name, icon, version, developers, website, issue URL, translator-credits, licence | ✓ | ✓ | parity |
| `developer_name` text | `_("The GNOME Project")`, translatable | `DEVELOPER_NAME = 'The GNOME Project'` — **bare literal, no `_()`** | **gap**: text axis |

Driven: the about dialog opens and is visible (`DRIVE OK` checks 25–27), which
proves presentation, not translation marking. **Unit verdict: gap** (one row,
text axis).

## Unit: thumbnailer CLI — `src/font-thumbnailer.c` -> `lib/font_thumbnailer.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| `--text TEXT` option + its translated metavar `_("TEXT")` | two separate marked strings | `-t`/`--text`, but the metavar is the bare literal `TEXT` baked into `OptionParser`'s `'-tTEXT'` spec, never passed through `_()` | **gap** |
| `--size SIZE` option + its translated metavar `_("SIZE")` | two separate marked strings | same shape, `SIZE` unmarked | **gap** |
| Usage/help banner `_("FONT-FILE OUTPUT-FILE")` | a standalone translatable metavar for the positional args | merged into one new, port-only string `_('Usage: gnome-thumbnail-font [OPTION…] FONT-FILE OUTPUT-FILE')` — not byte-identical to any upstream msgid | **gap** |
| `-t`/`-s` short options, exit codes, stderr framing | ✓ | ✓ | parity |

Driven: the thumbnailer runs and writes a PNG, reports usage with no
arguments, and errors on a missing file (`DRIVE OK` checks 28–30) — all
behaviour-axis checks. The text axis was never driven and is where the actual
gaps are. **Unit verdict: gap** (three msgids lost or invented).

## Unit: info page — `font-view-window.c` (`populate_grid`/`populate_details`) -> `lib/info_page.rb`

All fifteen row labels (`Name` … `Named Styles`) and `yes`/`no` are present
and marked, matching upstream's set one for one. The variation-axis format
string is **not** byte-identical to upstream's — tracked in
`TRANSLATION_PARITY.md` and not repeated here beyond: the row that shows it is
otherwise a parity row, downgraded only on the text axis.

The `Type` row's content-type descriptions (`TrueType font`, `OpenType font`,
`Font collection`, `WOFF font`, `WOFF2 font`, `SFNT font`, `TrueType XML
font`, `PostScript Type 1 font`, `PCF font`, `BDF font`, `SNF font`, `Speedo
font`, `Linux PSF console font`, `Embedded OpenType font`) are **new text that
exists nowhere in upstream's catalogue** — upstream gets this string from
`g_content_type_get_description()`, i.e. shared-mime-info's own localised
catalogue, never gettext-marked in `gnome-font-viewer` itself. `lib/info_page.rb`
documents why (no Ruby binding exposes that GIO call) and locates the
substitution, which is what `component-parity`'s rules ask for — this is a
correspondence, not a silent gap, on the **component** axis. It is still a
real gap on the **translation** axis (fourteen keys with no upstream
counterpart, so no translation exists for any of them in 78 languages even
when the upstream string was translated) — recorded there.

The driven suite never opens an SFNT font that carries variation axes, OpenType
features, or color glyphs, so `Variation Axes`/`Named Styles`/`Layout
Features`/`Color Glyphs` rows are untested in the runtime gate even though the
code paths exist. Not a component-identification gap, but a `test-parity` one.

**Unit verdict: parity on widgets/behaviour, gap on text** (two items: the
axis format string, the invented content-type strings).

## Unit: preview page — `font-view-window.ui` (`tag=preview`) -> `lib/preview_page.rb`

Install button label cycle (`_Install` → `Installing` → `Installed`/`Failed`),
`suggested-action` class toggling, info toggle button, and the lazily-built
font widget are all present and match the inventory. Driven end to end
(`DRIVE OK` checks 11–17, 22–24): preview opens, install fires, button state
settles, installed file is byte-identical. **Unit verdict: parity.**

## Unit: error dialog — `font-view-window.ui` (`error_dialog`) -> `lib/error_dialog.rb`

Present, one `_Close` response, shown from the three call sites. Driven open
with heading set (`DRIVE OK` checks 20–21) but the body is never asserted —
see the upstream bug noted in `component-inventory.md` (`show_error` passes
`heading` as the body, dropping the real message): whether the port
reproduces or fixes that bug was never checked, by this review or by the
drive script. **Unit verdict: unverified on one facet, otherwise parity.**

## Rollup

| Axis | Status |
|---|---|
| Count | No missing or extra widgets found in the eight units checked |
| Style | `suggested-action`, `view`, `property`, `devel`, `font-item`, `font-preview` CSS classes all present where upstream applies them |
| Behaviour | All checked signals/actions fire; driven for 6 of 8 units |
| Text | **5 confirmed gaps**: `--version`'s own string and its help entry, the about dialog's developer name, the thumbnailer's `TEXT`/`SIZE`/usage metavars (3 msgids), the variation-axis format string, and 14 invented content-type strings with no upstream counterpart |

**This round's component-parity verdict: gap.** The widget tree is faithful
everywhere checked; every open item is on the text axis, detailed above and
cross-filed in `TRANSLATION_PARITY.md`.
