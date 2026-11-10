import 'dart:convert';

import 'package:enough_icalendar/enough_icalendar.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const maxCalendarBytes = 512 * 1024;
String schoolCalendarKey(String schoolId) =>
    'compass.preview.$schoolId.calendar';

class CalendarImportException implements Exception {
  const CalendarImportException(this.message);
  final String message;
}

class SchoolCalendarEvent {
  const SchoolCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location = '',
  });

  final String id;
  final String title;
  final DateTime start;

  /// Exclusive end, following iCalendar semantics.
  final DateTime end;
  final bool allDay;
  final String location;

  bool occursOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final until = DateTime(day.year, day.month, day.day + 1);
    if (end.isAtSameMomentAs(start)) {
      return !start.isBefore(from) && start.isBefore(until);
    }
    return start.isBefore(until) && end.isAfter(from);
  }
}

class ImportedSchoolCalendar {
  ImportedSchoolCalendar._(
    this.ics,
    this.importedAt,
    List<SchoolCalendarEvent> events, [
    this.subscriptionUrl,
  ]) : events = List.unmodifiable(events);

  final String ics;
  final String? subscriptionUrl;
  ImportedSchoolCalendar withSubscription(String? url) =>
      ImportedSchoolCalendar._(ics, importedAt, events, url);
  final DateTime importedAt;
  final List<SchoolCalendarEvent> events;

  factory ImportedSchoolCalendar.parse(String text, {DateTime? importedAt}) {
    if (utf8.encode(text).length > maxCalendarBytes) {
      throw const CalendarImportException(
        'Choose a calendar smaller than 512 KB.',
      );
    }
    final cleaned = text.replaceFirst('\uFEFF', '').trim();
    if (!cleaned.startsWith('BEGIN:VCALENDAR') ||
        !cleaned.endsWith('END:VCALENDAR')) {
      throw const CalendarImportException('Choose an iCalendar (.ics) file.');
    }
    try {
      // Parse components, folded lines and escaped text using the iCalendar
      // library, rather than attempting to parse ICS with regular expressions.
      // https://pub.dev/packages/enough_icalendar#parse-icalendar-requests
      // RFC 5545 section 3.1 removes exactly one continuation character.
      // Preserve any additional spaces before passing lines to the parser.
      final unfolded = cleaned.replaceAll(RegExp(r'\r?\n[ \t]'), '');
      final component = VComponent.parse(unfolded);
      if (component is! VCalendar) {
        throw const CalendarImportException('Choose an iCalendar (.ics) file.');
      }
      final entries = component.children.whereType<VEvent>().toList();
      if (entries.length > 2000) {
        throw const CalendarImportException(
          'Choose a calendar with at most 2,000 events.',
        );
      }
      final latest = <String, VEvent>{};
      for (var i = 0; i < entries.length; i++) {
        final event = entries[i];
        final id = event.getProperty('UID')?.textValue ?? 'event-$i';
        if ((latest[id]?.sequence ?? -1) <= (event.sequence ?? 0)) {
          latest[id] = event;
        }
      }
      final events = <SchoolCalendarEvent>[];
      for (final entry in latest.entries) {
        final event = entry.value;
        if (event.status == EventStatus.cancelled) continue;
        // The supplied school feed has expanded, all-day VEVENTs. Timezone
        // RRULEs live under VTIMEZONE and are deliberately not treated as events.
        // Reject unsupported event recurrence instead of showing false dates.
        if ([
          'RRULE',
          'RDATE',
          'RECURRENCE-ID',
        ].any((name) => event.getProperty(name) != null)) {
          throw const CalendarImportException(
            'Export recurring events as individual occurrences before importing.',
          );
        }
        final startProperty = event.getProperty<DateTimeProperty>('DTSTART');
        if (startProperty == null) {
          throw const CalendarImportException(
            'An event is missing its start date.',
          );
        }
        final allDay = startProperty.textValue.length == 8;
        final rawStart = _checkedDate(startProperty);
        final start = allDay
            ? DateTime(rawStart.year, rawStart.month, rawStart.day)
            : _localTime(rawStart, startProperty.timezoneId);
        final endProperty = event.getProperty<DateTimeProperty>('DTEND');
        final rawEnd = endProperty == null ? null : _checkedDate(endProperty);
        final end = rawEnd != null
            ? (allDay
                  ? DateTime(rawEnd.year, rawEnd.month, rawEnd.day)
                  : _localTime(
                      rawEnd,
                      endProperty?.timezoneId ?? startProperty.timezoneId,
                    ))
            : event.duration != null
            ? (allDay
                  ? DateTime(
                      start.year,
                      start.month,
                      start.day + event.duration!.toDuration().inDays,
                    )
                  : start.add(event.duration!.toDuration()))
            : allDay
            ? DateTime(start.year, start.month, start.day + 1)
            : start;
        if (end.isBefore(start) || (allDay && !end.isAfter(start))) {
          throw const CalendarImportException(
            'An event has an invalid end date.',
          );
        }
        // Some school exports contain HTML entities inside otherwise plain ICS
        // text. Decode them for display; Text widgets never render HTML markup.
        final title = _displayText(event, 'SUMMARY');
        final location = _displayText(event, 'LOCATION');
        events.add(
          SchoolCalendarEvent(
            id: entry.key,
            title: title?.trim().isNotEmpty == true
                ? title!.trim()
                : 'Untitled event',
            start: start,
            end: end,
            allDay: allDay,
            location: location ?? '',
          ),
        );
      }
      events.sort(_compareEvents);
      return ImportedSchoolCalendar._(
        cleaned,
        importedAt ?? DateTime.now(),
        events,
      );
    } on CalendarImportException {
      rethrow;
    } catch (_) {
      throw const CalendarImportException(
        'This calendar could not be read. Choose a valid .ics file.',
      );
    }
  }

