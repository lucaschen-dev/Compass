import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

import 'data.dart';
import 'api.dart';

class CalendarParser {
  static Uri validate(String input) {
    final u = Uri.tryParse(input.trim());
    if (u == null ||
        u.scheme != 'https' ||
        u.host.toLowerCase() != 'buckley.myschoolapp.com' ||
        u.userInfo.isNotEmpty ||
        u.hasFragment ||
        (u.hasPort && u.port != 443) ||
        u.path.toLowerCase() != '/podium/feed/ical.aspx' ||
        (u.queryParameters.entries
            .where((e) => e.key.toLowerCase() == 'z' && e.value.isNotEmpty)
            .isEmpty)) {
      throw ApiException(0, 'Paste the full HTTPS Feed URL from My Buckley.');
    }
    return u;
  }

  static String plain(String raw) {
    var s = raw.replaceAllMapped(
      RegExp(r'\\(.)', dotAll: true),
      (m) => m[1]!.toLowerCase() == 'n' ? '\n' : m[1]!,
    );
    s = s
        .replaceAll(
          RegExp(r'<br\s*/?>|</p>|</div>|</tr>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    for (final e in {
      '&nbsp;': ' ',
      '&#160;': ' ',
      '&quot;': '"',
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
    }.entries) {
      s = s.replaceAll(e.key, e.value);
    }
    return s.trim();
  }

  static String zoneAlias(String z) =>
      {
        'Pacific Standard Time': 'America/Los_Angeles',
        'Eastern Standard Time': 'America/New_York',
        'UTC': 'Etc/UTC',
      }[z] ??
      z;
  static (DateTime, bool)? date(Json? field, String zone) {
    if (field == null) return null;
    final value = text(field, 'value');
    final params = field['params'] as Json;
    final allDay = params['VALUE'] == 'DATE' || value.length == 8;
    try {
      final parts = RegExp(
        allDay
            ? r'^(\d{4})(\d{2})(\d{2})$'
            : r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$',
      ).firstMatch(value);
      if (parts == null) return null;
      final y = int.parse(parts[1]!),
          m = int.parse(parts[2]!),
          d = int.parse(parts[3]!);
      final h = allDay ? 0 : int.parse(parts[4]!),
          n = allDay ? 0 : int.parse(parts[5]!),
          sec = allDay ? 0 : int.parse(parts[6]!);
      final dt = allDay
          ? DateTime(y, m, d)
          : tz.TZDateTime(
              tz.getLocation(
                value.endsWith('Z')
                    ? 'Etc/UTC'
                    : zoneAlias(text(params, 'TZID', zone)),
              ),
              y,
              m,
              d,
              h,
              n,
              sec,
            );
      if (dt.year != y ||
          dt.month != m ||
          dt.day != d ||
          dt.hour != h ||
          dt.minute != n ||
          dt.second != sec) {
        return null;
      }
      return (dt, allDay);
    } catch (_) {
      return null;
    }
  }

  static (DateTime, bool)? descriptionDate(String description, String zone) {
    final value = RegExp(
      r'^\s*(?:due(?:\s+date)?|due\s+on)\s*[:=]\s*([^\n]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(description)?[1]?.trim();
    if (value == null) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) {
      final iso = DateTime.tryParse(value);
      if (iso != null) return (iso, false);
    }
    for (final format in [
      'M/d/yyyy h:mm:ss a',
      'M/d/yyyy h:mm a',
      'M/d/yyyy H:mm',
      'yyyy-MM-dd HH:mm:ss',
      'MMM d, yyyy h:mm a',
      'MMMM d, yyyy h:mm a',
      'M/d/yyyy',
      'yyyy-MM-dd',
      'MMM d, yyyy',
      'MMMM d, yyyy',
    ]) {
      try {
        final day = !format.contains('H') && !format.contains('h');
        final d = DateFormat(format, 'en_US').parseStrict(value);
        return (
          day
              ? d
              : tz.TZDateTime(
                  tz.getLocation(zoneAlias(zone)),
                  d.year,
                  d.month,
                  d.day,
                  d.hour,
                  d.minute,
                  d.second,
                ),
          day,
        );
      } catch (_) {}
    }
    return null;
  }

