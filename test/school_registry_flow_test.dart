import 'package:compass_flutter/main.dart';
import 'package:compass_flutter/src/data/school_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'school discovery shows approved schools and hides archived schools',
    (tester) async {
      await tester.pumpWidget(
        CompassApp(
          preferences: SharedPreferencesAsync(),
          saved: const {},
          schoolRegistry: const _TestRegistry([
            RegisteredSchool(
              id: 'harbor',
              name: 'Harbor High School',
              emailDomain: 'harbor.edu',
            ),
          ]),
        ),
      );
      await tester.tap(find.text('Find Your School'));
      await tester.pumpAndSettle();
      expect(find.text('Harbor High School'), findsOneWidget);
      expect(find.text('Alderline'), findsNothing);
      expect(find.text('Cedarbrook'), findsNothing);
    },
  );

  testWidgets('the empty approved catalog never falls back to demo schools', (
    tester,
  ) async {
    await tester.pumpWidget(
      CompassApp(
        preferences: SharedPreferencesAsync(),
        saved: const {},
        schoolRegistry: const _TestRegistry([]),
      ),
    );
    await tester.tap(find.text('Find Your School'));
    await tester.pumpAndSettle();
    expect(find.text('No approved schools yet.'), findsOneWidget);
    expect(find.text('Alderline'), findsNothing);
    expect(find.text('Cedarbrook'), findsNothing);
  });
}

class _TestRegistry implements SchoolRegistry {
  const _TestRegistry(this.schools);

  final List<RegisteredSchool> schools;

  @override
  Future<List<RegisteredSchool>> listApprovedSchools() async => schools;

  @override
  Future<RegisteredSchool?> getApprovedSchool(String id) async =>
      schools.where((school) => school.id == id).firstOrNull;
}
