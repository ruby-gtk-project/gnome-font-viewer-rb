# gnome-font-viewer — upstream component inventory

Survey step for the full-parity Ruby port. Upstream is `origin/main`
(GNOME Fonts, GTK4 + libadwaita, C); the port is the `ruby` branch of this
repo. Read with the `component-identification` skill's rules: a component is a
widget *plus* its CSS classes, signals, actions and owner.

Upstream is small: 11 C/H sources in `src/`, one `.ui` template, one `.css`,
no GSettings schema, no blueprint. The `.ui` file and `font-view-window.c` are
two halves of one component and are unioned below.

## Declarative UI

`src/font-view-window.ui` has exactly one `<template class="FontViewWindow"
parent="AdwApplicationWindow">` plus one free-standing `<object
class="AdwAlertDialog" id="error_dialog">`. The template contains an
`AdwNavigationView` with three `AdwNavigationPage`s (`overview`, `preview`,
`info`), and a nested `GtkBuilderListItemFactory` whose `bytes` property is a
second, inline `GtkListItem` template — that inline template is its own
component and is listed separately.

No `.blp`. No GSettings schema anywhere in the tree (`meson_options.txt` and
`data/meson.build` ship only the desktop file, metainfo, icons, D-Bus service
and thumbnailer entry). GResource (`src/gnome-font-viewer.gresource.xml`)
carries just `font-view-window.ui` and `style.css`.

## Stylesheet

`src/style.css` — three rules, all of which the port must reproduce:

| Selector | Declarations | Applied by |
|---|---|---|
| `gridview` | `padding: 16px` | implicit on the overview `GtkGridView` |
| `.font-item` | `padding: 8px` | the list-item `GtkBox` |
| `.font-preview` | `font-size: 128px` | the list-item `FontInscription` |

CSS classes applied from source, not the stylesheet: `view` (overview
`AdwToolbarView`), `property` (every info `AdwActionRow`), `suggested-action`
(install button, added/removed dynamically), `devel` (on the window when
`APPLICATION_ID` ends in `Devel`).

---

## src/font-view-application.c + src/main.c — the application

`FontViewApplication : AdwApplication`, `HANDLES_OPEN`, resource base path
`/org/gnome/font-viewer/`.

| Facet | Detail |
|---|---|
| Actions | `app.about`, `app.quit` |
| Accels | `app.quit` → `<Control>q`; `window.close` → `<Control>w` |
| Signals/vfuncs | `activate` → show overview; `startup` → `FcInit`, app name _"Fonts"_, default icon; `open` → async `g_file_query_info` then preview, or error |
| Other | `main.c` adds a `--version` option printing _"GNOME Fonts"_ + version; gettext bindings (`bindtextdomain`/`bind_textdomain_codeset`/`textdomain`) |
| Error state | query-info failure → overview + `Could Not Display Font` alert |

Repeaters: none. Conditional: the window is created once, lazily
(`ensure_window`).

→ **`lib/font_view_application.rb`** (kind: application). **Present** —
`FontViewApplication`, 156 lines, with `app.about`, `app.quit`, both accels
and the `open` path.

## src/font-view-application.c (`action_about`) — About dialog

`adw_show_about_dialog` with application name _Fonts_, icon, developer name
_The GNOME Project_, four developers, website, issue URL,
`translator-credits`, licence GPL-2.0.

→ **`lib/about_dialog.rb`** (kind: dialog). **Present** (`AboutDialog`, 57 lines).

## src/main.c + src/font-view-application.c — gettext bootstrap

`bindtextdomain`/`bind_textdomain_codeset`/`textdomain` in `main.c`, consumed
everywhere else through `_()`/`C_()`. Has no single upstream file of its own —
it is the setup half of every translated string in every other component.

