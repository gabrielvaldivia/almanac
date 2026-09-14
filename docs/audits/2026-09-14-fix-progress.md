# Audit fixes — September 14, 2026

The user requested one change at a time, ordered by impact relative to effort, with verification, a push, and a phone build/install after every change. Existing features, data compatibility, and presentation are preserved except where a documented bug requires correction.

The baseline checkpoint is `b39fc0b`. It includes the previously verified widget/composer/list work and the audit evidence. Two upstream UI-test changes were incorporated; the timeline test now measures visibility against the actual overlay and starts drags within the visible list. The corrected test and composer check passed. The checkpoint was pushed, built, installed, and launched on Gabe's iPhone.

## Order

Start with small, low-risk fixes that remove a freeze or unintended edits (F17, F15, F10, F11), then recurrence correctness (F01/F02), current list issues (F06/F05/F23), parser/editor issues, remaining recurrence/widget/storage issues, accessibility/release packaging, and safe cleanup. Reorder when implementation reveals a simpler fix or a dependency. No feature removal or broad redesign is part of this work.

## Changes

### 1. F17 — Large-series edit performance

Replaced one full-array scan per occurrence with an ID lookup built once. The existing update semantics and ordering are unchanged. Added a maximum-size series test covering IDs, dates, occurrence indices, exception flags, and an unrelated interleaved event. All 18 targeted Release tests passed. The 10,000-occurrence edit measured 33 ms versus 4.35 s in the audit (simulator measurements). The signed device build passed. Pushed as `9722e14` and installed on the phone. Automatic launch was blocked by the phone being locked.

### 2. F15 — Canceling category creation

The full editor now keeps its category selection until a new category is actually saved. A UI regression verifies Cancel → Save → relaunch retains Work; the existing category-creation flow also passed. Signed phone build passed. Pushed as `a920341` and installed on the phone.

### 3. F10 — Category saves preserve color overrides

Category metadata saves and renames retain event colors. Changing a category color updates events matching its previous color while preserving different event colors. A storage regression covers no-op saves, renames, recoloring, unrelated events, defaults, IDs, and persistence. All 110 unit tests and the category rename UI test passed; signed phone build passed. The first run exposed an overbroad test equality assertion because legacy decoding supplies optional repeat defaults. The regression now checks persisted colors, categories, IDs, and dates; the full unit rerun passed. App fix `cce0f7a` was pushed and installed; the assertion correction is a separate follow-up commit.

## Remaining

F01–F09, F11–F14, F16, and F18–F23 remain open until explicitly recorded below. The rare long-inactivity boundary and the unused/redundant-code inventory remain part of the work. The original audit is retained as historical evidence; its reproduction probes intentionally assert the old defects and are not shipping regression tests.
