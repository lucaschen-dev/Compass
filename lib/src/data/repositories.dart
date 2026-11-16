import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../community_models.dart';
import '../demo_activities.dart';
import '../local_accounts.dart';
import '../recommendations.dart';
import '../school_demo.dart';

/// Repository contracts. [LocalSchoolCatalogRepository] and the other local
/// classes keep the demo usable offline and in tests. Firestore implementations
/// live in `firestore_repositories.dart` and are used when Firebase is ready.

abstract class SchoolCatalogRepository {
  Future<List<Map<String, Object?>>> listSchools();
  Future<Map<String, Object?>?> getSchool(String schoolId);
}

abstract class GuideRepository {
  Future<List<DemoGuideItem>> listRules(String schoolId);
  Future<Set<String>> readProgress(String schoolId, String userKey);
  Future<void> setRead(String schoolId, String userKey, String ruleId, bool read);
}

abstract class AcademicsRepository {
  Future<List<DemoCourse>> listCourses(String schoolId);
  Future<List<DemoCreditRequirement>> listRequirements(String schoolId);
  Future<Map<String, int>> progress(String schoolId, String userKey);
  Future<void> setProgress(
    String schoolId,
    String userKey,
    String requirementId,
    int completed,
  );
}

abstract class ActivityRepository {
  Future<List<DemoActivity>> listClubs(String schoolId);
  Future<List<DemoActivity>> listEvents(String schoolId);
  Future<Set<String>> clubApplies(String schoolId, String userKey);
  Future<void> setClubApply(
    String schoolId,
    String userKey,
    String clubId,
    bool applied,
  );
}

abstract class UserProfileRepository {
  /// Auth-ready public profile. Never persist password hashes remotely.
  Future<Map<String, Object?>?> publicProfile(String schoolId, String email);
}

abstract class PostRepository {
  Future<List<CommunityPost>> listPosts(String schoolId, String userKey);
  Future<void> savePosts(
    String schoolId,
    String userKey,
    List<CommunityPost> posts,
  );
}

abstract class ChatRepository {
  Future<List<ChatThread>> listThreads(String schoolId, String userKey);
  Future<void> saveThreads(
    String schoolId,
    String userKey,
    List<ChatThread> threads,
  );
}

abstract class PreferencesRepository {
  Future<StudentPreferences> load(DemoSchool school, String userKey);
  Future<void> save(
    DemoSchool school,
    String userKey,
    StudentPreferences preferences,
  );
}

abstract class FriendsRepository {
  Future<Set<String>> listFriends(String schoolId, String userKey);
  Future<void> addFriend(String schoolId, String userKey, String personId);
}

String _guideKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.guide.$userKey';
String _reqKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.req.$userKey';
String _applyKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.clubApplies.$userKey';
String _prefsKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.preferences.$userKey';
String _friendsKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.friends.$userKey';
String _postsKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.posts.$userKey';
String _threadsKey(String schoolId, String userKey) =>
    'compass.preview.$schoolId.threads.$userKey';

DemoSchool? _school(String id) =>
    demoSchools.where((school) => school.id == id).firstOrNull;

class LocalSchoolCatalogRepository implements SchoolCatalogRepository {
  @override
  Future<List<Map<String, Object?>>> listSchools() async => [
    for (final school in demoSchools)
      school.toCatalogJson(emailDomain: schoolEmailDomain(school)),
  ];

  @override
  Future<Map<String, Object?>?> getSchool(String schoolId) async {
    final school = _school(schoolId);
    if (school == null) return null;
    return school.toCatalogJson(emailDomain: schoolEmailDomain(school));
  }
}

class LocalGuideRepository implements GuideRepository {
  LocalGuideRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<List<DemoGuideItem>> listRules(String schoolId) async =>
      _school(schoolId)?.guide ?? const [];

  @override
  Future<Set<String>> readProgress(String schoolId, String userKey) async {
    final raw = await preferences.getString(_guideKey(schoolId, userKey));
    if (raw == null) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setRead(
    String schoolId,
    String userKey,
    String ruleId,
    bool read,
  ) async {
    final next = await readProgress(schoolId, userKey);
    if (read) {
      next.add(ruleId);
    } else {
      next.remove(ruleId);
    }
    await preferences.setString(
      _guideKey(schoolId, userKey),
      jsonEncode(next.toList()),
    );
  }
}

class LocalAcademicsRepository implements AcademicsRepository {
  LocalAcademicsRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<List<DemoCourse>> listCourses(String schoolId) async =>
      _school(schoolId)?.courses ?? const [];

