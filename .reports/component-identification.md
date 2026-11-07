# Component identification — this round's pass

`.reports/component-inventory.md` already carries a full, file-by-file
component inventory for this app (one section per upstream file, widgets +
CSS + signals + actions, all 19 `lib/*.rb`-shaped components mapped). It was
re-read in full for this round and confirmed still accurate at the file/widget
level — no widget, signal or action it lists was found to be wrong by the
deeper `component-parity` pass. Rather than duplicate it, this note records
two corrections and one addition found while using it as the base for
`component-parity.md` and `translation-parity.md`:

## Correction: locale count

`component-inventory.md` states "107 locales in upstream's `po/LINGUAS`."
Recounted directly this round against `origin/main`'s actual `po/LINGUAS`:
**105** entries, matching the port's `po/LINGUAS` (also 105) and the port's
`po/*.po` file count (105). The earlier figure was off by two; the parity
conclusion it was used for (no gap in locale count) still holds, just at the
right number.

## Addition: a port-only data component the inventory's file-level framing didn't surface

`lib/info_page.rb`'s `CONTENT_TYPE_DESCRIPTIONS` is a fourteen-entry string
table with no upstream source line behind it (upstream gets this text from
`g_content_type_get_description()` at runtime, not from its own source). By
this skill's own rule ("under-reports... Composite widgets... CSS classes
behind a macro... read, don't strike"), a data table of fourteen new
user-visible strings is a component in its own right and belongs in the
inventory even though it corresponds to nothing in `src/`. It is now
identified, follows into `lib/info_page.rb:62-80`, and is carried into
`component-parity.md` and `translation-parity.md` as the place those two
reports found their respective gaps.

## Addition: the `--version` flag's own help text has no component to attach to

Upstream's `main.c` declares `--version` as a `GOptionEntry` with its own
translatable description, `N_("Show the application's version")`, which
shows up in `--help` output. The port's `lib/font_view_application.rb#run`
checks `argv.include?('--version')` ahead of handing off to
`Gtk::Application`/`OptionParser` entirely, so there is no help-text
component on the port side to identify — not "present but wrong," genuinely
absent as a component. Recorded here because `component-inventory.md`'s
application-unit section does not mention it, and it is the detail
`component-parity.md` flags as a gap on that unit.

No other correction or addition was found. The inventory's structure (one
unit per upstream file, house style file mapping, the seven numbered risks at
the end) remains the right map of the app for any future round.
