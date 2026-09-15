# Audit fixes — September 14, 2026

The user requested one change at a time, ordered by impact relative to effort, with verification, a push, and a phone build/install after every change. Existing features, data compatibility, and presentation are preserved except where a documented bug requires correction.

The baseline checkpoint is `b39fc0b`. It includes the previously verified widget/composer/list work and the audit evidence. Two upstream UI-test changes were incorporated; the timeline test now measures visibility against the actual overlay and starts drags within the visible list. The corrected test and composer check passed. The checkpoint was pushed, built, installed, and launched on Gabe's iPhone.

The user subsequently waived phone installation and requested continued work. F06 was pushed as `b686973`; its build passed, but the phone disconnected before installation. From F05 onward, each change is tested, Release-built, and pushed without waiting for a phone.

## Order

Start with small, low-risk fixes that remove a freeze or unintended edits (F17, F15, F10, F11), then recurrence correctness (F01/F02), current list issues (F06/F05/F23), parser/editor issues, remaining recurrence/widget/storage issues, accessibility/release packaging, and safe cleanup. Reorder when implementation reveals a simpler fix or a dependency. No feature removal or broad redesign is part of this work.

## Changes

### 1. F17 — Large-series edit performance

Replaced one full-array scan per occurrence with an ID lookup built once. The existing update semantics and ordering are unchanged. Added a maximum-size series test covering IDs, dates, occurrence indices, exception flags, and an unrelated interleaved event. All 18 targeted Release tests passed. The 10,000-occurrence edit measured 33 ms versus 4.35 s in the audit (simulator measurements). The signed device build passed. Pushed as `9722e14` and installed on the phone. Automatic launch was blocked by the phone being locked.

### 2. F15 — Canceling category creation

The full editor now keeps its category selection until a new category is actually saved. A UI regression verifies Cancel → Save → relaunch retains Work; the existing category-creation flow also passed. Signed phone build passed. Pushed as `a920341` and installed on the phone.

### 3. F10 — Category saves preserve color overrides

Category metadata saves and renames retain event colors. Changing a category color updates events matching its previous color while preserving different event colors. A storage regression covers no-op saves, renames, recoloring, unrelated events, defaults, IDs, and persistence. All 110 unit tests and the category rename UI test passed; signed phone build passed. The first run exposed an overbroad test equality assertion because legacy decoding supplies optional repeat defaults. The regression now checks persisted colors, categories, IDs, and dates; the full unit rerun passed. App fix `cce0f7a` was pushed and installed; the assertion correction is a separate follow-up commit.

### 4. F11 — Category edits respect event recovery

Renames and deletions now share model-level recovery guards. Both payloads save before publishing changed categories/events/defaults; a save error restores the previous payloads and readable backups. A recovery message explains why editing is paused. Category creation and reordering retain their prior behavior. All 113 unit tests and the normal category rename/edit/delete UI flow passed, including new corruption, rollback, and deletion regressions. The signed phone build passed. Pushed as `2e481fd` and installed on the phone.

### 5. F01 — Recurrence ending changes preserve history

Existing occurrence indices that still satisfy the edited rule are retained independently of the future-generation horizon. Surviving IDs and date exceptions remain intact, exclusions remain excluded, and missing years are not backfilled. Anchors/endings retain the supplied calendar through encoding. All 115 unit tests passed, followed by 20 focused calendar/recurrence/birthday tests after the storage-calendar refinement. Signed phone build passed. Pushed as `7a4343d` and installed on the phone.

### 6. F02 — Month/year moves follow the recurrence rule

Series dates are recalculated by occurrence index instead of uniformly shifting month-end dates. Moving a middle occurrence retains its requested day even when deriving the anchor crosses a shorter month; an optional backward-compatible rule field preserves that day. Explicit date exceptions keep their date offset, metadata-only exceptions follow the rule, and equivalent custom intervals keep the anchor. The common edit path now uses one traversal. All 119 unit tests passed, followed by 36 focused tests after adding the short-month/date-exception edge case (120 unit tests now exist). Signed phone build passed.

### 7. F06 — Timeline focus follows uncovered rows

Row tracking now uses the actual timeline overlay edge. Before shrinking the overlay while scrolling the list, it also checks that the proposed height would not reveal an earlier event group and send focus backward. Only date crossings reach the parent, and the native scroll inset stays stable. All 32 timeline unit tests and four timeline UI regressions passed, including forward/reverse scrolling through crowded dates; the new regression also passed on iOS 18.5. The successful screenshot was inspected. A test-only exact-frame assertion was adjusted for floating point rounding. Signed phone build passed. F02 was pushed as `324340f` and installed before starting this change.

### 8. F05 — Show more generates recurring events for each page

Explicit page boundaries now extend recurrence generation before advancing the list window. Existing occurrences and IDs remain unchanged, and a failed save does not publish unsaved events or advance the page. Future availability checks the rule's ending/exclusions and uses the series category rather than an exception's category. All 125 unit tests and three paging UI tests passed, including sparse recurrence across an empty year, persistence, and stable scroll position. App/widget Release build passed.

### 9. F23 — Loaded pages stay relative to the current day

