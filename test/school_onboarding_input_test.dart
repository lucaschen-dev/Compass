import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_auth_page.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'first-login name accepts the first keystroke and composing text: ${brightness.name}',
      (tester) async {
        final original = SharedPreferencesAsyncPlatform.instance;
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final accounts = LocalAccounts(
          SharedPreferencesAsync(),
          demoSchools.first,
          null,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: localCompassTheme(brightness),
            home: SchoolAuthPage(school: demoSchools.first, accounts: accounts),
          ),
        );
        await tapVisible(tester, find.text('First login'));
        await tester.enterText(find.byType(TextField), 'name.input');
        await tapVisible(tester, find.text('Set up a local demo account'));
        await tester.enterText(
          find.byType(TextField).first,
          'Synthetic-Input-2026!',
        );
        await tester.enterText(
          find.byType(TextField).last,
          'Synthetic-Input-2026!',
        );
        // Reproduce a password input still active when the next step opens.
        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        final passwordClient = tester.testTextInput.log
            .lastWhere((call) => call.method == 'TextInput.setClient')
            .arguments[0];
        await tapVisible(tester, find.text('Continue'));
        final nameClient = tester.testTextInput.log
            .lastWhere((call) => call.method == 'TextInput.setClient')
            .arguments[0];
        expect(
          nameClient,
          isNot(passwordClient),
          reason: 'The name must get a fresh input connection instead of reusing the password client.',
        );
        final name = tester.widget<TextField>(find.byType(TextField));
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(
          editable.focusNode.hasFocus,
          isTrue,
          reason: 'After Continue, the name must own keyboard focus, not the removed password field or button.',
        );
        expect(name.obscureText, isFalse);
        expect(
          name.controller!.text,
          isEmpty,
          reason: 'Password text must never carry into the name.',
        );
        tester.testTextInput.enterText('Alex Chen');
        await tester.pump();
        expect(name.controller!.text, 'Alex Chen');
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '陈',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump();
        expect(name.controller!.text, '陈');
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '陈子安',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
        expect(name.controller!.text, '陈子安');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
