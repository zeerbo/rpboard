# Prepared-spell limit on the Magie tab

Status: ready-for-agent

## Problem Statement

A player running a prepared caster — a wizard or a druid who knows every spell of their accessible levels but must choose a subset each morning — has no way to record how many spells that subset may hold. The Magie tab already offers a per-spell "prepared" toggle, so a player can mark spells as prepared, but nothing bounds how many. At the table this means the sheet cannot answer the one question that matters during preparation ("am I full yet?"), and it silently permits a state the game rules forbid: twelve spells prepared when the character may prepare five. The player ends up tracking the count on paper beside an app that was supposed to replace the paper.

## Solution

The Character gains a player-typed number: how many spells may be prepared at once. The Magie tab shows a third derived chip beside CD Magia and Bonus Attacco reading `prepared / limit` — a live answer to "am I full yet?". Once the limit is reached, the existing prepared toggle stops accepting new spells and says why, so the player is told rather than left guessing. Nothing is ever un-prepared automatically: the player who lowers their limit below what they have prepared sees the chip turn red and decides themselves which spells to drop.

Deliberately small. The prepared toggle stays the single gesture for preparing and un-preparing a spell; no separate "prepared spells" section, no "Prepara" button, no substitution flow.

## User Stories

1. As a wizard's player, I want to type how many spells I may prepare per day, so that my sheet knows the bound my class imposes.
2. As a druid's player, I want that number to persist across app restarts, so that I type it once per level-up instead of once per session.
3. As a player preparing spells, I want a chip beside CD Magia and Bonus Attacco showing prepared-versus-limit, so that I can see at a glance how many choices I have left.
4. As a player preparing spells, I want that chip to update the instant I toggle a spell, so that I never have to count the checked circles by hand.
5. As a player who has filled every slot, I want the prepared toggle to refuse the next spell, so that my sheet cannot hold a state the rules forbid.
6. As a player whose toggle was refused, I want a message naming the limit I hit, so that the unresponsive tap reads as a rule and not as a bug.
7. As a player at my limit, I want to un-prepare a spell and immediately be able to prepare a different one, so that swapping a choice costs two taps and no ceremony.
8. As a player un-preparing a spell, I want it to stay in my spell list, so that dropping today's choice never costs me the spell I learned.
9. As a player who just levelled up, I want to raise my limit and prepare more spells at once, so that the sheet follows my character's growth.
10. As a player who lost a level or recalculated wrongly, I want to lower my limit below what I currently have prepared, so that the field never fights my typing.
11. As a player in that over-limit state, I want the chip to turn red, so that I can see the sheet needs attention without reading a dialog.
12. As a player in that over-limit state, I want my prepared spells left exactly as they are, so that the app never discards choices I made on my behalf.
13. As a player in that over-limit state, I want to keep un-preparing spells until I am back within the limit, so that I recover by my own choice of which to drop.
14. As a player in that over-limit state, I want preparing further spells to stay refused, so that the state can only get better, never worse.
15. As a sorcerer's or warlock's player, whose class prepares nothing, I want to leave the limit at zero and keep toggling freely, so that a feature for prepared casters does not constrain my character.
16. As a player with the limit at zero, I want no prepared-versus-limit chip shown at all, so that my Magie tab carries no number that means nothing for my class.
17. As an existing user upgrading the app, I want my saved characters to open with no limit applied, so that an upgrade never takes away a toggle that worked yesterday.
18. As an existing user upgrading the app, I want every spell I had already prepared to survive the upgrade untouched, so that an upgrade costs me no data.
19. As a player, I want cantrips excluded from the prepared count, so that spells I always have available do not consume choices I make each morning.
20. As a player, I want the limit field to refuse a negative number, so that I cannot type a value that has no meaning.
21. As a player, I want the limit field sitting near the spellcasting-ability field rather than inside the chip row, so that the row of chips stays what it already is — derived totals I read, not fields I edit.
22. As a player, I want the spell rows to look identical whether or not I am at my limit, so that the list stays scannable and does not restyle itself around a rule that rarely fires.
23. As a player, I want switching away from the Magie tab and back to preserve both my limit and my prepared spells, so that navigation never loses an edit.
24. As a player, I want the two existing chips (CD Magia, Bonus Attacco) to look exactly as they do today, so that a new neighbour chip changes nothing I already read fluently.
25. As a developer, I want the limit rule to live on the Character rather than in the tab, so that no future screen can write past the limit by touching the model directly.

## Implementation Decisions

### Character gains the limit as a plain field

