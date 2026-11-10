import 'package:compass_flutter/src/calendar_storage.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_calendar_data.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/calendar_fixtures.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  const first = LocalAccount(
    email: 'alex@alderline.example',
    name: 'Alex Chen',
    grade: 11,
    salt: '',
    passwordHash: '',
  );
  const other = LocalAccount(
    email: 'sam@alderline.example',
    name: 'Sam Chen',
    grade: 10,
    salt: '',
    passwordHash: '',
  );
  test('legacy calendar migrates to only the first account, without crossing schools', () async {
    final prefs = SharedPreferencesAsync(), school = demoSchools.first;
    final legacy = ImportedSchoolCalendar.parse(
      calendarFixture(allDayEventFixture('Original school calendar')),
    ).withSubscription('https://demo.myschoolapp.com/feed?z=synthetic');
    final saved = <String, Object?>{
      schoolCalendarKey(school.id): legacy.toStorage(),
    };
    await migrateAccountCalendar(prefs, saved, school, first);
    await migrateAccountCalendar(prefs, saved, school, other);
    expect(
      ImportedSchoolCalendar.fromStorage(
        saved[accountCalendarKey(school, first)],
      )!.subscriptionUrl,
      legacy.subscriptionUrl,
    );
    expect(
      ImportedSchoolCalendar.fromStorage(
        saved[accountCalendarKey(school, other)],
      ),
      isNull,
    );
    expect(
      accountCalendarKey(school, first),
      isNot(accountCalendarKey(demoSchools.last, first)),
    );
  });
  test(
    'an explicitly reset account calendar never reappears from legacy storage',
    () async {
      final prefs = SharedPreferencesAsync(), school = demoSchools.first;
      final saved = <String, Object?>{
        schoolCalendarKey(school.id): calendarFixture(
          allDayEventFixture('Legacy'),
        ),
      };
      await migrateAccountCalendar(prefs, saved, school, first);
      final key = accountCalendarKey(school, first);
      saved[key] = 'null';
      await prefs.setString(key, 'null');
      await migrateAccountCalendar(prefs, saved, school, first);
      expect(saved[key], 'null');
      expect(await prefs.getString(key), 'null');
    },
  );
}
