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
as bottom-bar items, after a gap below Settings and Today. The composer then
opens on the bar's side. Where bars stay horizontal, including every other
iPhone, the floating buttons remain. This uses `toolbarVerticalEdge`, which
needs Xcode 27.1. Builds from older Xcode versions keep the floating buttons
everywhere. Sheet toolbars use
semantic placements (`cancellationAction` and `confirmationAction`), so vertical
bars order Cancel or Close first and Save next. Manage Categories uses the
toolbar API instead of the deprecated `navigationBarItems`.

Content follows the safe area, which can be asymmetric when bars run down one
side or two apps share the inner display. Dates, markers, rows, and floating
controls stay inside it. The gray timeline band and its divider extend under
side bars and beside the camera, as background content.

The composer grows from the add button. In a regular-width window that is wider
than it is tall, such as the inner display opened like a book, it stays on the
add button's side of the window's center. The inner display folds down that
center. The composer therefore never spans the hinge, and on large iPhones in
landscape it keeps roughly its portrait width. Compact and taller-than-wide
windows keep the full-width composer.

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
- Open, flat and folded like a book: the event list and timeline fill the
  display, the composer stays on one side of the fold, and Settings pushes in
  place.
- Open, tall and folded like a laptop: the timeline and list keep their
  positions through the fold.
- Split View on both sides: safe areas and controls follow the shared edge.
- Close the device after pinching near the trailing edge of the open timeline:
  the focused month stays visible and the heading matches it.
- Sheets on both displays: Edit Event, Dates, Repeat, Add Category, Manage
  Categories, and Contact Birthdays.

`TimelineTests` covers focus preservation across width changes and the
composer's width limits.

## Possible follow-ups

These need the iOS 27.1 SDK:

- Position the composer with `GeometryProxy.reservedRegions(kind: .division)`,
  using the real fold instead of the window's center, and keep the full width
  while the inner display is flat.
- Add the `systemExtraLargePortrait` widget family for the inner Home Screen.
- Run the UI tests on the iPhone Duo simulator in CI.
