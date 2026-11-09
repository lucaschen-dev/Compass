import 'dart:convert';

import 'demo_activities.dart';
import 'school_demo.dart';

String studentPreferencesKey(DemoSchool school) =>
    'compass.preview.${school.id}.preferences';

List<String> availableInterests(DemoSchool school) => ({
  for (final person in school.classmates) ...person.interests,
  for (final activity in [...school.clubs, ...school.events])
    ...activity.interests,
}.toList()..sort());

class StudentPreferences {
  StudentPreferences({
    Iterable<String> interests = const [],
    this.meetupTime = MeetupTime.any,
  }) : interests = Set.unmodifiable(interests);

  final Set<String> interests;
  final MeetupTime meetupTime;

  List<String> get sortedInterests => interests.toList()..sort();

  String toStorage() => jsonEncode({
    'version': 1,
    'interests': sortedInterests,
    'meetupTime': meetupTime.name,
  });

  factory StudentPreferences.fromStorage(Object? value, DemoSchool school) {
    if (value is! String) return StudentPreferences();
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) return StudentPreferences();
      final allowed = availableInterests(school).toSet();
      final rawInterests = data['interests'];
      return StudentPreferences(
        interests: rawInterests is List
            ? rawInterests.whereType<String>().where(allowed.contains)
            : const [],
        meetupTime: MeetupTime.values.firstWhere(
          (time) => time.name == data['meetupTime'],
          orElse: () => MeetupTime.any,
        ),
      );
    } on FormatException {
      return StudentPreferences();
    }
  }
}

class InterestMatch<T> {
  const InterestMatch(this.item, this.sharedInterests);

  final T item;
  final List<String> sharedInterests;
}

class SchoolRecommendations {
  const SchoolRecommendations({
    required this.peers,
    required this.clubs,
    required this.events,
  });

  final List<InterestMatch<DemoPerson>> peers;
  final List<InterestMatch<DemoActivity>> clubs;
  final List<InterestMatch<DemoActivity>> events;
}

SchoolRecommendations recommendFor(
  DemoSchool school,
  StudentPreferences preferences,
) {
  bool fitsTime(DemoActivity item) =>
      preferences.meetupTime == MeetupTime.any ||
      item.meetupTime == MeetupTime.any ||
      item.meetupTime == preferences.meetupTime;

  // Only this school's data is scored. More shared interests rank first;
  // alphabetical ties keep results stable across reloads and platforms.
  return SchoolRecommendations(
    peers: _rank(
      school.classmates,
      preferences,
      (p) => p.interests,
      (p) => p.name,
    ),
    clubs: _rank(
      school.clubs.where(fitsTime),
      preferences,
      (a) => a.interests,
      (a) => a.title,
    ),
    events: _rank(
      school.events.where(fitsTime),
      preferences,
      (a) => a.interests,
      (a) => a.title,
    ),
  );
}

List<InterestMatch<T>> _rank<T>(
  Iterable<T> items,
  StudentPreferences preferences,
  List<String> Function(T) interests,
  String Function(T) title,
) {
  final matches = <InterestMatch<T>>[];
  for (final item in items) {
    final shared = interests(
      item,
    ).toSet().intersection(preferences.interests).toList()..sort();
    if (shared.isNotEmpty) {
      matches.add(InterestMatch(item, List.unmodifiable(shared)));
    }
  }
  matches.sort((a, b) {
    final byOverlap = b.sharedInterests.length.compareTo(
      a.sharedInterests.length,
    );
    return byOverlap != 0
        ? byOverlap
        : title(a.item).toLowerCase().compareTo(title(b.item).toLowerCase());
  });
  return List.unmodifiable(matches.take(3));
}
