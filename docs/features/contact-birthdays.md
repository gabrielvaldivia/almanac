# Contact birthdays

Settings → Contacts → Sync Birthdays opens a review sheet. Contacts access is requested only after Continue. New birthdays start selected; each row has a switch, and search and Select All / Deselect All apply to the visible results. Save commits the selection. Cancel leaves events and saved choices unchanged.

This is a manual sync: reopening the review reads the latest contact names and birthday dates. Saving updates selected imports without duplicating their event IDs. Turning off a previously imported birthday removes that contact’s imported events. Previously excluded or deleted birthdays stay unselected, while newly discovered contacts start selected. Contacts unavailable to the current permission scope are preserved. The app never changes Contacts.

Imports use the Birthdays category and indefinite yearly recurrence. A birth year is optional. February 29 uses February 28 in non-leap years and returns to February 29 in leap years. Non-Gregorian birthdays retain their source calendar when a Gregorian birthday is unavailable. Dates remain local calendar days when traveling. Existing recurrence exclusions and individual edits survive an unchanged sync.

Only contact identifiers, formatted names, and birthday calendar information are retained with imported events. Names and birthday fields are fetched through CNContactStore; phone numbers, email addresses, notes, and photos are not requested. Limited access has a Choose More Contacts action. Denied access has an Open Settings action; restricted, empty, and failed loads have dedicated states.

Implementation follows Apple’s [Contacts access guidance](https://developer.apple.com/documentation/contacts/accessing-the-contact-store) and [limited-access API](https://developer.apple.com/documentation/contacts/cnauthorizationstatus/limited).

## Validation

- Full iOS 18.5 simulator suite: 63 unit/integration tests and 3 UI tests passed.
- Eleven birthday tests cover selection, repeat imports, omitted contacts, source changes, leap days, time zones, non-Gregorian recurrence, storage, and deleted occurrences.
- UI test covers individual switches, save and relaunch, remembered selections, cancel, repeated sync, and bulk deselection. It uses synthetic contacts behind an explicit DEBUG-only launch argument.
- Signed Release device build passed. Real address-book permissions and limited-contact selection still require validation on an iPhone.

Local evidence: `/tmp/almanac-birthdays-final.log`, `/tmp/almanac-birthdays-final.xcresult`, and `/tmp/almanac-birthdays-device-build.log`.
