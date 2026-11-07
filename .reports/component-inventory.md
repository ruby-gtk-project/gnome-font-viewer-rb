# Component inventory — gnome-font-viewer-rb

Surveyed against `origin/main` (upstream C/GObject app) for full-parity porting.
Upstream has no blueprint files; the UI tree lives in `src/font-view-window.ui`
plus one inline `GtkBuilderListItemFactory` template embedded in it. No
GSettings schema, no shortcuts window, no preferences dialog exist upstream.

Upstream source (`git ls-tree -r --name-only origin/main`):

```
src/font-inscription.c / .h
src/font-model.c / .h
src/font-thumbnailer.c
src/font-view-application.c / .h
src/font-view-window.c / .h / .ui
src/gnome-font-viewer.gresource.xml
src/main.c
src/meson.build
src/open-type-layout.h
src/style.css
src/sushi-font-loader.c / .h
src/sushi-font-widget.c / .h
src/totem-resources.c / .h
data/gnome-font-viewer.thumbnailer
data/icons/... (3 svg)
data/org.gnome.font-viewer.desktop.in.in
data/org.gnome.font-viewer.metainfo.xml.in
data/org.gnome.font-viewer.service.in
po/*.po (119 catalogues) + POTFILES.in/.skip + LINGUAS
```

## Components

| # | Upstream file(s) | `lib/*.rb` | Kind | Exists on `ruby`? |
|---|---|---|---|---|
| 1 | `src/main.c` | `exe/gnome-font-viewer` (+ `lib/translation.rb` for the gettext bootstrap) | entry point / CLI | Yes |
| 2 | `src/font-view-application.c/.h` | `lib/font_view_application.rb` | `Adw.Application` subclass — actions (`app.about`, `app.quit`), accelerators, `open()` handling, stylesheet load | Yes |
| 3 | `src/font-view-application.c` (`action_about`, inline `adw_show_about_dialog`) | `lib/about_dialog.rb` | about dialog | Yes |
| 4 | `src/font-view-window.c/.h` + `src/font-view-window.ui` (template root) | `lib/font_view_window.rb` | `Adw.ApplicationWindow` subclass — owns `AdwNavigationView`, window actions (`win.focus-search`, `win.install-font`), the `GtkEventControllerKey` key-bubble handler, the `GtkShortcutController` (Ctrl+F) | Yes |
| 5 | `src/font-view-window.ui` — `AdwNavigationPage[tag=overview]` subtree (search entry, `AdwHeaderBar`, `GtkGridView` + `GtkFilterListModel`/`GtkSortListModel`/`GtkStringFilter`/`GtkStringSorter`) | `lib/overview_page.rb` | page | Yes |
| 6 | `src/font-view-window.ui` — inline `GtkBuilderListItemFactory` template (`GtkBox` > `FontInscription` + `GtkInscription`, CSS `font-item`/`font-preview`) | `lib/font_item.rb` | grid list-item widget | Yes |
| 7 | `src/font-view-window.ui` — `AdwNavigationPage[tag=preview]` subtree (install/info buttons, `GtkStack`, `GtkScrolledWindow`/`GtkViewport`) + `font-view-window.c` install-font logic | `lib/preview_page.rb` | page | Yes |
| 8 | `src/font-view-window.ui` — `AdwNavigationPage[tag=info]` subtree (`AdwPreferencesPage`) + `font-view-window.c` `populate_grid`/`populate_details`/`add_row`/`strip_whitespace`/`strip_version`/`describe_axis`/`get_sfnt_name`/`is_valid_subfamily_id`/`describe_instance`/`get_features` | `lib/info_page.rb` | page | Yes |
| 9 | `src/font-view-window.ui` — `AdwAlertDialog id="error_dialog"` + `font_view_window_show_error()` | `lib/error_dialog.rb` | dialog | Yes |
| 10 | `src/font-view-window.c` install-font job (`action_install_font_cb`, `install_font_job`, `font_install_finished`, `install_button_refresh_appearance`) | `lib/font_installer.rb` | non-widget helper | Yes |
| 11 | `src/font-model.c/.h` (`FontViewModel`) | `lib/font_model.rb` | `GListModel`-backing model | Yes |
| 12 | `src/font-model.c/.h` (`FontViewModelItem`) | `lib/font_model_item.rb` | list-row data item | Yes |
| 13 | `src/font-inscription.c/.h` | `lib/font_inscription.rb` | `GtkWidget` subclass (fixed-size text preview) | Yes |
| 14 | `src/sushi-font-widget.c/.h` | `lib/font_preview_widget.rb` | `GtkDrawingArea` subclass (full font preview + `loaded`/`error` signals) | Yes |
| 15 | `src/sushi-font-loader.c/.h` | `lib/font_loader.rb` | non-widget helper (FreeType face loading, name lookup) | Yes |
| 16 | `src/totem-resources.c/.h` | `lib/resource_monitor.rb` | non-widget helper (CPU/time watchdog for the thumbnailer) | Yes |
| 17 | `src/font-thumbnailer.c` | `lib/font_thumbnailer.rb` + `exe/gnome-thumbnail-font` | CLI tool | Yes |
| 18 | `src/open-type-layout.h` | `lib/open_type_layout.rb` | static data table | Yes |
| 19 | `src/style.css` | `lib/style.rb` | stylesheet (`gridview` padding, `.font-item`, `.font-preview`) | Yes |
| 20 | `src/gnome-font-viewer.gresource.xml` | — (no `.ui`/resource bundle; house style builds widgets declaratively in Ruby, no GResource needed) | resource manifest | N/A by house style, not a gap |
| 21 | `data/org.gnome.font-viewer.desktop.in.in` | `data/` equivalent (desktop entry / mimetypes) | desktop launcher | Present under `data/` — see note below |
| 22 | `data/org.gnome.font-viewer.metainfo.xml.in` | `data/` equivalent | AppStream metadata | Present under `data/` — see note below |
| 23 | `data/org.gnome.font-viewer.service.in` | `data/` equivalent | D-Bus service activation file | Present under `data/` — see note below |
| 24 | `data/gnome-font-viewer.thumbnailer` | `data/` equivalent | thumbnailer registration | Present under `data/` — see note below |
| 25 | `data/icons/**` (3 svg) | `data/` equivalent | app icons | Present under `data/` — see note below |
| 26 | `po/*.po` (119 catalogues), `po/POTFILES.in`, `po/POTFILES.skip`, `po/LINGUAS` | `po/*.po` + `po/gnome-font-viewer-rb.pot` + `po/LINGUAS` | translation catalogue | Present — catalogue exists; msgid-by-msgid parity is the job of the `translation-parity` skill, not this survey |

