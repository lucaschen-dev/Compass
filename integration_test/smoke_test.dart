import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:media_kit/media_kit.dart';
import 'package:compass_flutter/src/store.dart';
import 'package:compass_flutter/src/planner.dart';
import 'package:compass_flutter/src/ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Mac native launch, keychain, navigation and composer', (
    tester,
  ) async {
    tz.initializeTimeZones();
    MediaKit.ensureInitialized();
    const vault = FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
    final key = 'migration-smoke-${DateTime.now().microsecondsSinceEpoch}';
    await vault.write(key: key, value: 'disposable-test');
    expect(await vault.read(key: key), 'disposable-test');
    await vault.delete(key: key);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CampusStore(prefs)..restoring = false;
    final planner = PlannerStore(prefs);
    await tester.pumpWidget(CompassApp(store: store, planner: planner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore the demo'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO'), findsOneWidget);
    expect(store.snapshot, isNotNull);
    await tester.tap(find.widgetWithText(TextButton, 'Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Maya Taylor'), findsOneWidget);
    await tester.tap(find.text('Maya Taylor'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send message'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Native Mac demo message');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Native Mac demo message'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Native Mac migration check',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Saved locally during automated verification.',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Home'));
    await tester.pumpAndSettle();
    expect(store.posts.first['title'], 'Native Mac migration check');
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Buckley assignments'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    planner.dispose();
  });
}
