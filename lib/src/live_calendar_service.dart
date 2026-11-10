import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'school_calendar_data.dart';

String calendarFeedKey(String schoolId) =>
    'compass.preview.$schoolId.calendar.feed';
String calendarPromptKey(String schoolId, [String? accountEmail]) =>
    'compass.preview.$schoolId.calendar.prompted${accountEmail == null ? '' : '.${Uri.encodeComponent(accountEmail)}'}';
Uri normalizeCalendarUrl(String value) {
  if (value.trim().length > 4096) {
    throw const CalendarImportException('Choose a valid calendar link.');
  }
  final uri = Uri.tryParse(
    value.trim().replaceFirst(
      RegExp(r'^webcal:', caseSensitive: false),
      'https:',
    ),
  );
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443)) {
    throw const CalendarImportException(
      'Use a secure calendar subscription link.',
    );
  }
  final host = uri.host.toLowerCase();
  if (!RegExp(r'^[a-z0-9-]+\.myschoolapp\.com$').hasMatch(host) &&
      ![
        'calendar.google.com',
        'outlook.office365.com',
        'outlook.live.com',
      ].contains(host) &&
      !RegExp(r'^p\d+-caldav\.icloud\.com$').hasMatch(host)) {
    throw const CalendarImportException(
      'This calendar provider is not supported yet. You can import an .ics file.',
    );
  }
  return uri;
}

class LiveCalendarService {
  const LiveCalendarService();
  Future<ImportedSchoolCalendar> fetch(String link) async {
    final uri = normalizeCalendarUrl(link);
    final client = http.Client();
    try {
      return await _download(client, uri).timeout(const Duration(seconds: 20));
    } on CalendarImportException {
      rethrow;
    } catch (_) {
      throw const CalendarImportException(
        'Could not update the calendar. Your saved events are still available.',
      );
    } finally {
      client.close();
    }
  }

  Future<ImportedSchoolCalendar> _download(http.Client client, Uri uri) async {
    final request = kIsWeb
        ? http.Request('POST', Uri.base.resolve('/api/calendar'))
        : http.Request('GET', uri);
    if (kIsWeb) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'url': uri.toString()});
    } else {
      request.followRedirects = false;
      request.headers['Accept'] = 'text/calendar';
    }
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final chunks = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      chunks.addAll(chunk);
      if (chunks.length > maxCalendarBytes * 2) {
        throw const CalendarImportException(
          'Choose a calendar smaller than 512 KB.',
        );
      }
    }
    final text = utf8.decode(chunks);
    if (response.statusCode != 200) {
      String? message;
      if (kIsWeb) {
        try {
          message = (jsonDecode(text) as Map)['error'] as String?;
        } catch (_) {}
      }
      throw CalendarImportException(
        message ?? 'The calendar could not be reached. Please try again.',
      );
    }
    if (kIsWeb) {
      try {
        final data = jsonDecode(text) as Map<String, dynamic>;
        return ImportedSchoolCalendar.parse(
          data['ics'] as String,
          importedAt: DateTime.tryParse(data['fetchedAt'] as String? ?? ''),
        );
      } on CalendarImportException {
        rethrow;
      } catch (_) {
        throw const CalendarImportException(
          'Calendar connection is unavailable in this preview. Import an .ics file instead.',
        );
      }
    }
    return ImportedSchoolCalendar.parse(text);
  }
}
