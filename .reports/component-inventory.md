# Component inventory — gnome-font-viewer-rb

Surveyed against `origin/main` (upstream C/GTK4) on 2026-11-07. This is a
survey only: no app code was written for this step.

## Method

- Upstream source enumerated with `git ls-tree -r --name-only origin/main`.
- The one declarative UI file, `src/font-view-window.ui`, read in full: it is
  the template for `FontViewWindow` and defines the three `AdwNavigationPage`s
  (overview/preview/info), the inline `GtkListItem` factory template, the
  `GtkShortcutController` managed shortcut, and the `AdwAlertDialog`
  `error_dialog`.
- Every `src/*.c`/`*.h` file read, together with `src/style.css`,
  `src/gnome-font-viewer.gresource.xml`, and the `data/` packaging files.
- Compared against every file in `lib/` on `ruby`.

## Result

**Upstream has 15 source files (`src/*.c`/`*.h`, excluding `config.h`) plus one
`.ui` template, one `.gresource.xml`, one `.css` and the `data/` packaging
files. `ruby`'s `lib/` already has a corresponding file for every
user-facing component below — this port is at or near full parity already.**
No missing component was found; the items below are the inventory the task
asked for, not a backlog.

## Components

### 1. Application — `FontViewApplication`
one process-wide object: owns the window, the About/Quit actions, the
accelerators, and the file-on-command-line handling

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/font-view-application.c`, `src/font-view-application.h`, `src/main.c` (incl. `--version` option) | `lib/font_view_application.rb` | application | ✅ |

Actions: `app.about`, `app.quit` (both `GSimpleAction`/`Gio::SimpleAction`).
Accels: `app.quit` → `<Control>q`, `window.close` → `<Control>w`,
`win.focus-search` → `<Control>f` (upstream declares the last one as a
`GtkShortcutController` inside the window template rather than an app accel;
the port reproduces the same binding as an accelerator, noted in the file's
header comment).

### 2. Main window — `FontViewWindow`
the one `AdwApplicationWindow`, holding an `AdwNavigationView` over the three
pages below

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/font-view-window.c`, `src/font-view-window.h`, `src/font-view-window.ui` (`<template class="FontViewWindow" parent="AdwApplicationWindow">`) | `lib/font_view_window.rb` | window | ✅ |

Widgets: `Adw.ApplicationWindow` 1, `Adw.NavigationView` 1,
`Gtk.EventControllerKey` 1 (bubble phase, `key-pressed`/`key-released`),
`Gtk.ShortcutController` 1 (managed, `<Control>F` → `win.focus-search`).
CSS: `devel` (added when the application id ends in `Devel`).
Actions installed: `win.focus-search`, `win.install-font`.
Signal: `notify::` on the font model's list (`items-changed`) refreshes the
install button.

### 3. Overview page — `OverviewPage`
the "All Fonts" grid page: search entry in the header, `GtkGridView` of every
installed font below

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `AdwNavigationPage` tagged `overview` in `src/font-view-window.ui` (the `GtkSearchEntry`/`GtkGridView`/`GtkNoSelection`▸`GtkFilterListModel`▸`GtkSortListModel` chain and its inline `GtkBuilderListItemFactory` template) | `lib/overview_page.rb` | page | ✅ |

Widgets: `Adw.ToolbarView` 1 (css `view`), `Adw.HeaderBar` 1, `Adw.Clamp` 1,
`Gtk.SearchEntry` 1, `Gtk.Button` 1 (About, `app.about`), `Gtk.ScrolledWindow`
1, `Gtk.GridView` 1, `Gtk.NoSelection`/`Gtk.FilterListModel`/`Gtk.SortListModel`
(types, not widgets). Signals: `search_entry#search-changed` →
`filter.changed`, `grid_view#activate` → opens the selected item.

### 4. Grid item template — `FontItem`
one cell of the overview grid: a large self-drawn preview over the font's name

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| Inline `GtkBuilderListItemFactory` template inside the `overview` page in `src/font-view-window.ui` | `lib/font_item.rb` | repeater (one per installed font) | ✅ |

Widgets per item: `Gtk.Box` 1 (vertical, css `font-item`), `FontInscription` 1
(css `font-preview`), `Gtk.Inscription` 1 (ellipsized name).

### 5. Font preview widget — `FontInscription`
the fixed-size drawing area that renders "Aa" in a font

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/font-inscription.c`, `src/font-inscription.h` | `lib/font_inscription.rb` | widget (`Gtk.DrawingArea` subclass) | ✅ |

### 6. Font model — `FontModel` / `FontModelItem`
the backing list of installed fonts

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/font-model.c`, `src/font-model.h` (`FontViewModel` + `FontViewModelItem` GObjects) | `lib/font_model.rb`, `lib/font_model_item.rb` | model (`Gio::ListModel`-backed) | ✅ |

### 7. Preview page — `PreviewPage`
the page one font fills: title/style in the header, Install and Info buttons,
the font's own preview underneath

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `AdwNavigationPage` tagged `preview` in `src/font-view-window.ui` | `lib/preview_page.rb` | page | ✅ |

Widgets: `Adw.ToolbarView` 1, `Adw.HeaderBar` 1, `Adw.WindowTitle` 1,
`Gtk.Button` 1 (Install, `win.install-font`), `Gtk.ToggleButton` 1 (Info,
`navigation.push` targeting `'info'`), `Gtk.Stack` 1, `Gtk.ScrolledWindow` 1,
`Gtk.Viewport` 1. Install button states/labels: installable (default),
`installing` → "Installing", `installed` → "Installed" (css
`suggested-action`), `failed` → "Failed" — all four reproduced.

