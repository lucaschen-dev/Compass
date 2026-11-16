/// One private document per user and school.
///
/// Stored at `users/{uid}/schools/{schoolId}` because a Firestore document path
/// needs an even number of segments. Guide text, course catalogs, classmate
/// lists, and calendar imports are not part of this blob.
class UserSchoolState {
  const UserSchoolState({
    this.interests = const [],
    this.meetupTime = 'any',
    this.friends = const [],
    this.clubApplies = const [],
    this.requirementProgress = const {},
    this.guideProgress = const [],
    this.savedPosts = const [],
    this.likedPosts = const [],
    this.followedTags = const [],
  });

  final List<String> interests;
  final String meetupTime;
  final List<String> friends;
  final List<String> clubApplies;
  final Map<String, int> requirementProgress;
  final List<String> guideProgress;
  final List<String> savedPosts;
  final List<String> likedPosts;
  final List<String> followedTags;

  Map<String, Object?> toMap() => {
    'prefs': {'interests': interests, 'meetupTime': meetupTime},
    'friends': friends,
    'clubApplies': clubApplies,
    'requirementProgress': requirementProgress,
    'guideProgress': guideProgress,
    'savedPosts': savedPosts,
    'likedPosts': likedPosts,
    'followedTags': followedTags,
  };

  factory UserSchoolState.fromMap(Map<String, dynamic> data) {
    final prefs = data['prefs'];
    final prefMap = prefs is Map ? Map<String, dynamic>.from(prefs) : const {};
    return UserSchoolState(
      interests: _strings(prefMap['interests']),
      meetupTime: prefMap['meetupTime'] as String? ?? 'any',
      friends: _strings(data['friends']),
      clubApplies: _strings(data['clubApplies']),
      requirementProgress: _counts(data['requirementProgress']),
      guideProgress: _strings(data['guideProgress']),
      savedPosts: _strings(data['savedPosts']),
      likedPosts: _strings(data['likedPosts']),
      followedTags: _strings(data['followedTags']),
    );
  }
}

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

Map<String, int> _counts(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

const forbiddenRemoteKeys = {
  'password',
  'passwordHash',
  'salt',
  'calendar',
  'calendarUrl',
  'calendarImport',
  'webcal',
  'icsUrl',
};

bool containsForbiddenRemoteKeys(Map<String, Object?> data) =>
    data.keys.any(forbiddenRemoteKeys.contains);
