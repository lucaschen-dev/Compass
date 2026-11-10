import 'dart:convert';

import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('school suffix is immutable and invalid/cross-school usernames are rejected', () {
    final accounts = LocalAccounts(
      SharedPreferencesAsync(),
      demoSchools.first,
      null,
    );
    expect(accounts.emailFor('Alex.Chen'), 'alex.chen@alderline.example');
    expect(
      accounts.emailFor('alex@alderline.example'),
      'alex@alderline.example',
    );
    for (final value in [
      'a@gmail.com',
      'a@cedarbrook.example',
      '@alderline.example',
      'a b',
      '',
    ]) {
      expect(() => accounts.emailFor(value), throwsA(isA<AccountException>()));
    }
  });
  test(
    'local demo passwords are salted, verified and never saved as plaintext',
    () async {
      final prefs = SharedPreferencesAsync(), school = demoSchools.first;
      final accounts = LocalAccounts(prefs, school, null);
      const password = 'Demo-password-2026';
      final account = await accounts.create(
        username: 'alex',
        password: password,
        name: 'Alex Chen',
        grade: 11,
      );
      final other = await accounts.create(
        username: 'sam',
        password: password,
        name: 'Sam Chen',
        grade: 10,
      );
      expect(account.salt, isNot(other.salt));
      expect(account.passwordHash, isNot(other.passwordHash));
      final stored = (await prefs.getString(accountStoreKey(school)))!;
      expect(stored, isNot(contains(password)));
      expect(jsonDecode(stored), hasLength(2));
      final restored = LocalAccounts(prefs, school, stored);
      expect((await restored.login('alex', password)).name, 'Alex Chen');
      await expectLater(
        restored.login('alex', 'wrong-password'),
        throwsA(isA<AccountException>()),
      );
      await expectLater(
        restored.create(
          username: 'alex',
          password: password,
          name: 'Alex Chen',
          grade: 11,
        ),
        throwsA(isA<AccountException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
