import 'package:shared_preferences/shared_preferences.dart';

import 'local_accounts.dart';
import 'school_calendar_data.dart';
import 'school_demo.dart';

String accountCalendarKey(DemoSchool school, LocalAccount account) =>
    '${schoolCalendarKey(school.id)}.account.${Uri.encodeComponent(account.email)}';

/// Assign the pre-login calendar to one local account only. An explicit null
/// snapshot is retained so reset calendars can never resurrect legacy data.
Future<void> migrateAccountCalendar(
  SharedPreferencesAsync preferences,
  Map<String, Object?> saved,
  DemoSchool school,
  LocalAccount account,
) async {
  final ownerKey = '${schoolCalendarKey(school.id)}.legacyOwner';
  var owner = saved[ownerKey] as String?;
  if (owner == null) {
    owner = account.email;
    await preferences.setString(ownerKey, owner);
    saved[ownerKey] = owner;
  }
  final key = accountCalendarKey(school, account);
  if (saved.containsKey(key)) return;
  final previous = owner == account.email
      ? saved[schoolCalendarKey(school.id)]
      : null;
  final value = previous is String ? previous : 'null';
  await preferences.setString(key, value);
  saved[key] = value;
}
