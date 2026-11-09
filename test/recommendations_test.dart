import 'dart:convert';

import 'package:compass_flutter/src/demo_activities.dart';
import 'package:compass_flutter/src/recommendations.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final alderline = demoSchools.first;
  final cedarbrook = demoSchools.last;

  test(
    'preferences round-trip, stay immutable, and discard invalid saved data',
    () {
      final source = {'Robotics', 'Drawing'};
      final preferences = StudentPreferences(
        interests: source,
        meetupTime: MeetupTime.afterSchool,
      );
      source.clear();
      final loaded = StudentPreferences.fromStorage(
        preferences.toStorage(),
        alderline,
      );
      expect(loaded.interests, {'Robotics', 'Drawing'});
      expect(loaded.meetupTime, MeetupTime.afterSchool);
      expect(() => loaded.interests.add('Reading'), throwsUnsupportedError);
      for (final bad in [null, 42, '{broken', 'null', '[]', 'true']) {
        expect(
          StudentPreferences.fromStorage(bad, alderline).interests,
          isEmpty,
        );
      }
      final sanitized = StudentPreferences.fromStorage(
        jsonEncode({
          'interests': ['Robotics', 'Robotics', 'Theater', 42],
          'meetupTime': 'unknown',
        }),
        alderline,
      );
      expect(sanitized.interests, {'Robotics'});
      expect(sanitized.meetupTime, MeetupTime.any);
      expect(
        studentPreferencesKey(alderline),
        'compass.preview.alderline.preferences',
      );
      expect(
        studentPreferencesKey(cedarbrook),
        'compass.preview.cedarbrook.preferences',
      );
    },
  );

  test('shared interests rank matches, with stable alphabetical ties', () {
    final preferences = StudentPreferences(
      interests: ['Robotics', 'Design', 'Drawing'],
    );
    final results = recommendFor(alderline, preferences);
    expect(results.peers.map((match) => match.item.id), [
      'jordan-ellis',
      'amara-brooks',
    ]);
    expect(results.peers.first.sharedInterests, ['Design', 'Robotics']);
    expect(results.clubs.map((match) => match.item.id), [
      'robotics-lab',
      'sketchbook-circle',
    ]);
    expect(results.events.map((match) => match.item.id), [
      'robotics-open-lab',
      'sketch-and-read',
    ]);
    expect(
      recommendFor(alderline, preferences).peers.map((m) => m.item.id),
      results.peers.map((m) => m.item.id),
    );
  });

  test('meetup time filters activities without hiding matching peers', () {
    final results = recommendFor(
      alderline,
      StudentPreferences(
        interests: ['Robotics', 'Drawing'],
        meetupTime: MeetupTime.lunch,
      ),
    );
    expect(results.peers.map((match) => match.item.id), [
      'amara-brooks',
      'jordan-ellis',
    ]);
    expect(results.clubs.map((match) => match.item.id), ['sketchbook-circle']);
    expect(results.events.map((match) => match.item.id), ['sketch-and-read']);
    final noActivities = recommendFor(
      alderline,
      StudentPreferences(interests: ['Robotics'], meetupTime: MeetupTime.lunch),
    );
    expect(noActivities.peers, hasLength(1));
    expect(noActivities.clubs, isEmpty);
    expect(noActivities.events, isEmpty);
  });

  test('no interests or no overlap never fabricates a match', () {
    for (final preferences in [
      StudentPreferences(),
      StudentPreferences(interests: ['Unknown']),
    ]) {
      final results = recommendFor(alderline, preferences);
      expect(results.peers, isEmpty);
      expect(results.clubs, isEmpty);
      expect(results.events, isEmpty);
    }
  });

  test('the same preference only recommends from the active school', () {
    final preferences = StudentPreferences(interests: ['Photography']);
    final first = recommendFor(alderline, preferences);
    final second = recommendFor(cedarbrook, preferences);
    expect(first.peers.single.item.id, 'maya-chen');
    expect(second.peers.single.item.id, 'eli-torres');
    expect(first.clubs.single.item.id, 'campus-lens');
    expect(second.clubs.single.item.id, 'yearbook-lab');
    expect(first.events.single.item.id, 'campus-photo-walk');
    expect(second.events.single.item.id, 'golden-hour-walk');
  });

  test(
    'school samples have usable, distinct opportunities for every interest',
    () {
      for (final school in demoSchools) {
        expect(school.clubs, isNotEmpty);
        expect(school.events, isNotEmpty);
        expect(
          school.clubs.map((a) => a.id).toSet().length,
          school.clubs.length,
        );
        expect(
          school.events.map((a) => a.id).toSet().length,
          school.events.length,
        );
        for (final interest in availableInterests(school)) {
          final results = recommendFor(
            school,
            StudentPreferences(interests: [interest]),
          );
          expect(
            results.peers,
            isNotEmpty,
            reason: '${school.id}: $interest peers',
          );
          expect(
            results.clubs,
            isNotEmpty,
            reason: '${school.id}: $interest clubs',
          );
          expect(
            results.events,
            isNotEmpty,
            reason: '${school.id}: $interest events',
          );
        }
      }
    },
  );
}
