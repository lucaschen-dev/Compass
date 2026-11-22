import 'dart:convert';

import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/data/sync_codec.dart';
import 'package:compass_flutter/src/data/user_state.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';

const uid = 'student-1';

void main() {

  test('remote post omits replies, secrets, and inline photos', () {
    final post = CommunityPost(
      id: 'p1',
      authorId: 'me',
      title: 'Lab help',
      body: 'Where is room 12?',
      category: PostCategory.question,
      subtag: 'Classes',
      at: DateTime.utc(2026, 11, 15, 12),
      photos: const ['data:image/png;base64,aaaa', 'https://cdn.example/p.png'],
      replies: [
        PostReply(
          id: 'r1',
          author: 'me',
          body: 'Second floor',
          at: DateTime.utc(2026, 11, 15, 13),
        ),
      ],
    );
    final json = remotePostJson(post, uid);
    expect(json.containsKey('replies'), isFalse);
    expect(json.containsKey('passwordHash'), isFalse);
    expect(json['authorId'], uid);
    expect(json['photos'], ['https://cdn.example/p.png']);
    expect(containsForbiddenRemoteKeys(json), isFalse);
  });

  test('private state is one document and never carries a calendar', () {
    const state = UserSchoolState(
      interests: ['Robotics'],
      meetupTime: 'afterSchool',
      friends: ['jordan'],
      clubApplies: ['robotics-lab'],
      requirementProgress: {'english': 2},
      guideProgress: ['alderline-library-etiquette'],
      savedPosts: ['p1'],
      likedPosts: ['p1'],
      followedTags: ['question'],
    );
    final map = state.toMap();
    expect(map.keys, isNot(contains('calendarUrl')));
    expect(containsForbiddenRemoteKeys(map), isFalse);
    final restored = UserSchoolState.fromMap(Map<String, dynamic>.from(map));
    expect(restored.clubApplies, ['robotics-lab']);
    expect(restored.requirementProgress['english'], 2);
    expect(restored.meetupTime, 'afterSchool');
  });

  test('a comment or chat send writes only the new document', () {
    final at = DateTime.utc(2026, 11, 15, 12);
    final before = CommunityController(
      school: demoSchools.first,
      account: const LocalAccount(
        email: 'alex@alderline.example',
        name: 'Alex Chen',
        grade: 11,
        uid: uid,
      ),
      saved: jsonEncode({
        'profile': const CommunityProfile(name: 'Alex Chen', grade: 11).toJson(),
        'posts': [
          CommunityPost(
            id: 'p1',
            authorId: 'me',
            title: 'Lab help',
            body: 'Where is room 12?',
            category: PostCategory.question,
            subtag: 'Classes',
            at: at,
          ).toJson(),
        ],
        'threads': [
          ChatThread(
            id: 'direct-jordan',
            name: 'Jordan',
            members: const ['jordan', 'me'],
            messages: [
              ChatMessage(
                id: 'm1',
                authorId: 'jordan',
                text: 'Hey',
                at: at,
              ),
            ],
          ).toJson(),
        ],
        'saved': const <String>[],
        'liked': const <String>[],
        'tags': const <String>[],
        'clubApplies': const <String>[],
        'composerDraft': const <String, dynamic>{},
      }),
      write: (_) async {},
    );
    final withReply = jsonDecode(before.encode()) as Map<String, dynamic>;
    final posts = (withReply['posts'] as List).cast<Map<String, dynamic>>();
    posts[0]['replies'] = [
      PostReply(
        id: 'r1',
        author: 'me',
        body: 'Second floor',
        at: at.add(const Duration(minutes: 5)),
      ).toJson(),
    ];
    final replyDelta = diffEncoded(
      previousEncoded: before.encode(),
      nextEncoded: jsonEncode(withReply),
      uid: uid,
    );
    expect(replyDelta.upsertPosts, isEmpty);
    expect(replyDelta.upsertReplies, hasLength(1));
    expect(replyDelta.upsertReplies.single.reply.id, 'r1');
    expect(remoteReplyJson(replyDelta.upsertReplies.single.reply, uid)['authorId'], uid);

    final withMessage = jsonDecode(before.encode()) as Map<String, dynamic>;
    final threads = (withMessage['threads'] as List).cast<Map<String, dynamic>>();
    (threads[0]['messages'] as List).add(
      ChatMessage(
        id: 'm2',
        authorId: 'me',
        text: 'On my way',
        at: at.add(const Duration(minutes: 1)),
      ).toJson(),
    );
    final messageDelta = diffEncoded(
      previousEncoded: before.encode(),
      nextEncoded: jsonEncode(withMessage),
      uid: uid,
    );
    expect(messageDelta.upsertMessages, hasLength(1));
    expect(messageDelta.upsertMessages.single.message.id, 'm2');
    expect(messageDelta.upsertThreads, isEmpty);
    final remote = remoteMessageJson(messageDelta.upsertMessages.single.message, uid);
    expect(remote['senderId'], uid);
    expect(remote.containsKey('photo'), isFalse);
  });

  test('my reply syncs on another account’s post', () {
    final at = DateTime.utc(2026, 11, 15, 12);
    final otherReply = PostReply(
      id: 'original',
      author: 'other-uid',
      body: 'Room 12',
      at: at,
    );
    final ownReply = PostReply(
      id: 'own',
      author: 'me',
      body: 'Thank you!',
      at: at,
    );
    String encode(List<PostReply> replies) => jsonEncode({
      'posts': [
        CommunityPost(
          id: 'other-post',
          authorId: 'other-uid',
          title: 'Lab help',
          body: 'Where is room 12?',
          category: PostCategory.question,
          subtag: 'Classes',
          at: at,
          replies: replies,
        ).toJson(),
      ],
    });

    final before = encode([otherReply]);
    final after = encode([otherReply, ownReply]);
    final added = diffEncoded(
      previousEncoded: before,
      nextEncoded: after,
      uid: uid,
    );
    expect(added.upsertPosts, isEmpty);
    expect(added.upsertReplies.single.postId, 'other-post');
    expect(added.upsertReplies.single.reply.id, 'own');

    final removed = diffEncoded(
      previousEncoded: after,
      nextEncoded: before,
      uid: uid,
    );
    expect(removed.upsertPosts, isEmpty);
    expect(removed.deleteReplies.single.postId, 'other-post');
    expect(removed.deleteReplies.single.replyId, 'own');
  });

  test('legacy Firebase chat cache retains only own messages and drafts', () {
    final at = DateTime.utc(2026, 11, 15, 12);
    final thread = ChatThread(
      id: 'my-custom-thread',
      name: 'My group',
      members: const ['me', 'jordan'],
      draft: 'My local draft',
      messages: [
        ChatMessage(id: 'mine', authorId: 'me', text: 'My message', at: at),
        ChatMessage(id: 'foreign', authorId: 'other-uid', text: 'Other', at: at),
      ],
    );
    final foreignThread = ChatThread(
      id: 'another-group',
      name: 'Another group',
      members: const ['me', 'jordan'],
      messages: [
        ChatMessage(id: 'other', authorId: 'other-uid', text: 'Other', at: at),
      ],
    );
    final controller = CommunityController(
      school: demoSchools.first,
      account: const LocalAccount(
        email: 'alex@alderline.example',
        name: 'Alex Chen',
        grade: 11,
        uid: uid,
      ),
      saved: jsonEncode({
        'version': 1,
        'profile': const CommunityProfile(name: 'Alex Chen', grade: 11).toJson(),
        'posts': [],
        'threads': [thread.toJson(), foreignThread.toJson()],
      }),
      write: (_) async {},
    );
    addTearDown(controller.dispose);

    final restored = controller.threads.singleWhere((item) => item.id == thread.id);
    expect(restored.messages.map((message) => message.id), ['mine']);
    expect(restored.draft, 'My local draft');
    expect(controller.threads.any((item) => item.id == foreignThread.id), isFalse);
    expect(jsonDecode(controller.encode())['version'], 2);
  });

  test('delete-for-me stays local and sample authors are not uploaded', () {
    final at = DateTime.utc(2026, 11, 15, 12);
    String encode(List<ChatMessage> messages) => jsonEncode({
      'profile': const CommunityProfile(name: 'Alex Chen', grade: 11).toJson(),
      'posts': [
        CommunityPost(
          id: 'notice',
          authorId: 'staff:Principal',
          title: 'Assembly',
          body: 'Friday',
          category: PostCategory.event,
          subtag: 'Campus',
          at: at,
        ).toJson(),
      ],
      'threads': [
        ChatThread(
          id: 'direct-jordan',
          name: 'Jordan',
          members: const ['jordan', 'me'],
          messages: messages,
        ).toJson(),
      ],
    });
    final kept = ChatMessage(id: 'm1', authorId: 'jordan', text: 'Hey', at: at);
    final delta = diffEncoded(
      previousEncoded: encode([kept]),
      nextEncoded: encode(const []),
      uid: uid,
    );
    expect(delta.upsertPosts, isEmpty);
    expect(delta.upsertMessages, isEmpty);
    expect(delta.hiddenMessageIds, ['m1']);
  });
}
