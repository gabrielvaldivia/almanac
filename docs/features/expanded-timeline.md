# Expanded timeline

Drag the handle down to fill the available screen with the timeline. Drag it up
to return to the compact timeline or collapse it. The handle tracks the finger
and snaps to one of these three positions on release.

In the expanded view, event cards float at the bottom in horizontal pages. Events
on the same displayed calendar day form a stack; the event count opens a menu
containing every event in that stack. Tap a card or menu item to edit its event.

Scrolling the timeline selects the nearest card page without changing the chosen
timeline date. Swiping the cards moves the timeline to their date. Each page fits
one complete stack, including after rotation. The month stays above the timeline.
Category filtering applies to both views. Reduce Motion disables animated paging.

Regression coverage lives in `TimelineTests` (calendar mapping, page alignment,
scroll synchronization, resizing, filtering, and bounded view allocation) and
`EventFlowTests.testExpandTimelineScrollFloatingStacksAndOpenStackedEvent`
(handle drag, paging, same-day selection, editing, and return to the event list).