→ **`lib/translation.rb`** (kind: support, no direct upstream file — the Ruby
equivalent of `main.c`'s `bindtextdomain` calls, built on the `gettext` gem).
**Present** (34 lines), included by every other `lib/*.rb` that defines a
user-facing string.

## src/font-view-window.c + src/font-view-window.ui — the main window

`FontViewWindow : AdwApplicationWindow`, 800×600 default, 360×294 minimum,
`focus-widget` = `search_entry`.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `devel` (only when app id ends `Devel`) | — | holds everything |
| `Gtk.ShortcutController` (scope `managed`) | 1 | — | — | controller |
| `Gtk.Shortcut` | 1 | — | `<Control>F` → `action(win.focus-search)` | — |
| `Gtk.EventControllerKey` (phase `bubble`) | 1 | — | `key-pressed`, `key-released` → `window_bubble_key_event` | controller |
| `Adw.NavigationView` (`nav_view`) | 1 | — | `push_by_tag`, `pop` from source | three pages |
| `Adw.NavigationPage` | 3 | — | tags `overview` / `preview` / `info` | see below |

Window-level actions installed with `gtk_widget_class_install_action`:
`win.focus-search` (grab focus to the search entry) and `win.install-font`.

`window_bubble_key_event` is type-to-search: `Escape` clears the search entry
and stops; navigation/space/menu keys and any `Ctrl`/`Alt` combination
propagate; anything else is forwarded to the `GtkText` delegate inside the
search entry and, if handled, focus moves to the entry.

Window also owns, in source: the `FontViewModel`, the `GtkSortListModel`
hookup, an `items-changed` handler that refreshes the install button, a
`GFile` for the current font, a `GCancellable` for the install job, and the
`font_name_closure` used by both the filter and the sorter.

→ **`lib/font_view_window.rb`** (kind: window). **Present** (`FontViewWindow`, 298 lines).

## src/font-view-window.ui — overview page (`tag=overview`)

Title _All Fonts_.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | `view` | — | — |
| `Adw.HeaderBar` | 1 | — | — | title widget is the search clamp |
| `Adw.Clamp` | 1 | — | — | max 400, tightening 150; source sets `hexpand` on it as a workaround |
| `Gtk.SearchEntry` (`search_entry`) | 1 | — | `text` bound into the filter's `search`; `search-delay` 0 | placeholder _Search fonts_ |
| `Gtk.Button` | 1 | — | `app.about` | `help-about-symbolic`, tooltip _About Fonts_ |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar-policy: never` |
| `Gtk.GridView` (`grid_view`) | 1 | `gridview` padding from CSS | `activate` → `view_child_activated_cb` | `single-click-activate`, `tab-behavior: item`, `vexpand` |

Non-widget model chain (compare on the behaviour axis, not the widget count):
`Gtk.NoSelection` ← `Gtk.FilterListModel` (`filter`) with a
`Gtk.StringFilter` whose expression is the `font_name_closure` and whose
`search` binds to the entry ← `Gtk.SortListModel` (`sort_model`) with a
`Gtk.StringSorter` on the same closure ← the `FontViewModel` list store.

`view_child_activated_cb` reads the item at the activated position and calls
`font_view_window_show_preview (file, face_index)`.

Empty state: none upstream — no `AdwStatusPage`, no "no results" view.

→ **`lib/overview_page.rb`** (kind: page). **Present** (`OverviewPage`, 151 lines).

## src/font-view-window.ui — the grid list-item (inline `GtkListItem` template)

The `GtkBuilderListItemFactory` `bytes` payload. One component, repeated once
per visible font (a repeater driven by the filtered/sorted font model).

| Widget | × | CSS | Bindings | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical, spacing 6) | 1 | `font-item` | — | item root |
| `FontInscription` | 1 | `font-preview` | `text` ← item `preview-text`; `attributes` ← item `attr-list` | `halign: center`, `vexpand`, 6px side margins |
| `Gtk.Inscription` | 1 | — | `text` ← item `font-name` | `xalign 0.5`, `text-overflow: ellipsize-end` |

→ **`lib/font_item.rb`** (kind: list-item factory). **Present** (`FontItem`, 78 lines, a `Gtk::SignalListItemFactory`).

## src/font-view-window.ui — preview page (`tag=preview`)

Title bound to `font_title.title`.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` (`font_title`) | 1 | — | set from the loaded face: family name (or basename) + style name | shared with the info page by binding |
| `Gtk.Button` (`install_button`) | 1 | `suggested-action` (added/removed dynamically) | `win.install-font` | label cycles `_Install` → `Installing` → `Installed` / `Failed`; sensitivity follows; tooltip _Install Font_ |
| `Gtk.ToggleButton` (`info_button`) | 1 | — | `navigation.push` with target `'info'` | label `I_nfo`, tooltip _Font Details_; reset to inactive on every `show_preview` |
| `Gtk.Stack` (`preview_stack`) | 1 | — | — | one page named `preview`; a second page is implied by the stack but never added upstream |
| `Gtk.ScrolledWindow` (`swin_preview`) | 1 | — | — | — |
| `Gtk.Viewport` (`viewport_preview`) | 1 | — | — | `hscroll-policy`/`vscroll-policy: natural` |
| `SushiFontWidget` (`font_widget`) | 1 | — | `loaded` → `font_widget_loaded_cb`; `error` → `font_widget_error_cb` | **built in source, not the template** — created lazily on first preview with 12px bottom/start/end margins and `vexpand`; afterwards only its `uri`/`face-index` are reset and `load` called again |

`install_button_refresh_appearance` is the install button's whole visual
state machine and is also called from `items-changed` on the model, so an
externally installed font updates the button live.

→ **`lib/preview_page.rb`** (kind: page). **Present** (`PreviewPage`, 147 lines).

## src/font-view-window.ui + `populate_grid`/`populate_details` — info page (`tag=info`)

Title and subtitle bound to `font_title`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | no buttons; back arrow only |
| `Adw.WindowTitle` | 1 | — | title + subtitle bound | — |
| `Adw.PreferencesPage` (`swin_info`) | 1 | — | — | content |
| `Adw.PreferencesGroup` | 1 | — | — | rebuilt per font: group 0 removed, a fresh one added |
| `Adw.ActionRow` | variable | `property` | — | repeater; `use-markup` false, `use-underline` false, `subtitle-selectable` true |

The rows, in order, each conditional on the face providing the datum:
`Name`, `Location`, `Style`, `Type` (content-type description), then for SFNT
faces `Version` (version prefix stripped), `Copyright`, `Description`,
`Manufacturer`, `Designer`, `License` (each whitespace-stripped); for Type 1
faces `Version` and `Copyright` from `PS_FontInfoRec`. Then the details:
`Glyph Count`, `Color Glyphs` (_yes_/_no_), `Layout Features` (OpenType
feature names joined with the context-qualified `", "`), `Variation Axes`
(one row per axis, first row titled, the rest with an empty title, each
_"%s %g — %g, default %g"_), `Named Styles` (instances joined, falling back to
_"Instance %d"_).

→ **`lib/info_page.rb`** (kind: page). **Present** (`InfoPage`, 330 lines).

## src/font-view-window.ui — error dialog

`Adw.AlertDialog` (`error_dialog`), one response `close` labelled `_Close`.
Presented by `font_view_window_show_error (heading, body)` from three call
sites: file query failure, font-widget `error`, and install failure.
(Upstream bug worth noting: `show_error` sets the body to `heading`, dropping
the real message. Whether the port reproduces that bug or fixes it is a
`component-parity` question, not settled by this survey.)

→ **`lib/error_dialog.rb`** (kind: dialog / error state). **Present** (`ErrorDialog`, 39 lines).

## src/font-view-window.c (`action_install_font_cb` and friends) — font installer

No widgets; the behaviour behind `win.install-font`. Picks the XDG font
directory from `FcConfigGetFontDirs`, else the first directory under `$HOME`;
creates it if absent; copies the font in a `GTask` thread, retrying with a
`<n>` filename prefix on `G_IO_ERROR_EXISTS`; cancellable; on finish refreshes
the install button and raises `Could Not Install Font` on error.

→ **`lib/font_installer.rb`** (kind: action/service). **Present** (`FontInstaller`, 139 lines).

## src/font-model.c + src/font-model.h — the font list model

`FontViewModelItem : GObject` with read-only properties `font-name`,
`preview-text`, `attr-list`, plus `font_file` and `face_index` accessors.
`FontViewModel` holds a `GListStore`, builds it from a fontconfig
`FcFontList` (`FC_FILE`, `FC_INDEX`, `FC_FAMILY`, `FC_STYLE`, `FC_SLANT`,
`FC_WEIGHT`, `FC_SCALABLE`), maps fontconfig weight/slant to Pango
weight/style and to the English style names used in the displayed font name,
emits `items-changed`, has `font_view_model_has_face` for the install button,
and watches fontconfig for config changes with an idle-scheduled reload.

→ **`lib/font_model.rb`** (kind: model, 249 lines) and
**`lib/font_model_item.rb`** (kind: model item, 40 lines, a `GLib::Object`
subclass). **Both present.**

## src/font-inscription.c + src/font-inscription.h — fixed-size preview cell

`FontInscription : GtkWidget` (final). Properties `text`, `attributes`.
Custom `measure` (fixed 220×180) and `snapshot` (a clipped `PangoLayout`
drawn at a 0.7 baseline fraction). Used only by the grid list-item.

→ **`lib/font_inscription.rb`** (kind: custom widget). **Present** — 127 lines, rebuilt as a `Gtk::DrawingArea` (see blocker 2).

## src/sushi-font-widget.c + src/sushi-font-widget.h — the font preview canvas

`SushiFontWidget : GtkDrawingArea`. Properties `uri`, `face-index` (both
construct). Signals `loaded` and `error` (carries a `GError`). Custom
`measure` + `snapshot` drawing, via Cairo with an FT font face: the font name
at a title size, then the lowercase alphabet, the uppercase alphabet and
`0123456789.:,;(*!?')` at an alpha size (each omitted when the face lacks the
glyphs), then a sample string at each of 8, 10, 12, 18, 24, 36, 48, 72, 96,
120, 144, 168, 192, 216 pt (or the face's own fixed sizes), stopping when the
allocation is full. Handles RTL base direction. `load` is async and re-entrant.

→ **`lib/font_preview_widget.rb`** (kind: custom widget). **Present** — 355 lines, rebuilt as a `Gtk::DrawingArea` (see blocker 2).

## src/sushi-font-loader.c + src/sushi-font-loader.h — FreeType face loader

Sync and async `FT_Face` from a URI with a face index, plus
`sushi_get_font_name (face, short_form)`. No UI.

→ **`lib/font_loader.rb`** (kind: support/service). **Present** (`FontLoader` module, 992 lines — the FFI/parsing bulk of the port).

## src/open-type-layout.h — OpenType feature name table

159 `MAKE_TAG` → translatable name pairs in the `"OpenType layout"` message
context, consumed by `get_features` for the `Layout Features` row. Pure data,
but it is user-facing text and part of the translation surface.

→ **`lib/open_type_layout.rb`** (kind: data table). **Present** (`OpenTypeLayout` module, 212 lines).

## src/font-thumbnailer.c + src/totem-resources.c/.h + data/gnome-font-viewer.thumbnailer — the thumbnailer

A second executable, `gnome-thumbnail-font`, registered as a GNOME
thumbnailer for the font MIME types. Options `--text` (_Text to thumbnail
(default: Aa)_, `TEXT`), `--size` (_Thumbnail size (default: 128)_, `SIZE`),
and `FONT-FILE OUTPUT-FILE`. `totem-resources.c` is the rlimit/wall-clock
watchdog around it. No widgets; translatable strings only.

→ **`lib/font_thumbnailer.rb`** (kind: CLI tool, 250 lines) and
**`lib/resource_monitor.rb`** (kind: support, 124 lines). **Both present.**

## src/style.css + src/gnome-font-viewer.gresource.xml — the stylesheet

Three rules (table above), loaded as a GResource. The port has no GResource,
so this becomes a `Gtk::CssProvider` fed from a string or a data file.

→ **`lib/style.rb`** (kind: stylesheet). **Present** (`Style` module, 43 lines, a `Gtk::CssProvider` fed from a string).

## data/org.gnome.font-viewer.desktop.in.in, .metainfo.xml.in, .service.in, icons

Desktop entry (_Fonts_ / _View fonts on your system_, keywords
`fonts;fontface;`, 8 font MIME types, `DBusActivatable`), AppStream metainfo,
D-Bus service file, and three SVG icons (regular, Devel, symbolic).

→ **`data/` passthrough**, no `lib/*.rb`. (kind: packaging). **Present** —
`data/` carries the thumbnailer entry, the desktop/metainfo/service
templates and `data/icons/`.

## po/ — translations

107 locales in upstream's `po/LINGUAS`; `po/POTFILES.in` lists the desktop
file, metainfo, `font-thumbnailer.c`, `font-view-application.c`,
`font-view-window.c`, `font-view-window.ui`, `main.c` and
`open-type-layout.h`. The bulk of the catalogue is the 159 OpenType feature
names.

→ **`po/*.po` + `po/gnome-font-viewer-rb.pot` + `po/LINGUAS` + `lib/translation.rb`**
(kind: translation catalogue). **Present** — 119 `.po` files, `LINGUAS` (107
entries) and the gettext bootstrap now exist on `ruby` (commit
`308f0b1`, "Port the translation catalogue (po/) and wire up gettext", with a
follow-up fuzzy-entry fix in `2c88d46`). This closes the gap the previous
version of this inventory recorded as "Missing". Whether every upstream
`msgid` made it across byte-identical, and whether all 107 locales still
round-trip, is the `translation-parity` step's job, not re-verified here.

---

## What `lib/` on `ruby` has today

One file per upstream component, house style (`# frozen_string_literal: true`,
`require 'adwaita'`, `require_relative` siblings, a ported-from comment,
memoized widget accessors with `.tap`):

| Path | Lines | What it is |
|---|---:|---|
| `lib/gnome_font_viewer.rb` | 8 | entry requires: the display-free half, the application and the thumbnailer |
| `lib/font_view_application.rb` | 156 | application |
| `lib/font_view_window.rb` | 298 | window |
| `lib/overview_page.rb` | 151 | page |
| `lib/font_item.rb` | 78 | grid list-item factory |
| `lib/preview_page.rb` | 147 | page |
| `lib/info_page.rb` | 330 | page |
| `lib/about_dialog.rb` | 57 | dialog |
| `lib/error_dialog.rb` | 39 | dialog / error state |
| `lib/font_installer.rb` | 139 | action/service |
| `lib/font_model.rb` | 249 | model |
| `lib/font_model_item.rb` | 40 | model item |
| `lib/font_inscription.rb` | 127 | custom widget (DrawingArea) |
| `lib/font_preview_widget.rb` | 355 | custom widget (DrawingArea) |
| `lib/font_loader.rb` | 992 | FreeType/fontconfig access |
| `lib/open_type_layout.rb` | 212 | data table |
| `lib/font_thumbnailer.rb` | 250 | CLI tool |
| `lib/resource_monitor.rb` | 124 | support |
| `lib/style.rb` | 43 | stylesheet |
| `lib/translation.rb` | 34 | gettext bootstrap (no single upstream file; see above) |
| `lib/gnome/font/viewer/rb/version.rb` | — | gem version (no upstream counterpart) |

Parity count: **19 of 19** upstream `lib/*.rb`-shaped components present,
plus the `data/` passthrough and the `po/` catalogue. Presence is file-level
only — this survey does not claim per-widget, per-CSS-class, per-signal or
per-msgid parity; that is the `component-parity` and `translation-parity`
steps' job, and the risks below are the places where the port's shape
necessarily diverges from upstream's and deserve a second look there.

## Risks carried from survey time (not blockers — everything below has a resolution already on `ruby`; recorded so parity review knows where to look)

1. **FreeType / HarfBuzz / fontconfig have no Ruby bindings here.** Almost
   every datum on the info page (`FT_Get_Sfnt_Name`, `FT_Get_PS_Font_Info`,
   `FT_Get_MM_Var`, `FT_HAS_COLOR`, `num_glyphs`,
   `hb_ot_layout_language_get_feature_tags`) and the whole font list
   (`FcFontList`, `FcConfigGetFontDirs`) come from C APIs with no gem.
   *Resolved without FFI:* `lib/font_loader.rb` parses the sfnt tables itself
   (table directory, `name`, `head`, `maxp`, `cmap`, `fvar`, GSUB/GPOS feature
   lists, colour and bitmap tables, TTC and WOFF containers, Type 1 cleartext
   `FontInfo`), and `lib/font_model.rb` shells out to `fc-list` with the same
   field set as upstream's `FcObjectSet`. Both carry runtime cost and parsing
   risk upstream does not have, and `fc-list` is now a hard runtime dependency
   — `component-parity` should check this still matches `FcFontList` field for
   field.
2. **`SushiFontWidget` and `FontInscription` are `GtkWidget` subclasses with
   custom `measure` and `snapshot`**, which Ruby GTK cannot override.
   *Resolved* by rebuilding both as `Gtk::DrawingArea` with a draw func and
   explicit size requests (`lib/font_preview_widget.rb`,
   `lib/font_inscription.rb`). Measure and baseline behaviour therefore differ
   from upstream by construction — worth a visual check.
3. **`GtkBuilderListItemFactory` with inline `bytes` and `<closure>`/`<binding>`
   is not reachable from Ruby.** *Resolved:* `lib/font_item.rb` is a
   `Gtk::SignalListItemFactory`, and the `font_name_closure` the filter and
   sorter share is done in Ruby instead of as a `Gtk::Expression`.
4. **`Adwaita::Application` / `Adwaita::ApplicationWindow` are flagged broken
   in the `ruby-gtk` skill**, yet upstream's root is `AdwApplicationWindow`.
   Worth re-checking in the dev shell on every bindings bump which of
   `Gtk::Application`/`Adwaita::ApplicationWindow` each of
   `lib/font_view_application.rb`/`lib/font_view_window.rb` ended up using.
5. **Widget-class actions and `navigation.push` with a target.**
   `gtk_widget_class_install_action` has no Ruby equivalent, so
   `win.focus-search` and `win.install-font` are `Gio::SimpleAction`s on an
   action group on the window, and the info toggle's `navigation.push`/`'info'`
   target has to be driven from Ruby against `Adwaita::NavigationView`.
6. **Async + threads.** Upstream's install job is a `GTask` in a thread with a
   `GCancellable` and the face loader is async; the port has to keep both off
   the main loop without GLib's task machinery.
7. **No GSettings schema upstream**, so nothing to port there — and no
   persisted state, which the port must not invent.