## Gaps found

None at the widget/page/dialog level: every upstream unit — the application
class, the window, its three navigation pages (overview, preview, info), the
error dialog, the about dialog, the grid's list-item widget, the two custom
widget classes (`FontInscription`, `SushiFontWidget`→`FontPreviewWidget`), the
model pair, the three non-widget helpers (loader, resource monitor,
installer), the thumbnailer CLI, the OpenType layout table and the
stylesheet — already has a corresponding `lib/*.rb` file on `ruby`, named per
the house `one upstream file → one lib/<thing>.rb` convention (with the two
upstream files that share one class, `font-model.c/.h`, correctly split into
`font_model.rb` + `font_model_item.rb`, and the window's three
`AdwNavigationPage` subtrees correctly split out of the single
`font-view-window.ui`/`.c` pair into their own page files).

This survey did not verify, and leaves to the respective skills:
- **component-parity** — whether each ported widget actually carries the same
  CSS classes, signal connections and action names as upstream (row-by-row,
  not just file-by-file).
- **translation-parity** — whether every upstream `msgid` is present,
  byte-identical, in the Ruby source, and whether all 119 `.po` catalogues
  are intact.
- **test-parity** — upstream ships no automated test suite under `src/`, so
  there is no upstream test census to match; any Ruby specs on `ruby` are
  net-new coverage, not a port.

No action items are raised by this survey; it is a map of what exists, not a
clearance to skip the parity checks above.