### 8. Font preview body — `FontPreviewWidget`
the font's name, its alphabets, and the sample-string-at-every-size block

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/sushi-font-widget.c`, `src/sushi-font-widget.h` | `lib/font_preview_widget.rb` | widget | ✅ |

Signals: `loaded`, `error` (connected swapped in `font-view-window.c`; the
port exposes them as `on_loaded`/`on_error` callbacks).

### 9. Font loader — `FontLoader`
reads a font file and answers every FreeType/HarfBuzz question the UI asks
about it

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/sushi-font-loader.c`, `src/sushi-font-loader.h` | `lib/font_loader.rb` | model/service | ✅ |

### 10. OpenType layout table — `OpenTypeLayout`
the registered feature-tag → human name table

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/open-type-layout.h` | `lib/open_type_layout.rb` | data table | ✅ |

### 11. Info page — `InfoPage`
the font-details `AdwPreferencesPage`: name table strings, glyph count, colour
support, layout features, variation axes, named styles

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `AdwNavigationPage` tagged `info` in `src/font-view-window.ui`, plus `populate_grid`/`populate_details`/`add_row`/`strip_whitespace`/`strip_version` in `src/font-view-window.c` | `lib/info_page.rb` | page | ✅ |

### 12. Error dialog — `ErrorDialog`
the one alert shown when a font won't display or won't install

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `AdwAlertDialog` id `error_dialog` in `src/font-view-window.ui`, `font_view_window_show_error` in `src/font-view-window.c` | `lib/error_dialog.rb` | dialog | ✅ |

Response: `close` → "_Close" (also the close/default response).

### 13. About dialog — `AboutDialog`
opened from the overview header's About button

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `action_about` in `src/font-view-application.c` (`adw_show_about_dialog`) | `lib/about_dialog.rb` | dialog | ✅ |

### 14. Font installer — `FontInstaller`
copies the shown font into the user's font directory (the Install button's
behaviour)

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `action_install_font_cb`, `install_font_job`, `font_install_finished` in `src/font-view-window.c` | `lib/font_installer.rb` | service | ✅ |

### 15. Font thumbnailer — `FontThumbnailer`
the standalone CLI that renders a font file to a square PNG for file managers

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/font-thumbnailer.c`, `data/gnome-font-viewer.thumbnailer` | `lib/font_thumbnailer.rb` | CLI entry point | ✅ |

### 16. Resource monitor — `ResourceMonitor`
caps the thumbnailer's memory/CPU/wall-clock use

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/totem-resources.c`, `src/totem-resources.h` | `lib/resource_monitor.rb` | service | ✅ |

### 17. Stylesheet — `Style`
the app's CSS (grid padding, cell padding, preview font size)

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/style.css` (loaded via the GResource bundle `src/gnome-font-viewer.gresource.xml`) | `lib/style.rb` | stylesheet | ✅ |

### 18. GResource bundle
`src/gnome-font-viewer.gresource.xml` (`font-view-window.ui` + `style.css`)
has no port equivalent and needs none: the Ruby house style builds the window
declaratively in code (no `.ui` file to bundle) and loads the CSS directly
(`Style.apply`) rather than through a resource path. Not a gap — a
deliberate, documented substitution (see `lib/style.rb`'s header comment).

### 19. GSettings schema
None exists upstream — `git ls-tree` shows no `*.gschema.xml` anywhere in the
tree, so there is nothing to port here.

### 20. Translation / gettext bootstrap
| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `main.c`'s `bindtextdomain`/`bind_textdomain_codeset`/`textdomain`, every `_()`/`C_()` call site, `po/POTFILES.in`, `po/POTFILES.skip`, `po/LINGUAS`, `po/*.po` | `lib/translation.rb` (bootstrap) + `po/*.po` at the port root + `_()`/`p_()` call sites in every other `lib/*.rb` | infra | ✅ |

### 21. Entry point
| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/main.c` (option parsing, `g_application_run`) | `lib/gnome_font_viewer.rb` (the `require_relative` aggregator) + `FontViewApplication#run` (handles `--version`) | entry point | ✅ |

## Keyboard shortcuts

| Shortcut | Upstream | Port |
|---|---|---|
| `Ctrl+F` | `GtkShortcutController` → `win.focus-search`, in the window template | `FontViewWindow::FOCUS_SEARCH_ACCEL`, set as an app accelerator | ✅ |
| `Ctrl+Q` | `app.quit` accel, set in `font_view_application_startup` | `FontViewApplication::ACCELS['app.quit']` | ✅ |
| `Ctrl+W` | `window.close` accel, same place | `FontViewApplication::ACCELS['window.close']` | ✅ |

No `src/*.gschema.xml`, no shortcuts window/dialog, and no menu model exist
upstream, so none of those are missing components either — they simply aren't
part of this app.

## Bottom line

Every upstream user-facing unit — the application, the window, its three
pages, the grid item template, the font-rendering widget, the model, the two
dialogs, the installer, the thumbnailer CLI, the resource monitor, the
OpenType table, and the stylesheet — already has a `lib/*.rb` file on `ruby`,
each carrying a header comment naming exactly what upstream file(s) it was
ported from. No blocking gap was found in this survey; a deeper pass (the
`component-parity` skill, widget-by-widget) would be the next step to confirm
nothing inside an existing file was dropped, but that is outside this
survey's scope.