  @override
  Future<List<DemoCreditRequirement>> listRequirements(String schoolId) async =>
      _school(schoolId)?.graduationRequirements ?? const [];

  @override
  Future<Map<String, int>> progress(String schoolId, String userKey) async {
    final raw = await preferences.getString(_reqKey(schoolId, userKey));
    if (raw == null) return {};
    try {
      return {
        for (final entry in (jsonDecode(raw) as Map).entries)
          entry.key as String: (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setProgress(
    String schoolId,
    String userKey,
    String requirementId,
    int completed,
  ) async {
    final next = await progress(schoolId, userKey);
    next[requirementId] = completed;
    await preferences.setString(_reqKey(schoolId, userKey), jsonEncode(next));
  }
}

class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<List<DemoActivity>> listClubs(String schoolId) async =>
      _school(schoolId)?.clubs ?? const [];

  @override
  Future<List<DemoActivity>> listEvents(String schoolId) async =>
      _school(schoolId)?.events ?? const [];

  @override
  Future<Set<String>> clubApplies(String schoolId, String userKey) async {
    final raw = await preferences.getString(_applyKey(schoolId, userKey));
    if (raw == null) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setClubApply(
    String schoolId,
    String userKey,
    String clubId,
    bool applied,
  ) async {
    final next = await clubApplies(schoolId, userKey);
    if (applied) {
      next.add(clubId);
    } else {
      next.remove(clubId);
    }
    await preferences.setString(
      _applyKey(schoolId, userKey),
      jsonEncode(next.toList()),
    );
  }
}

class LocalUserProfileRepository implements UserProfileRepository {
  LocalUserProfileRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<Map<String, Object?>?> publicProfile(
    String schoolId,
    String email,
  ) async {
    final school = _school(schoolId);
    if (school == null) return null;
    final accounts = LocalAccounts(
      preferences,
      school,
      await preferences.getString(accountStoreKey(school)),
    );
    final account = accounts.find(email);
    return account?.toPublicProfileJson(schoolId: schoolId);
  }
}

class LocalPostRepository implements PostRepository {
  LocalPostRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<List<CommunityPost>> listPosts(String schoolId, String userKey) async {
    final school = _school(schoolId);
    if (school == null) return const [];
    final raw = await preferences.getString(_postsKey(schoolId, userKey));
    if (raw == null) return samplePosts(school);
    try {
      return (jsonDecode(raw) as List)
          .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return samplePosts(school);
    }
  }

  @override
  Future<void> savePosts(
    String schoolId,
    String userKey,
    List<CommunityPost> posts,
  ) => preferences.setString(
    _postsKey(schoolId, userKey),
    jsonEncode(posts.map((post) => post.toJson()).toList()),
  );
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<List<ChatThread>> listThreads(String schoolId, String userKey) async {
    final school = _school(schoolId);
    if (school == null) return const [];
    final raw = await preferences.getString(_threadsKey(schoolId, userKey));
    if (raw == null) return sampleThreads(school);
    try {
      return (jsonDecode(raw) as List)
          .map((item) => ChatThread.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return sampleThreads(school);
    }
  }

  @override
  Future<void> saveThreads(
    String schoolId,
    String userKey,
    List<ChatThread> threads,
  ) => preferences.setString(
    _threadsKey(schoolId, userKey),
    jsonEncode(threads.map((thread) => thread.toJson()).toList()),
  );
}

class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<StudentPreferences> load(DemoSchool school, String userKey) async {
    final raw = await preferences.getString(_prefsKey(school.id, userKey));
    return StudentPreferences.fromStorage(
      raw ?? await preferences.getString(studentPreferencesKey(school)),
      school,
    );
  }

  @override
  Future<void> save(
    DemoSchool school,
    String userKey,
    StudentPreferences value,
  ) => preferences.setString(_prefsKey(school.id, userKey), value.toStorage());
}

class LocalFriendsRepository implements FriendsRepository {
  LocalFriendsRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  @override
  Future<Set<String>> listFriends(String schoolId, String userKey) async {
    final raw = await preferences.getString(_friendsKey(schoolId, userKey));
    if (raw == null) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> addFriend(
    String schoolId,
    String userKey,
    String personId,
  ) async {
    final next = await listFriends(schoolId, userKey)..add(personId);
    await preferences.setString(
      _friendsKey(schoolId, userKey),
      jsonEncode(next.toList()),
    );
  }
}
