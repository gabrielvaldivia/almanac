# iPhone Duo

Almanac adapts to both displays of iPhone Duo with the same layout it uses on
other iPhones. The closed outer display is compact width. The open inner
display is regular width and height, in every orientation. Opening, closing,
folding, and rotating the device only resize the scene. The timeline position,
the event list, and any draft in the composer stay in place.

Navigation uses stacks throughout: the main screen and every sheet. In regular
widths, `NavigationView` shows the main screen as a collapsed sidebar next to an
empty detail column. That would have left the inner display blank, and it also
affected large iPhones in landscape.

Settings and Today are plain bar buttons, each with a title and a symbol. The
system can place them in a vertical bar on the side of the display, which shows
the symbol, or in the overflow menu, which shows the title. Wherever the system
uses a vertical bar (the closed outer display, and the open inner display in
landscape), Filter and Add move out of their floating buttons into the same bar
as bottom-bar items, after a gap below Settings and Today. Tapping Add grows the
composer out of the button on the bar's side, and dismissing it shrinks the
composer back in. The button leaves the bar while the composer is open, and
comes last among the bottom items, so the filter keeps its place. SwiftUI can't match
geometry across the bar's hosting view, so the composer reads the button's
window frame when it opens and closes, then scales from it. Where bars stay
horizontal, including every other iPhone, the floating buttons remain and the
plus morphs into the composer as before. This uses `toolbarVerticalEdge`, which
needs Xcode 27.1. Builds from older Xcode versions keep the floating buttons
everywhere. Sheet toolbars use
semantic placements (`cancellationAction` and `confirmationAction`), so vertical
bars order Cancel or Close first and Save next. Manage Categories uses the
toolbar API instead of the deprecated `navigationBarItems`.

When the inner display is open like a book, in landscape, the main screen
splits at the fold. Months, stacked in a vertical scroll, fill the side before
the fold (the left, in left-to-right languages) and the event list fills the
other side. The months take the timeline's place. The split follows the fold
that `GeometryProxy.reservedRegions(kind: .division)` reports, including while
the display is flat. A horizontal fold (the inner display in portrait), the
outer display, Split View on one side of the fold, and every other iPhone keep
the timeline above the list. This needs Xcode 27.1. Each column's color reaches
the top edge; the navigation bar paints no background over them.

Events appear as colored bars, with the category filter applied. An event
across several days is one bar across them, squared off where it continues into
the next week or month. Longer events take the top lanes, and a day with more
events than fit counts the rest. A day too small for bars shows dots. The weekday letters stay pinned above the
months. Tapping a day scrolls the list to that day, or to the next day with
events. Scrolling the months by hand scrolls the list to the first event of the
month at the top. Scrolling the list instead brings its month to the top of the
months. A tap only moves the list; days are never selected or highlighted.
Today appears in the bar whenever
another month is at the top. The months run from the earliest listed day
through the end of the loaded list, and reaching the last one loads another
year, as Show More does. The list keeps its scroll position when the months
appear beside it or give way to the timeline.

Dragging the handle between the months and the list resizes the months. The
handle sits in a lane of fixed width, the hinge's width or at least 16 points,
so its spacing stays the same wherever the edge is. Within 24 points of the fold the edge snaps back to it, with a tick.
The months keep at least 280 points and the list at least 320. The width is
remembered as a share of the content width, and VoiceOver can adjust it by
swiping up or down on the handle.

Content follows the safe area, which can be asymmetric when bars run down one
side or two apps share the inner display. Dates, markers, rows, and floating
controls stay inside it. The gray timeline band and its divider extend under
side bars and beside the camera, as background content.

The composer grows from the add button. In a regular-width window that is wider
than it is tall, such as the inner display opened like a book or a large iPhone
in landscape, it centers on the window at up to 500 points wide, even beside a
side bar, so it crosses the fold. Compact and taller-than-wide windows keep the
full-width composer.

When the timeline's width changes, the focused date keeps its relative position
on screen. Before this, a date focused near the trailing edge of the wide inner
display fell offscreen after closing the device, while the month heading and the
list still followed it.

The app supports all four orientations. The inner display does not honor
orientation locks, and apps that take part in multitasking must support every
orientation.

## Building and testing

The app fills the displays only when built with Xcode 27.1 and the iOS 27.1
SDK. Builds from Xcode 26 run in an iPhone-sized window that leaves room
around the status bar and camera. CI still builds with Xcode 26.6 on an
iPhone 17 Pro simulator.

Check these in Xcode 27.1 Device Hub with the iPhone Duo simulator:

- Closed, in portrait and landscape: bars move to the side, and the composer and
  filter clear them.
- Open, flat and folded like a book: the months and the event list fill the
  display, the composer centers on the display, and Settings pushes in place.
- Open, tall and folded like a laptop: the timeline and list keep their
  positions through the fold.
- Split View on both sides: safe areas and controls follow the shared edge.
- Close the device after pinching near the trailing edge of the open timeline:
  the focused month stays visible and the heading matches it.
- Open in landscape: the months and the list meet at the fold, with the
  months' gray reaching under a leading bar and no band across the top. Tap
  days, scroll the months, and scroll the list; each side follows the other.
  Rotate to portrait and close the device: the timeline returns at the list's
  date.
- Sheets on both displays: Edit Event, Dates, Repeat, Add Category, Manage
  Categories, and Contact Birthdays.

`TimelineTests` covers focus preservation across width changes, the
composer's width limits, splitting at a fold, and the month grid's months,
weeks, and events.

## Possible follow-ups

These need the iOS 27.1 SDK:

- Add the `systemExtraLargePortrait` widget family for the inner Home Screen.
- Run the UI tests on the iPhone Duo simulator in CI.