  String toStorage() => jsonEncode({
    'version': 1,
    'ics': ics,
    'importedAt': importedAt.toIso8601String(),
    if (subscriptionUrl != null) 'subscriptionUrl': subscriptionUrl,
  });

  static ImportedSchoolCalendar? fromStorage(Object? value) {
    if (value is! String) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic> || data['ics'] is! String) return null;
      return ImportedSchoolCalendar.parse(
        data['ics'] as String,
        importedAt: DateTime.tryParse(data['importedAt'] as String? ?? ''),
      ).withSubscription(data['subscriptionUrl'] as String?);
    } catch (_) {
      return null;
    }
  }
}

final _unescape = HtmlUnescape();
String? _displayText(VEvent event, String name) {
  final value = event.getProperty<TextProperty>(name)?.value as String?;
  return value == null ? null : _unescape.convert(value);
}

DateTime _checkedDate(DateTimeProperty property) {
  final value = property.dateTime;
  final expected =
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
  if (!property.textValue.startsWith(expected)) {
    throw const CalendarImportException('An event contains an invalid date.');
  }
  return value;
}

bool _timezonesReady = false;
DateTime _localTime(DateTime value, String? timezoneId) {
  if (value.isUtc) return value.toLocal();
  if (timezoneId == null || timezoneId.isEmpty) return value;
  if (!_timezonesReady) {
    // Bundled IANA data; this performs no network request.
    // https://pub.dev/packages/timezone#initialization
    tz_data.initializeTimeZones();
    _timezonesReady = true;
  }
  return tz.TZDateTime(
    tz.getLocation(timezoneId),
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  ).toLocal();
}

int _compareEvents(SchoolCalendarEvent a, SchoolCalendarEvent b) {
  final byDate = a.start.compareTo(b.start);
  return byDate != 0 ? byDate : a.title.compareTo(b.title);
}

List<SchoolCalendarEvent> calendarEventsOn(
  Iterable<SchoolCalendarEvent> events,
  DateTime day,
) =>
    events.where((event) => event.occursOn(day)).toList()..sort(_compareEvents);

// Only public fictional data is bundled. Personal imports stay in local storage.
List<SchoolCalendarEvent> sampleCalendarEvents(
  String schoolId,
  DateTime month,
) {
  final schedules = switch (schoolId) {
    'alderline' => [
      (
        title: 'New student welcome tour',
        weekday: DateTime.monday,
        hour: 12,
        location: 'Student Commons',
      ),
      (
        title: 'Robotics open lab',
        weekday: DateTime.thursday,
        hour: 15,
        location: 'Makerspace',
      ),
      (
        title: 'Friday spirit day',
        weekday: DateTime.friday,
        hour: -1,
        location: 'Campus',
      ),
    ],
    'cedarbrook' => [
      (
        title: 'Transfer student breakfast',
        weekday: DateTime.tuesday,
        hour: 8,
        location: 'Courtyard',
      ),
      (
        title: 'Stage crew open house',
        weekday: DateTime.wednesday,
        hour: 15,
        location: 'Auditorium lobby',
      ),
      (
        title: 'Garden volunteer hour',
        weekday: DateTime.friday,
        hour: 15,
        location: 'Greenhouse',
      ),
    ],
    _ => <({String title, int weekday, int hour, String location})>[],
  };
  final events = <SchoolCalendarEvent>[];
  final count = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= count; day++) {
    final date = DateTime(month.year, month.month, day);
    for (final schedule in schedules.where(
      (item) => item.weekday == date.weekday,
    )) {
      final allDay = schedule.hour < 0;
      final start = DateTime(
        date.year,
        date.month,
        date.day,
        allDay ? 0 : schedule.hour,
        schedule.hour == 15 ? 30 : 0,
      );
      events.add(
        SchoolCalendarEvent(
          id: '$schoolId-${schedule.weekday}-$day',
          title: schedule.title,
          start: start,
          end: allDay
              ? DateTime(date.year, date.month, date.day + 1)
              : start.add(const Duration(hours: 1)),
          allDay: allDay,
          location: schedule.location,
        ),
      );
    }
  }
  return events..sort(_compareEvents);
}
