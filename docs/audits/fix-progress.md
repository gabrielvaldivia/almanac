# Audit fixes and validation

All 20 areas from the [ranked September 13 audit](2026-09-13.md) are implemented. The order below preserves the audit's impact-versus-effort ranking. Each area was committed and pushed separately; final integration fixes and regression coverage complete item 20.

Items 1–11 are on `main`. Items 12–20 are on `codex/audit-fixes`, based on those commits. The remaining work was isolated in `/private/tmp/almanac-fixes` because other tasks are editing the original checkout. Their uncommitted UI changes and Xcode workspace state are preserved.

| Rank | Fixed behavior | Commit |
| --- | --- | --- |
| 1 | Missing series IDs cannot select or delete unrelated events. | `ff73f3c` |
| 2 | Editing a series preserves every occurrence and its ID; no destructive 100-event cutoff. | `f10b464` |
| 3 | Category reorder and rename are independent; names are validated and event/default references repaired. | `8533c34` |
| 4 | Reminders use dated event-day summaries, explicit permission, visible status, and queue reconciliation. | `c475bc3` |
| 5 | Preferences share one store, survive migration and relaunch, and preserve explicit None. | `7df134e` |
| 6 | Add Event honors its incoming category and preserves deliberate form choices. | `d95286c` |
| 7 | Registered widget links open Add Event or the selected event. | `650492f` |
| 8 | Repeat counts, intervals, titles, and date ranges are validated before saving. | `1060f38` |
| 9 | Centralized event saves refresh both widgets and reminders. | `eae3500` |
| 10 | Time Bot and Time Piece use valid alternate-icon identifiers; failures are visible. | `ca96f92` |
| 11 | Spanning/future events and history remain reachable; deletion uses event identity. | `071a8a1` |
| 12 | Unreadable event data is preserved; writes pause and a readable backup can be restored. | `5a4572a` |
| 13 | Anchored recurrence rules preserve month/year behavior, end modes, IDs, exceptions, and deleted occurrences; future occurrences replenish. | `8ced15e` |
| 14 | Timeline lanes handle overlaps and ongoing ranges consistently, including column spacing. | `ae1bf8d` |
| 15 | Primary controls use native buttons and accessible labels, usable target sizes, and Reduce Motion. | `832494e` |
| 16 | Widgets refresh across midnight and align event dates, categories, colors, and empty states with the app. | `0731472` |
| 17 | StoreKit tracks verified purchases/refunds, refreshes entitlements, and shows price, pending/error/restore states and subscription management. | `8a28a8f` |
| 18 | Event and recurrence dates preserve calendar days while traveling; reminder preferences preserve local hour/minute. | `495afc7` |
| 19 | Shared models/date formatting replace duplicate implementations; removed inactive code, Google dependencies, sample live activity, event-content logs, and widget app-form/StoreKit dependencies. | `e8e0a08` |
| 20 | Activated unit/UI targets, added StoreKit configuration and CI, tested asynchronous scheduling and real editing flows, and fixed issues found during integration. | Final regression commit |

## Additional fixes found by regression tests

- The edit sheet could display the selected event but save using a placeholder event ID, silently leaving the original unchanged. Presentation and editing now use the selected event's identity. Category edit sheets also derive presentation from their selected category.
- A failed notification request no longer prevents the remaining requests from being scheduled.
- Failed event loading preserves existing reminders instead of replacing them with an empty plan. Preference refresh happens after successful loading.
- A fresh CI run exposed stale refund entitlements. Verified revocations now override cached entitlement records, expired transactions are excluded, and older overlapping refreshes cannot overwrite newer state. The StoreKit test creates its own app-state observer after configuring the test catalog, waits for product loading, and finishes its purchase before requesting a refund. This avoids inheriting the host app’s earlier observer and matches the app purchase lifecycle.
- Category date decoding accepts legacy numeric dates and newer calendar-day values; unreadable category data is preserved and editing pauses.

## Verification

- **26 unit/integration tests passed, zero failures**, including series deletion/editing, recurrence anchoring/refill/exceptions, storage recovery, preference migration, time zones, DST, notification capacity/reconciliation, timeline overlap, and widget boundaries.
- The StoreKit test purchases a verified test subscription, confirms the entitlement, refunds it, and observes the app's transaction listener remove the entitlement. StoreKit changes are asynchronous; the test waits for the observed state change.
- **Two UI tests passed, zero failures** on iOS 18.5 and again after final navigation changes on iOS 26.5: create/edit/relaunch/delete an event; create/rename/relaunch/reopen/delete a category.
- **Release device builds passed** for the app and widget extension, including signing with the existing developer team. The signed update was installed in place and launched successfully on the connected iPhone (iOS 26.7); no uninstall was performed. This is a development-signed installation, not an App Store release.
- All 16 alternate-icon identifiers were checked against the built Info.plist. The registered widget URL scheme was opened successfully in the simulator.
- `git diff --check` passes. Tests use dedicated simulators and test-created records.

Xcode 26.6's iOS 26.5 simulator rejected StoreKit test configuration with `SKInternalErrorDomain Code=3` and returned no test products. The same purchase/refund test passes on iOS 18.5. The older Xcode 16.4 CI runner also failed to deliver the refund update within the test timeout. CI explicitly uses Xcode 26.3 and iOS 18.5, both listed in the [macOS 15 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), rather than suppressing the test failure.

Reproduce the complete suite with an available iOS 18.5 iPhone simulator:

```sh
xcodebuild -project 'Up Next/Up Next.xcodeproj' -scheme 'Up Next' \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  CODE_SIGN_IDENTITY=- test
```

The shared `Almanac.xctestplan` enables both test targets. `.github/workflows/ios-tests.yml` runs the suite for pull requests and pushes to main/audit branches and preserves the result bundle.

## Notification behavior and remaining device checks

These are local iOS notifications. Each event day receives one nonrepeating summary at the user's selected local time; ongoing events appear through their inclusive final day. Elapsed reminder times are skipped rather than shifted onto a different day. Edits/deletions replace or remove pending requests; legacy repeating snapshots and hidden 15-minute alerts are removed.

Up to 64 upcoming event days are queued. Launch, activation, significant time changes, and best-effort background refresh replenish coverage; Settings displays the final scheduled date. iOS controls [background refresh timing](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate), so indefinite personalized delivery cannot be guaranteed when the app never opens and background execution is withheld.

Physical-device delivery with the app closed, travel on a real device, VoiceOver, and production App Store purchases still need device verification. The updated build has been installed and launched on the connected iPhone. Enable notifications if needed and check the scheduled-through date in Settings. The regression tests prove scheduling and state behavior; they do not prove delivery on the user's phone.

All-day events retain their calendar day while traveling. Legacy timestamps migrate using the current device timezone because the old format did not save the original timezone. Legacy recurrence end dates are preserved unless existing occurrences prove the old end was ignored; ambiguous old data is not guessed. Pro is described as a supporter subscription, with existing app features remaining available.
