# Audit fixes

Work proceeds in the order of the September 13 audit. Each completed item is verified and pushed separately. Existing Xcode workspace UI state is excluded from commits.

- 1: Guarded missing series IDs in selection/deletion and action visibility. Added XCTest regressions and activated the unit-test target.
- 2: Series editing preserves all occurrences and uses series order rather than unrelated array neighbors.
- 3: Removed index-based inline category renaming; reordering is independent of renaming. Names must be nonempty and unique; rename/delete repairs defaults and event references. Five regression tests pass.
- 4: Replaced repeating snapshots and hidden 15-minute reminders with sorted, dated local summaries; reconcile on changes, launch, activation, significant time changes, and best-effort background refresh. Permission/status is visible. Eight tests pass, including DST and future coverage. iOS limits the pending queue; up to 64 event days are queued and Settings shows coverage. Background refresh timing is controlled by iOS: https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate
- 5: Preferences use one shared store; migration preserves the latest settings and explicit None. Removed launch reset. Nine tests pass.
- 6: Add form initializes once from its incoming category/date; shared form no longer overwrites None or colors on appearance. Explicit repeat edits preserve custom choices. App and widget build pass.
- 7: Registered the widget URL scheme, validated routes, and wired Next Event to its event ID. Ten tests pass; simulator successfully opens upnext://addEvent.
- 8: Bounded repeat inputs and generator guards prevent duplicate/nonadvancing loops; date ranges and whitespace titles are validated. Eleven tests pass.
- 9: All event writes go through AppData; saves refresh both widgets and reminders once. Removed redundant reloads and manual change notifications. App/widget build pass.
- 10: Corrected Time Bot/Time Piece icon identifiers, show system icon-change errors, and read the actual selected icon. Build passes; all 16 alternate icon identifiers exist in the built Info.plist.
- 11: Spanning events stay visible, View More is available from the empty state, and history is reachable with chronological grouping and deletion by event ID. Regression added; verification runs in the isolated audit checkout to avoid concurrent UI edits.
- 12: Added guarded storage, a readable backup, preservation of unreadable originals, visible recovery controls, and tolerant decoding of legacy optional fields. Fourteen tests pass, including refusal to overwrite corrupt data.
- 13: Saved recurrence rules distinguish end modes, anchor month/year dates, refill the horizon, and preserve occurrence IDs, exceptions, and deletions. Legacy end dates are preserved unless existing occurrences prove the old end was ignored. Added four recurrence tests; syntax check passes. Simulator validation pending while Xcode is being reinstalled.
- 14: Timeline uses one deterministic interval layout, clips ongoing events at today, reuses only free lanes, and includes column spacing in widths. Added overlap regression; syntax check passes. Simulator validation pending Xcode reinstall.
- 15: Native add/event/category/icon buttons, accessible names and color choices, bounded form sizing, and Reduce Motion support. Applied fixing-accessibility skill. Syntax check passes; device/VoiceOver validation pending Xcode reinstall.
- 16: Widget entries advance at midnight, filter against their entry date, retain final-day events, use event colors, expose dynamic category options, and represent no event explicitly. Xcode reinstalled; all 20 tests pass, including items 13–15.
- 17–20: In progress.
