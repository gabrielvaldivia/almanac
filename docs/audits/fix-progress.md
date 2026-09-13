# Audit fixes

Work proceeds in the order of the September 13 audit. Each completed item is verified and pushed separately. Existing Xcode workspace UI state is excluded from commits.

- 1: Guarded missing series IDs in selection/deletion and action visibility. Added XCTest regressions and activated the unit-test target.
- 2: Series editing preserves all occurrences and uses series order rather than unrelated array neighbors.
- 3: Removed index-based inline category renaming; reordering is independent of renaming. Names must be nonempty and unique; rename/delete repairs defaults and event references. Five regression tests pass.
- 4: Replaced repeating snapshots and hidden 15-minute reminders with sorted, dated local summaries; reconcile on changes, launch, activation, significant time changes, and best-effort background refresh. Permission/status is visible. Eight tests pass, including DST and future coverage. iOS limits the pending queue; up to 64 event days are queued and Settings shows coverage. Background refresh timing is controlled by iOS: https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate
- 5: Preferences use one shared store; migration preserves the latest settings and explicit None. Removed launch reset. Nine tests pass.
- 6: Add form initializes once from its incoming category/date; shared form no longer overwrites None or colors on appearance. Explicit repeat edits preserve custom choices. App and widget build pass.
- 7–20: In progress.
