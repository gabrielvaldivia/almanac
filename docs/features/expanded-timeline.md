# Expanded timeline

Drag the handle down to fill the available screen with the timeline. Drag it up
to return to the compact timeline or collapse it. The handle tracks the finger
and snaps to one of these three positions on release.

In the expanded view, event cards float at the bottom in horizontal pages. Events
on the same displayed calendar day form a stack; tapping the stack arranges its
cards vertically. Tap an individual card to edit its event.

Pinch the full-screen timeline to move continuously between linear days, weeks,
and months. The date beneath the fingers stays anchored as spacing changes;
labels crossfade between calendar units without snapping. Months retain their
actual lengths. Nearby markers use separate lanes at smaller scales. VoiceOver
users can choose Show days, Show weeks, or Show months from the header's Actions.
Returning to the compact view restores day spacing at the selected date.

Scrolling the timeline selects the nearest card page without changing the chosen
timeline date. Swiping cards moves the timeline at its current zoom. Each page
fits one complete stack, including after rotation. The visible month range stays
above the timeline. Category filtering applies to both views. Reduce Motion
disables animated paging; pinch geometry follows the gesture directly.

Regression coverage lives in `TimelineTests` (calendar mapping, pinch anchoring,
month lengths, page alignment, synchronization, resizing, filtering, and bounded
view allocation) and the timeline flows in `EventFlowTests` (handle drag, real
pinches, paging, same-day selection, editing, and return to the event list).
