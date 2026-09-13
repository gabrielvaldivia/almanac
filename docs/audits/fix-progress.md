# Audit fixes

Work proceeds in the order of the September 13 audit. Each completed item is verified and pushed separately. Existing Xcode workspace UI state is excluded from commits.

- 1: Guarded missing series IDs in selection/deletion and action visibility. Added XCTest regressions and activated the unit-test target.
- 2: Series editing preserves all occurrences and uses series order rather than unrelated array neighbors.
- 3: Removed index-based inline category renaming; reordering is independent of renaming. Names must be nonempty and unique; rename/delete repairs defaults and event references. Five regression tests pass.
- 4–20: In progress.
