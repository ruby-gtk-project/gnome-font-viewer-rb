# Accountability ensurance — gnome-font-viewer-rb

Grepped `lib/`, `exe/`, `.reports/` for `TODO`, `FIXME`, `not implemented`,
`for now`, `in a future`, `out of scope`, `does not carry over`, `not
applicable`, `n/a`, `dropped deliberately`, `by design`, `simplified`. There
is no `PORTING.md` anywhere in this repository — checked for one at the root
and found none, so the specific failure mode the `console-rb` precedent
describes (a navigation document that quietly becomes a decision document)
has no document to live in here.

## What the grep found

One hit, and it is a false positive: `lib/open_type_layout.rb:138` —
`'smpl' => p_('OpenType layout', 'Simplified Forms')` — is the literal
upstream OpenType feature name "Simplified Forms" (tag `smpl`), not the word
"simplified" used to excuse a gap. No other grep term matched anything in
`lib/`, `exe/`, or the four other reports this round produced
(`component-parity.md`, `test-parity.md`, `translation-parity.md`, and the
pre-existing `component-inventory.md`).

**No excuse language exists in this codebase or its reports.** That is a
genuine, checked fact, not an assumption — and it is also not the same claim
as "no gaps exist." It means gaps, where they exist, are not being hidden
behind a sentence that reads as a decision. They are gaps, full stop, and
this round's other four reports say so directly rather than filing them under
a softer word.

## Checking for the subtler form: a true claim doing the work of an excuse

The grep catches vocabulary. It does not catch a technically accurate
sentence placed where a reader will mistake it for permission. Three places
in `.reports/component-inventory.md` were read specifically for this:

- **"Resolved without FFI" / "Resolved by rebuilding both as `Gtk::DrawingArea`"**
  (lines 363, 373) — these describe a working substitution for a binding gap
  (`FontInscription`/`SushiFontWidget` cannot be `GtkWidget` subclasses with
  custom `measure`/`snapshot` in Ruby GTK) and say exactly where the
  replacement lives. `component-parity`'s own rules treat a located,
  explained substitution as a correspondence, not a gap — this is the
  documentation the skill asks for, not an excuse for missing work. It does
  not claim anything is finished that isn't; `component-parity.md` (this
  round) still flags that the drawing correctness of both widgets was never
  driven or screenshotted for content, which is the real open item, and that
  flag exists specifically because "resolved" in the inventory was read as
  "resolved for the binding gap," not "resolved, nothing more to check."
- **The content-type-description substitution in `lib/info_page.rb`** (the
  comment explaining why fourteen strings are hand-written instead of coming
  from `g_content_type_get_description()`) is the same shape: it names the
  binding gap, names the file, and does not claim the result matches
  upstream's translation behaviour. It doesn't — `translation-parity.md`
  (this round) counts those fourteen strings as added keys with no upstream
  counterpart and no translation in any locale. The source comment explains
  a decision about *how to build the component*; it carries no authority
  over whether that decision closes the translation gap, and this round's
  reports do not treat it as if it did.

Neither of these reads, on inspection, as a confession formatted to look like
architecture. Both are falsifiable claims ("the CSS is reproduced," "the
measure/snapshot behaviour is rebuilt") that this round's `component-parity.md`
and `translation-parity.md` went and actually checked, rather than citing as
settled.

## Where a false-green risk really sits: the runtime gate, not the prose

The task brief's sharpest instruction is "a false green in a report is the
most serious finding you can make." The place that risk actually lives this
round is not in any excuse sentence — there isn't one — but in how the
**34/34, drive_ok=true** number could be read. Nothing in the repository
claims those 34 checks constitute full behavioural coverage; the risk is a
*reader* inferring that from the bare number, the same mechanism the
`console-rb` precedent describes, just without a sentence to carry it. That
is exactly why this round's `test-parity.md` spells out, component by
component, what the 34 checks do and do not reach (keyboard typeahead
redirection, the drawing widgets' actual output, locale/i18n behaviour, most
of the info page's row content) instead of letting the pass/fail count speak
for itself. Treat that enumeration as this report's actual finding: **the
gate number is accurate and was reproduced, but it is narrower than its
"9 components" framing invites a reader to assume**, and nothing in the repo
said so until this round's reports did.

## Scorecard

| Check | Result |
|---|---|
| Excuse vocabulary in `lib/`, `exe/` | None found |
| Excuse vocabulary in `.reports/` | None found |
| `PORTING.md` citing itself as authority for a gap | Does not exist |
| True statements doing an excuse's job | Checked two candidates; both are located, falsifiable substitution notes that this round's own parity checks verified rather than took on faith |
| False-green risk | Present in how the runtime gate's 34/34 could be read in isolation, not in any sentence in the repo; addressed by this round's `test-parity.md` naming what it does not cover |

**Verdict: no accountability violation found in this codebase's own words.**
The gaps this round surfaced (translation key-set mismatches, two bare
string literals, an empty spec suite, narrow drive coverage) are reported as
gaps in `component-parity.md`, `translation-parity.md` and `test-parity.md`
respectively — nowhere are they described as settled, out of scope, or
resolved beyond what was actually resolved.
