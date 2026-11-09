import 'package:compass_flutter/src/school_calendar_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/calendar_fixtures.dart';

void main() {
  test('all-day dates are civil dates and DTEND is exclusive', () {
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture(allDayEventFixture('Campus break', end: '20261110')),
    );
    final event = calendar.events.single;
    expect(event.allDay, isTrue);
    expect(event.start, DateTime(2026, 11, 8));
    expect(event.occursOn(DateTime(2026, 11, 8)), isTrue);
    expect(event.occursOn(DateTime(2026, 11, 9)), isTrue);
    expect(event.occursOn(DateTime(2026, 11, 10)), isFalse);
    expect(event.occursOn(DateTime(2026, 11, 7)), isFalse);
  });

  test(
    'folded/escaped text, missing end and timezone components are handled',
    () {
      final calendar = ImportedSchoolCalendar.parse(
        calendarFixture(r'''BEGIN:VTIMEZONE
TZID:America/Los_Angeles
BEGIN:STANDARD
DTSTART:20261101T020000
TZOFFSETFROM:-0700
TZOFFSETTO:-0800
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:folded
DTSTAMP:20260101T000000Z
DTSTART;VALUE=DATE:20261108
SUMMARY:Biology\, lab review
  and discussion &amp; questions&#160;
LOCATION:Library&#8212;East
END:VEVENT'''),
      );
      expect(calendar.events, hasLength(1));
      expect(
        calendar.events.single.title,
        'Biology, lab review and discussion & questions',
      );
      expect(calendar.events.single.location, 'Library—East');
      expect(calendar.events.single.end, DateTime(2026, 11, 9));
    },
  );

  test('UTC and IANA timezone timed events represent the correct instant', () {
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture('''BEGIN:VEVENT
UID:utc
DTSTAMP:20260101T000000Z
DTSTART:20261108T140000Z
DTEND:20261108T150000Z
SUMMARY:UTC event
END:VEVENT
BEGIN:VEVENT
UID:ny
DTSTAMP:20260101T000000Z
DTSTART;TZID=America/New_York:20261108T090000
DTEND;TZID=America/New_York:20261108T100000
SUMMARY:New York event
END:VEVENT'''),
    );
    expect(
      calendar.events.map((e) => e.start.toUtc()),
      everyElement(DateTime.utc(2026, 11, 8, 14)),
    );
    expect(calendar.events.every((e) => !e.allDay), isTrue);
  });

  test('an all-day duration remains one civil day across daylight saving', () {
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture('''BEGIN:VEVENT
UID:dst
DTSTAMP:20260101T000000Z
DTSTART;VALUE=DATE:20260308
DURATION:P1D
SUMMARY:One day only
END:VEVENT'''),
    );
    expect(calendar.events.single.end, DateTime(2026, 3, 9));
    expect(calendar.events.single.occursOn(DateTime(2026, 3, 9)), isFalse);
  });

  test(
    'newest sequence wins, including cancellation of a previous version',
    () {
      final calendar = ImportedSchoolCalendar.parse(
        calendarFixture(
          [
            allDayEventFixture('Old', extra: 'SEQUENCE:1'),
            allDayEventFixture('Updated', extra: 'SEQUENCE:3'),
            allDayEventFixture('Stale', extra: 'SEQUENCE:2'),
            allDayEventFixture('Cancelled', uid: 'gone', extra: 'SEQUENCE:1'),
            allDayEventFixture(
              'Cancelled',
              uid: 'gone',
              extra: 'SEQUENCE:2\nSTATUS:CANCELLED',
            ),
          ].join('\n'),
        ),
      );
      expect(calendar.events.map((event) => event.title), ['Updated']);
    },
  );

  test('invalid dates, invalid files and unsupported event recurrence are explicit', () {
    for (final text in [
      '<html>Login</html>',
      calendarFixture(allDayEventFixture('Bad date', date: '20260230')),
      calendarFixture(allDayEventFixture('Bad end', end: '20261107')),
      calendarFixture(
        allDayEventFixture('Repeats', extra: 'RRULE:FREQ=WEEKLY'),
      ),
      'x' * (maxCalendarBytes + 1),
    ]) {
      expect(
        () => ImportedSchoolCalendar.parse(text),
        throwsA(isA<CalendarImportException>()),
      );
    }
    expect(ImportedSchoolCalendar.parse(calendarFixture('')).events, isEmpty);
  });

  test('imports round-trip locally and malformed stored data is tolerated', () {
    final calendar = ImportedSchoolCalendar.parse(
      calendarFixture(allDayEventFixture('Study session')),
      importedAt: DateTime(2026, 11, 8, 12),
    );
    final restored = ImportedSchoolCalendar.fromStorage(calendar.toStorage())!;
    expect(restored.events.single.title, 'Study session');
    expect(restored.importedAt, DateTime(2026, 11, 8, 12));
    for (final invalid in [null, 42, '{bad', '[]', '{"ics": "bad"}']) {
      expect(ImportedSchoolCalendar.fromStorage(invalid), isNull);
    }
    expect(
      schoolCalendarKey('alderline'),
      'compass.preview.alderline.calendar',
    );
    expect(
      schoolCalendarKey('cedarbrook'),
      isNot(schoolCalendarKey('alderline')),
    );
  });

  test('sample calendars are separate and cover the requested month only', () {
    final month = DateTime(2026, 11);
    final alderline = sampleCalendarEvents('alderline', month);
    final cedarbrook = sampleCalendarEvents('cedarbrook', month);
    expect(alderline, isNotEmpty);
    expect(cedarbrook, isNotEmpty);
    expect(alderline.every((event) => event.start.month == 11), isTrue);
    expect(
      alderline
          .map((e) => e.title)
          .toSet()
          .intersection(cedarbrook.map((e) => e.title).toSet()),
      isEmpty,
    );
    expect(sampleCalendarEvents('unknown', month), isEmpty);
  });
}
