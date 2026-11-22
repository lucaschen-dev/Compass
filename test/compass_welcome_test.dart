import 'package:compass_flutter/src/compass_backdrop.dart';
import 'package:compass_flutter/src/compass_welcome.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('welcome actions remain reachable on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(Brightness.dark),
        home: CompassWelcome(
          onFindSchool: () => actions.add('find'),
          onRegisterSchool: () => actions.add('register'),
          onSignIn: () => actions.add('sign in'),
        ),
      ),
    );

    final findSchool = find.widgetWithText(FilledButton, 'Find Your School');
    final register = find.widgetWithText(TextButton, 'Register');
    final signIn = find.widgetWithText(TextButton, 'Sign in');
    expect(tester.getSize(find.byType(CompassBackdrop)), const Size(320, 200));
    expect(
      tester.getBottomLeft(findSchool).dy,
      lessThan(tester.getTopLeft(register).dy),
    );
    expect(
      tester.getTopLeft(register).dy,
      lessThan(tester.getTopLeft(signIn).dy),
    );

    await tester.tap(findSchool);
    await tester.ensureVisible(register);
    await tester.pumpAndSettle();
    await tester.tap(register);
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    expect(actions, ['find', 'register', 'sign in']);
    expect(tester.takeException(), isNull);
  });
}
