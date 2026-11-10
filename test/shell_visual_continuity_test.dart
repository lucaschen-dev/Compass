import 'package:compass_flutter/main.dart' as app;
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/app_session.dart';

Finder compassText() => find
    .byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == 'Compass',
    )
    .last;

Color? background(Widget w) {
  if (w is Material) return w.color;
  if (w is ColoredBox) return w.color;
  if (w is DecoratedBox && w.decoration is BoxDecoration) {
    return (w.decoration as BoxDecoration).color;
  }
  return null;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        'brand reaches header without jumping or recoloring: ${brightness.name} $width',
        (tester) async {
          final original = SharedPreferencesAsyncPlatform.instance;
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.empty();
          addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final prefs = SharedPreferencesAsync();
          await seedSession(prefs, demoSchools.first);
          await prefs.setString('compass.preview.theme', brightness.name);
          await app.main();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1850));
          final before = tester.getRect(compassText());
          final styleBefore = tester
              .widget<RichText>(compassText())
              .text
              .style!;
          final endElement = compassText().evaluate().single;
          final opacityBefore =
              endElement.findAncestorWidgetOfExactType<Opacity>()?.opacity ?? 1;
          await tester.pump(const Duration(milliseconds: 100));
          final after = tester.getRect(compassText());
          final styleAfter = tester.widget<RichText>(compassText()).text.style!;
          expect(
            (before.center - after.center).distance,
            lessThan(.5),
            reason: 'The last moving frame must align exactly with the resting header.',
          );
          expect(
            styleBefore.color,
            styleAfter.color,
            reason: 'Brand color must not change when movement finishes.',
          );
          expect(styleBefore.fontFamily, styleAfter.fontFamily);
          expect(styleBefore.fontWeight, styleAfter.fontWeight);
          expect(styleBefore.fontSize, styleAfter.fontSize);
          expect(
            opacityBefore,
            1,
            reason: 'The brand must stay opaque at the top instead of fading into a replacement.',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets(
      'wide selected navigation covers both icon and label: ${brightness.name}',
      (tester) async {
        final original = SharedPreferencesAsyncPlatform.instance;
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = SharedPreferencesAsync();
        await seedSession(prefs, demoSchools.first);
        await prefs.setString('compass.preview.theme', brightness.name);
        await boot(tester);
        final label = tester.getRect(find.text('Home'));
        final theme = Theme.of(find.text('Home').evaluate().single);
        final selection = find.byWidgetPredicate(
          (w) => background(w) == theme.colorScheme.primaryContainer,
        );
        final fullRows = selection.evaluate().where((e) {
          final r = tester.getRect(find.byWidget(e.widget));
          return r.left < label.left &&
              r.right > label.right + 8 &&
              r.height >= 44 &&
              r.left < 24;
        });
        expect(
          fullRows,
          isNotEmpty,
          reason: 'The selected background must cover the label and icon across the sidebar row.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