The limit is a manually typed integer on Character, named `preparedSpellsMax` — following the existing `hpMax` suffix convention rather than a `max`-prefixed name. It is **not** derived from class and level. This is deliberate: CONTEXT.md records that the repo keeps 5e rules out of its model shape where it can (see the `Armor.addsDex` entry — a boolean flag instead of a light/medium/heavy armor *type*), the 5e preparation formula is not uniform across classes, and the Character's class is free text with no typed spellcasting-class concept to key a formula on. A derived limit would require inventing that concept.

### Zero means "no limit"

A limit of `0` disables the constraint entirely; the rule is active only above zero. Chosen over a nullable field and over "zero means zero preparable":

- It makes the Migration default (0) behavior-preserving for every Character already on disk. "Zero means zero" would silently strip the toggle from every saved Character on upgrade.
- It serves classes that know spells without preparing them: leave the field at zero, keep toggling freely.
- A nullable field would distinguish "no limit" from "exactly zero preparable", but the latter is not a state a player sets on purpose, and the nullable integer would have to be carried through model, JSON, DDL and UI to express it.

### The rule lives on Character, behind a method that reports its outcome

CONTEXT.md's Character entry states that a rule computable from a Character belongs to the Character, not to the screen showing it. Character therefore gains:

- A derived count of prepared spells, **excluding cantrips** (level 0).
- A derived predicate for whether another spell may be prepared.
- A toggle method taking the index of a spell in the Character's spell list, returning a boolean: `true` when the flag was flipped, `false` when the attempt was refused. It refuses in two cases — the spell is a cantrip, or the limit is already reached and the spell is not currently prepared. Un-preparing is never refused, which is what makes the over-limit state recoverable.

A boolean return is a deliberate deviation from the sibling spell-slot methods, which return nothing and no-op silently. The outcome here must reach the tab to drive its message; leaving the tab to pre-check the predicate itself would duplicate the condition in two places free to diverge.

### Over-limit is a tolerated state, not a prevented one

Lowering the limit below the current prepared count is accepted as typed. No spell is un-prepared automatically — there is no non-arbitrary rule for choosing which ones, and guessing would discard the player's decisions silently. Clamping the input instead was rejected because a numeric field is typed digit by digit, so intermediate values would be fought or mangled. The only changes in the over-limit state: the chip renders in the danger colour, and preparing more stays refused.

### The chip row stays derived; the input sits above it

The tab gains two distinct things:

- A **read-only chip** in the existing row beside CD Magia and Bonus Attacco, labelled **"Preparati"**, valued `<count>/<limit>`. Hidden entirely when the limit is zero — consistent with the tab's existing conditional rows (the spell-damage line appears only when equipment contributes spell damage) and with the equipment badge widget, which renders nothing when its delta is zero.
- A **numeric input** labelled **"Incantesimi Preparabili"**, placed with the spellcasting-ability field above the chip row, reusing the tab's shared numeric text field. Its setter clamps to zero or above, because that shared field's formatter admits a leading minus sign. The input is always visible, including at zero — otherwise the value would be unreachable.

Putting an input inside the chip row was rejected: both existing chips are derived, read-only totals, and mixing an editable control into that row breaks what the row means. A tap-to-edit dialog was rejected as undiscoverable for a value set once per level.

### The shared chip widget gains an optional colour

The shared chip widget currently hardcodes the accent colour for its value. It gains an optional value-colour parameter defaulting to accent, so the two existing call sites are untouched and the new chip can render in the danger colour when over limit. Preferred over duplicating the widget.

### Refusal is reported as a transient message

A refused prepare attempt shows a snack bar naming the limit, in Italian — e.g. "Limite incantesimi preparati raggiunto (5)". A silently inert control was rejected: mid-session, a tap that does nothing and says nothing reads as a bug. A refusal caused by tapping a **cantrip** shows no message — that tap is already inert today and is not a new rule to explain. A refused attempt does not mark the Character dirty, since nothing changed to persist.

### Spell rows are not restyled

Unprepared spell rows look identical whether or not the limit is reached. No dimming, no disabled styling. The chip and the snack bar carry the whole signal; recomputing row styling for a rarely-firing rule would add visual noise across the list.

### Schema change: one appended Migration step

The Database gains one column on the characters table, `prepared_spells_max`, integer, defaulting to 0; the schema version the SQLite adapter requests rises from 2 to 3. This is a single column addition — pure DDL, exactly the form ADR-0005's declarative ladder supports, with no Dart-side data transformation (the limitation that ADR records as unaddressed). Appended as a new step; released steps are not edited, so a fresh install and an upgraded install both arrive at identical schema through the same ladder.

The in-memory Database adapter needs no change: it round-trips Characters through the model's own map conversion rather than enumerating columns.

### No ADR