  static List<Json> parse(String raw) {
    final lines = <String>[];
    for (final line
        in raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += line.substring(1);
      } else {
        lines.add(line.replaceAll('\ufeff', ''));
      }
    }
    if (!lines.contains('BEGIN:VCALENDAR') ||
        !lines.contains('END:VCALENDAR')) {
      throw ApiException(
        0,
        'This link did not return a calendar. Use Feed URL, not the Assignment Center address.',
      );
    }
    final stack = <String>[];
    var fields = <String, Json>{};
    final results = <String, Json>{};
    final revisions = <String, int>{};
    var zone = 'America/Los_Angeles', count = 0;
    for (final line in lines) {
      var quoted = false, index = -1;
      for (var i = 0; i < line.length; i++) {
        if (line[i] == '"') quoted = !quoted;
        if (line[i] == ':' && !quoted) {
          index = i;
          break;
        }
      }
      if (index < 0) continue;
      final head = line.substring(0, index).split(';'),
          name = head[0].toUpperCase(),
          value = line.substring(index + 1);
      if (name == 'BEGIN') {
        stack.add(value.toUpperCase());
        if (value == 'VEVENT' || value == 'VTODO') fields = {};
        continue;
      }
      if (name == 'END') {
        if (stack.isEmpty || stack.last != value.toUpperCase()) {
          throw ApiException(
            0,
            'The calendar is incomplete. Try syncing again.',
          );
        }
        if (value == 'VEVENT' || value == 'VTODO') {
          if (++count > 5000) {
            throw ApiException(0, 'This calendar contains too many items.');
          }
          String val(String key) => text(fields[key] ?? {}, 'value');
          final title = plain(
                val('SUMMARY').isEmpty ? 'Untitled assignment' : val('SUMMARY'),
              ),
              details = plain(
                val('DESCRIPTION').isEmpty
                    ? val('X-ALT-DESC')
                    : val('DESCRIPTION'),
              );
          final uid = val('UID');
          final stable = base64Url.encode(
            utf8.encode('$title|$details|${val('DTSTART')}'),
          );
          final id =
              '${uid.isEmpty ? 'no-uid-$stable' : uid}|${val('RECURRENCE-ID')}';
          final sequence = int.tryParse(val('SEQUENCE')) ?? 0;
          if (sequence >= (revisions[id] ?? -1)) {
            revisions[id] = sequence;
            results.remove(id);
            if (val('STATUS').toUpperCase() != 'CANCELLED') {
              var due =
                  date(
                    fields['DUE'] ??
                        fields['X-DUE-DATE'] ??
                        fields['X-BLACKBAUD-DUE-DATE'],
                    zone,
                  ) ??
                  descriptionDate(details, zone);
              final end = date(fields['DTEND'], zone);
              if (due == null && end != null && end.$2) {
                final e = end.$1;
                due = (DateTime(e.year, e.month, e.day - 1), true);
              }
              final start = date(fields['DTSTART'], zone),
                  dated = due ?? date(fields['DTSTART'], zone);
              final notes = <String>[];
              if (['RRULE', 'RDATE', 'EXDATE'].any(fields.containsKey)) {
                notes.add(
                  'Recurring calendar entry. Open My Buckley for all occurrences.',
                );
              }
              if (dated == null) {
                notes.add('No readable date in this feed entry.');
              }
              if (uid.isEmpty) {
                notes.add('No calendar ID; matched using entry contents.');
              }
              final link = Uri.tryParse(val('URL'));
              final safe =
                  link != null &&
                  link.scheme == 'https' &&
                  link.host.toLowerCase() == 'buckley.myschoolapp.com' &&
                  link.userInfo.isEmpty &&
                  !link.path.toLowerCase().contains('/feed/');
              String? points;
              for (final key in [
                'X-POINTS',
                'X-POINTS-POSSIBLE',
                'X-MAX-POINTS',
                'X-BLACKBAUD-POINTS',
              ]) {
                if (RegExp(r'^\s*\d+(?:\.\d+)?\s*$').hasMatch(val(key))) {
                  points = val(key).trim();
                  break;
                }
              }
              points ??= RegExp(
                r'\b(?:points(?:\s+possible)?|max(?:imum)?\s+points|total\s+points)\s*[:=]\s*(\d+(?:\.\d+)?)\b',
                caseSensitive: false,
              ).firstMatch(details)?[1];
              results[id] = {
                'id': id,
                'title': title,
                'details': details,
                'date': dated?.$1.toIso8601String(),
                'allDay': dated?.$2 ?? true,
                'due': due?.$1.toIso8601String(),
                'start': start?.$1.toIso8601String(),
                'points': points,
                'link': safe ? link.toString() : null,
                'note': notes.join(' '),
              };
            }
          }
        }
        stack.removeLast();
        continue;
      }
      if (stack.lastOrNull == 'VCALENDAR' && name == 'X-WR-TIMEZONE') {
        zone = value;
      }
      if (stack.lastOrNull == 'VEVENT' || stack.lastOrNull == 'VTODO') {
        final params = <String, dynamic>{};
        for (final p in head.skip(1)) {
          final eq = p.indexOf('=');
          if (eq > 0) {
            params[p.substring(0, eq).toUpperCase()] = p
                .substring(eq + 1)
                .replaceAll('"', '');
          }
        }
        fields.putIfAbsent(name, () => {'value': value, 'params': params});
      }
    }
    if (stack.isNotEmpty) throw ApiException(0, 'The calendar is incomplete.');
    final sorted = results.values.toList();
    sorted.sort(
      (a, b) => (text(a, 'date', '9999')).compareTo(text(b, 'date', '9999')),
    );
    return sorted;
  }
}

class PlannerStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final FlutterSecureStorage vault;
  String scope = '';
  List<Json> todos = [], assignments = [];
  String? error, lastSync;
  bool connected = false, syncing = false;
  int generation = 0;
  PlannerStore(
    this.prefs, {
    this.vault = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });
  Future<void> load(String next) async {
    if (next == scope) return;
    scope = next;
    final epoch = ++generation;
    syncing = false;
    error = null;
    try {
      todos = rows(jsonDecode(prefs.getString('todos.$scope') ?? '[]'));
      assignments = rows(
        jsonDecode(prefs.getString('assignments.$scope') ?? '[]'),
      );
    } catch (_) {
      todos = [];
      assignments = [];
    }
    lastSync = prefs.getString('synced.$scope');
    connected = false;
    final feed = await vault.read(key: 'feed.$next');
    if (epoch != generation) return;
    connected = feed != null;
    if (!connected) assignments = [];
    notifyListeners();
  }

  Future<void> saveTodo(Json todo) async {
    final title = text(todo, 'title').trim();
    if (title.isEmpty || title.length > 200) {
      throw ApiException(0, 'Add a task of up to 200 characters.');
    }
    todo['title'] = title;
    final i = todos.indexWhere((t) => t['id'] == todo['id']);
    if (i < 0) {
      todos.add(todo);
    } else {
      todos[i] = todo;
    }
    await prefs.setString('todos.$scope', jsonEncode(todos));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    todos.removeWhere((t) => t['id'] == id);
    await prefs.setString('todos.$scope', jsonEncode(todos));
    notifyListeners();
  }

  Future<void> addAssignment(Json a) async {
    if (todos.any((t) => t['assignmentID'] == a['id'])) return;
    await saveTodo({
      'id': newID(),
      'title': a['title'],
      'notes': a['details'],
      'due': a['due'] ?? a['date'],
      'assignmentID': a['id'],
      'completed': false,
    });
  }

  Future<void> connect(String input) async {
    await sync(input: input);
  }

  Future<void> sync({String? input}) async {
    if (syncing) return;
    final epoch = generation, account = scope;
    syncing = true;
    error = null;
    notifyListeners();
    final client = http.Client();
    try {
      final saved = input ?? await vault.read(key: 'feed.$account');
      if (saved == null) return;
      final uri = CalendarParser.validate(saved);
      if (kIsWeb) {
        throw ApiException(
          0,
          'Use the Mac or mobile app to connect a private school feed.',
        );
      }
      final req = http.Request('GET', uri)..followRedirects = false;
      req.headers['Accept'] = 'text/calendar';
      final response = await client
          .send(req)
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw ApiException(
          0,
          'The feed could not be opened. Copy a fresh Feed URL from My Buckley.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 35),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw ApiException(0, 'This calendar is too large to import.');
        }
      }
      final items = CalendarParser.parse(utf8.decode(bytes));
      if (epoch != generation) return;
      await vault.write(key: 'feed.$account', value: saved);
      if (epoch != generation) return;
      assignments = items;
      connected = true;
      lastSync = DateTime.now().toIso8601String();
      await prefs.setString('assignments.$account', jsonEncode(items));
      await prefs.setString('synced.$account', lastSync!);
    } catch (_) {
      if (epoch == generation) {
        error = 'Sync failed. Check the Feed URL and your connection. Your saved assignments are still available.';
      }
    } finally {
      client.close();
      if (epoch == generation) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    final account = scope;
    generation++;
    syncing = false;
    connected = false;
    assignments = [];
    lastSync = null;
    error = null;
    await vault.delete(key: 'feed.$account');
    await prefs.remove('assignments.$account');
    await prefs.remove('synced.$account');
    notifyListeners();
  }
}
