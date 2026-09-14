# Timeline and event sheet

Events live in one persistent sheet. Its handle is inside the sheet and has two
stops: Large shows a compact timeline above a tall event list; Small gives most
of the screen to the timeline. The sheet follows the finger during a drag and
settles at the nearest size on release. Tapping the handle switches sizes.
VoiceOver users can choose either size from the handle's Actions.

Horizontal timeline scrolling moves the sheet to the nearest event day. Both
sizes retain the same vertical list and scroll position, including same-day
stacks. Tap an event row to edit it; tapping its timeline marker highlights and
reveals that row with haptic feedback. The month heading stays sticky in the Large sheet and fades out, collapsing its
space as the sheet is pulled down. Relative day labels remain sticky in both sizes. Visible-row tracking never issues a scroll command, avoiding feedback
and flicker while the sheet resizes.

With the Small sheet, pinch to move continuously between linear days, weeks,
and months. The date beneath the fingers stays anchored while labels crossfade.
Calendar months retain their actual lengths, and nearby markers occupy separate
lanes at smaller scales. The timeline header offers Show days, Show weeks, and
Show months as VoiceOver actions. Resizing the sheet preserves the zoom level
and the visible dates.
Dots move down as the sheet shrinks, staying between the days and the sheet.
Calendar dividers become more visible as the timeline grows.

The plus button floats over the sheet, whose list reaches the bottom edge. Extra
content padding lets the final event scroll clear of the button. Event entry
collapses after a downward swipe or a tap on surrounding content, retaining its
draft and pill overrides. Its leading dot follows the resolved event color.

`TimelineTests` covers sheet limits, drag geometry, calendar selection, pinch
anchoring, month boundaries, marker collisions, and bounded view allocation.
`EventFlowTests` covers sheet resizing, timeline-driven list scrolling, real
pinch gestures, editing, composer dismissal, date parsing, and persistence.