An integer field with a constraint is reversible — setting it to zero disables the behavior. The existing ADRs record structural decisions (the Database seam, typed ComponentData, the Migration ladder), not individual fields. The CONTEXT.md Character entry does get one line: it enumerates the derived rules that live on Character ("spell save DC and attack bonus, spell slots, death saves"), and adding a rule without extending that list would leave the document false.

## Testing Decisions

A good test here asserts behavior observable from outside the module under test: the count a Character reports, whether a prepare attempt succeeded, what survives a round-trip through persistence, what columns and values exist in a migrated Database. It does not assert how the count is computed, which private helpers exist, or the shape of internal state. Tests are named for the rule they pin, not the method they call.

Two seams, **both already present in the codebase**. No new seam is introduced.

### Seam 1 — Character (pure model, no I/O)

Prior art: the existing `Character spell slots` and `Character spellcasting derivation` groups in the Character model test, which drive the model directly with no widgets and no Database.

Covered:

- The prepared count excludes cantrips.
- The toggle returns `false` and changes nothing once the limit is reached.
- The toggle returns `false` for a cantrip regardless of the limit.
- Un-preparing always succeeds, including from an over-limit state.
- A limit of zero imposes no constraint: many spells can all be prepared.
- Lowering the limit below the prepared count leaves every prepared flag intact, and the over-limit condition is observable.
- The limit survives a round-trip through the model's map conversion, and a map missing the key yields zero.

### Seam 2 — the Migration ladder against a real SQLite database

Prior art: the existing armor/equipment v1-to-v2 group in the migration execution test, which opens a real `sqflite_common_ffi` database, writes a row at the old version, reopens at the new version, and asserts the data survived. ADR-0005 records this suite as the repo's deliberate, documented exception to being pure-Dart and I/O-free, precisely because step selection alone cannot prove data survives an upgrade.

Covered:

- A Character row written at version 2 still exists after upgrading to version 3, with its other fields unchanged.
- The new column exists after the upgrade and reads 0 for that pre-existing row.
- A Database created from scratch at version 3 has the same column as one upgraded into version 3.

### Deliberately not tested

The three UI-level behaviors — the snack bar on refusal, the chip's danger colour when over limit, and the chip being hidden at a limit of zero — are **not** covered. The widget seam that would cover them exists and is in use (the Magie tab group in the character-sheet screen test, with its tab-tapping helper), and this was a conscious choice by the developer against the recommendation to cover at least the snack bar. Consequence, recorded here rather than discovered later: nothing in the suite prevents a future change from removing the refusal message, the danger-coloured chip, or the hidden-at-zero rule. A follow-up ticket may add these.

## Out of Scope

- **A dedicated "prepared spells" section** between the spell slots and the spell list. Prepared spells remain visible only as flagged rows within the main list.
- **A "Prepara" button** distinct from the existing toggle. The toggle is the single gesture.
- **A substitution flow** — being offered a choice of which prepared spell to replace when attempting to prepare past the limit. The player un-prepares one, then prepares the other.
- **Deriving the limit from class and level**, and anything that implies it: a typed spellcasting-class concept, per-class preparation formulas, multiclass handling.
- **Distinguishing "prepared" from "known"** as separate concepts in the model. A spell in the Character's list is known; its flag says whether it is prepared today.
- **A "new day" / long-rest action** that clears every prepared flag at once.
- **Per-level preparation limits.** One limit covers all non-cantrip levels together.
- **Always-prepared spells** (domain spells, subclass grants) that should not count against the limit.
- **Ritual casting**, which in 5e can bypass preparation for some classes.
- **Widget-level tests** for the snack bar, the chip colour, and the hidden chip, as recorded above.
- **Any change to the spell-slot rows**, the spell-editing dialog, or the spell list's add/delete behavior.

## Further Notes

- **Glossary gap.** CONTEXT.md glosses Character, Armor, EquipmentItem and EquipmentBonus, but neither `Spell` nor `SpellSlot` has an entry, despite both being long-standing model concepts and despite this spec turning on what "prepared" means. Worth a `/domain-modeling` pass; not blocking this work. The one CONTEXT.md edit this spec does require is the added rule in the Character entry's list of derived rules.
- **No ADR conflict.** ADR-0005 (Migration ladder) is followed exactly: one appended declarative DDL step, no edit to a released step, no Dart-side data transformation. ADR-0002 (Database seam) is untouched — the in-memory adapter needs no change and the seam's interface does not move.
- **The existing prepared flag is already persisted**, so no data migration of spell payloads is needed; only the new Character-level column is added.
- **Upgrade path is behavior-preserving by construction**: default 0 plus "zero means no limit" means an upgraded install behaves exactly as it does today until the player types a limit.
