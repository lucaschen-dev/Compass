import 'package:compass_flutter/src/data/repositories.dart';
import 'package:compass_flutter/src/demo_activities.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('catalog and activity JSON round-trips for Firestore prep', () async {
    final catalog = LocalSchoolCatalogRepository();
    final schools = await catalog.listSchools();
    expect(schools, hasLength(2));
    expect(schools.first['emailDomain'], 'alderline.example');

    final club = alderlineClubs.first;
    final restored = DemoActivity.fromJson(
      Map<String, dynamic>.from(club.toJson()),
    );
    expect(restored.leaderIds, club.leaderIds);
    expect(restored.memberIds, club.memberIds);

    final school = demoSchools.first;
    expect(
      DemoGuideItem.fromJson(
        Map<String, dynamic>.from(school.guide.first.toJson()),
      ).id,
      school.guide.first.id,
    );
    expect(
      DemoCourse.fromJson(
        Map<String, dynamic>.from(school.courses.first.toJson()),
      ).id,
      school.courses.first.id,
    );
    expect(school.student.toJson().containsKey('passwordHash'), isFalse);
  });

  test('local activity repository stores club applies', () async {
    final prefs = SharedPreferencesAsync();
    final repo = LocalActivityRepository(prefs);
    await repo.setClubApply('alderline', 'alex@alderline.example', 'robotics-lab', true);
    expect(
      await repo.clubApplies('alderline', 'alex@alderline.example'),
      contains('robotics-lab'),
    );
    expect(
      await repo.listClubs('alderline'),
      isNotEmpty,
    );
  });

  test('public account profile omits secrets', () {
    const account = LocalAccount(
      email: 'alex@alderline.example',
      name: 'Alex',
      grade: 11,
      salt: 'secret-salt',
      passwordHash: 'secret-hash',
    );
    final json = account.toPublicProfileJson(schoolId: 'alderline');
    expect(json.containsKey('salt'), isFalse);
    expect(json.containsKey('passwordHash'), isFalse);
    expect(json['schoolId'], 'alderline');
  });
}
