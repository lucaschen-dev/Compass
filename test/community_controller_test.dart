import 'dart:convert';

import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';

const account = LocalAccount(
  email: 'alex@alderline.example',
  name: 'Alex Chen',
  grade: 11,
  salt: '',
  passwordHash: '',
);
void main() {
  test(
    'community state round-trips, with separate school and account keys',
    () async {
      String? saved;
      final c = CommunityController(
        school: demoSchools.first,
        account: account,
        write: (v) async => saved = v,
      );
      await c.change(() {
        c.followedTags = {'club/Badminton'};
        c.profile = const CommunityProfile(
          name: 'Alex Chen',
          grade: 12,
          bio: 'Violin and badminton',
        );
      });
      await c.toggleSaved(c.posts.first.id);
      await c.send(
        c.threads.first.id,
        text: 'See you at the gym!',
        replyTo: c.threads.first.messages.first.id,
      );
      final restored = CommunityController(
        school: demoSchools.first,
        account: account,
        write: (_) async {},
        saved: saved,
      );
      expect(restored.profile.grade, 12);
      expect(restored.savedPosts, contains(c.posts.first.id));
      expect(restored.followedTags, contains('club/Badminton'));
      expect(restored.threads.first.messages.last.replyTo, isNotNull);
      expect(
        communityStoreKey(demoSchools.first, account),
        isNot(communityStoreKey(demoSchools.last, account)),
      );
      const other = LocalAccount(
        email: 'other@alderline.example',
        name: 'Other Person',
        grade: 10,
        salt: '',
        passwordHash: '',
      );
      expect(
        communityStoreKey(demoSchools.first, account),
        isNot(communityStoreKey(demoSchools.first, other)),
      );
      final different = CommunityController(
        school: demoSchools.last,
        account: other,
        write: (_) async {},
      );
      expect(different.savedPosts, isEmpty);
      expect(
        different.posts.every((p) => p.id.startsWith('cedarbrook')),
        isTrue,
      );
    },
  );
  test('queued draft changes preserve a concurrently sent message', () async {
    final c = CommunityController(
      school: demoSchools.first,
      account: account,
      write: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      },
    );
    final id = c.threads.first.id;
    await Future.wait([
      c.send(id, text: 'Keep this message'),
      c.patchThread(id, draft: 'Next message'),
      c.toggleSaved(c.posts.first.id),
    ]);
    expect(c.threads.first.messages.last.text, 'Keep this message');
    expect(c.threads.first.draft, 'Next message');
    expect(c.savedPosts, hasLength(1));
  });
  test(
    'failed persistence rolls back profile, messages and saved posts',
    () async {
      final c = CommunityController(
        school: demoSchools.first,
        account: account,
        write: (_) async => throw StateError('disk full'),
      );
      final before = c.encode();
      await expectLater(
        c.change(
          () => c.profile = const CommunityProfile(name: 'Changed', grade: 9),
        ),
        throwsStateError,
      );
      expect(c.encode(), before);
      await expectLater(
        c.send(c.threads.first.id, text: 'Do not keep'),
        throwsStateError,
      );
      expect(c.encode(), before);
    },
  );
  test(
    'retraction enforces ownership and time and removes reply/media data',
    () async {
      final c = CommunityController(
        school: demoSchools.first,
        account: account,
        write: (_) async {},
      );
      final thread = c.threads.first;
      final now = DateTime.now();
      await c.send(
        thread.id,
        text: 'New message',
        replyTo: thread.messages.first.id,
        photo: 'cGhvdG8=',
      );
      final id = c.threads.first.messages.last.id;
      await c.retract(thread.id, id, now.add(const Duration(seconds: 30)));
      final unsent = c.threads.first.messages.last;
      expect(unsent.unsent, isTrue);
      expect(unsent.text, isEmpty);
      expect(unsent.photo, isNull);
      expect(unsent.replyTo, isNull);
      final incoming = c.threads.first.messages.firstWhere(
        (m) => m.authorId != 'me',
      );
      await expectLater(
        c.retract(thread.id, incoming.id, now),
        throwsStateError,
      );
      await c.send(thread.id, text: 'Too old later');
      await expectLater(
        c.retract(
          thread.id,
          c.threads.first.messages.last.id,
          now.add(const Duration(minutes: 3)),
        ),
        throwsStateError,
      );
      expect(c.threads.first.messages.last.unsent, isFalse);
    },
  );
  test('messages reject unavailable conversations, foreign replies and oversized content', () async {
    final c = CommunityController(
      school: demoSchools.first,
      account: account,
      write: (_) async {},
    );
    final thread = c.threads.first;
    await expectLater(c.send('another-school', text: 'No'), throwsStateError);
    await expectLater(
      c.send(thread.id, text: 'No', replyTo: 'foreign-message'),
      throwsArgumentError,
    );
    await expectLater(c.send(thread.id, text: 'x' * 2001), throwsArgumentError);
    await c.updateThread(thread.copyWith(left: true));
    await expectLater(c.send(thread.id, text: 'No access'), throwsStateError);
  });
  test('malformed stored community data falls back to school samples', () {
    final c = CommunityController(
      school: demoSchools.first,
      account: account,
      write: (_) async {},
      saved: jsonEncode({
        'profile': {'name': 1},
      }),
    );
    expect(c.posts, isNotEmpty);
    expect(c.profile.name, account.name);
  });
}