The list refreshes its calendar anchor on foregrounding and significant time changes while retaining the number of pages already loaded. Recurrences are extended before publishing the refreshed boundary. Tests cover midnight, time-zone travel, daylight saving, preserved history, and unchanged sparse paging/scroll behavior: 49 unit tests and the paging UI regression passed. App/widget Release build passed. F05 was pushed as `96f1885`.

### 10. F07 — Invalid dates remain unresolved beside valid repeat text

Named-date detection now covers the parser's day-first, abbreviated, and ordinal forms. A successfully parsed cadence carries an unresolved-start-date flag, so it cannot suppress date correction. Choosing a date resolves only that issue and retains the cadence. All 39 quick-entry tests passed, including 15 invalid date/cadence combinations and valid counterparts. App/widget Release build passed. F23 was pushed as `a20992b`.

### 11. F08 — Ordinary titles are not mistaken for schedules

Recurrence recognition now requires a cadence-like phrase, and incomplete-ending hints require a preceding title. Titles containing Every, Until, Through, Starting, or Daily retain their text, including when a real date or cadence follows them. Malformed supported schedules still request correction. All 40 quick-entry tests and the composer correction UI test passed. App/widget Release build passed. F07 was pushed as `7740d8b`.

### 12. F09 — Creating a historical finite series adds its events

New series with an explicit end date generate from the requested start through the inclusive end, subject to the existing 10,000-occurrence safeguard. This does not alter replenishment or editing's history-retention policy. Regressions cover short historical ranges, a leap year, a single-day series, and persisted identities. All 129 unit tests passed. App/widget Release build passed. F08 was pushed as `a5e1e44`.

### 13. F16 — Confirm the initially selected end date

The Add End Date sheet has a Done action that commits its selected date; selecting another date retains the existing immediate-save behavior. Both paths share one commit method. A UI regression passed for today's date and a future start, saving/relaunching, and removing the end date. App/widget Release build passed. F09 was pushed as `97882be`.

### 14. F22 — Cross-year ranges retain year context

Rows and widgets now include both years for ranges crossing a year boundary. The composer shares the year-inclusion rule and retains its compact formatting. All 44 calendar/quick-entry tests passed, covering current, past, future, and ongoing ranges. App/widget Release build passed. F16 was pushed as `2ce6f2c`.

### 15. F14 — Timeline dates survive time-zone changes

The timeline retains its anchor's civil date when local midnight changes and invalidates event/axis layout on calendar or day changes, including unchanged event arrays. Direct date/Today navigation refreshes this state as well. All 37 timeline/calendar tests passed, including four time zones, the date line, stable event positions, and correct Today navigation. App/widget Release build passed. F22 was pushed as `885c626`.

### 16. F12 — Widget and app agree on generated occurrence IDs

New recurring occurrences derive UUID v5 identifiers from the persisted series ID and occurrence index. Saved IDs remain untouched, including legacy random IDs and exceptions. Tests independently validate the UUID algorithm and widget/app refill link resolution, persistence, and later replenishment. All 133 unit tests passed. App/widget Release build passed. F14 was pushed as `eeb1aee`.

### 17. F20 — App and widget include required privacy manifests

Added target-specific manifests for existing preference access: app-only settings (`CA92.1`) and App Group storage (`1C8F.1`) in the app, and App Group storage in the widget. Reasons were checked against [Apple's reference](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons?language=objc). Plist/project validation and the Release build passed; both packaged manifests and their reason sets were inspected. No runtime logic changed. F12 was pushed as `a123cbd`.

### 18. F03 — Deleting one sparse occurrence retains its future schedule

Deleting the last loaded occurrence now retains the next valid occurrence beyond the normal horizon when the rule still has future dates. Exclusions and finite endings are respected, and unrelated events remain unchanged. The existing occurrence-based storage format is preserved. All 42 recurrence/regression/birthday tests passed across the initial run and corrected recurrence rerun; the new persistence fixture now consistently supplies its explicit calendar when creating and decoding the rule. App/widget Release build passed. F20 was pushed as `e0473e0`.

### 19. F04 — Individual edits stay confined to their occurrence

Before editing or deleting the last unmodified occurrence, retain the next valid unmodified occurrence as the series' metadata source. This keeps the existing storage format while isolating title, duration, color, category, notifications, and repeat edits. Finite exhausted series gain no extra dates. All 137 unit tests and a full editor → This Event Only → relaunch → page forward UI regression passed. Final app/widget Release build passed without source warnings. Metadata already overwritten by older app versions cannot be reconstructed automatically. F03 was pushed as `56cc78b`.

### 20. F13 — Widget category filters survive renames and name reuse

Categories acquire persistent IDs while existing name-only payloads remain readable. Widget options keep their String parameter for configuration compatibility and display category names with stable internal values. A persistent legacy-name map follows renames and retains deleted identities, so reusing an old name cannot redirect an existing widget. Category transactions also roll back this metadata. All 138 unit tests passed, followed by 21 storage/regression tests covering unreadable identity metadata. Both Release targets passed, including the updated App Intents provider. F04 was pushed as `b56fdd0`.

## Remaining

F18–F19 and F21 remain open until explicitly recorded below. The rare long-inactivity boundary and the unused/redundant-code inventory remain part of the work. The original audit is retained as historical evidence; its reproduction probes intentionally assert the old defects and are not shipping regression tests.
