import 'dart:convert';

import 'package:compass_flutter/src/campus_photos_page.dart';
import 'package:compass_flutter/src/community_feed.dart';
import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/data/school_chat_repository.dart';
import 'package:compass_flutter/src/data/school_moderation.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_chat_page.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:compass_flutter/src/school_moderation_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (size, brightness) in [
    (const Size(390, 844), Brightness.dark),
    (const Size(1280, 800), Brightness.light),
  ]) {
    testWidgets('reports, blocks and unblocks on ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final moderation = _ModerationFixture();
      final community = _community(moderation);
      final post = CommunityPost(
        id: 'community-post',
        authorId: 'student123',
        authorName: 'Jordan Lee',
        title: 'A school event',
        body: 'We meet after school.',
        category: PostCategory.event,
        subtag: 'Campus',
        at: DateTime.now(),
        replies: [
          PostReply(
            id: 'comment-1',
            author: 'student123',
            authorName: 'Jordan Lee',
            body: 'Please bring paper.',
            at: DateTime.now(),
          ),
        ],
      );
      community.posts = [post];
      addTearDown(community.dispose);
      addTearDown(moderation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: localCompassTheme(brightness),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            PostDetail(community: community, postId: post.id),
                      ),
                    ),
                    child: const Text('Open post'),
                  ),
                  TextButton(
                    onPressed: () => openBlockedPeople(context, moderation),
                    child: const Text('Open block list'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open post'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'I WILL KILL YOU');
      await tester.tap(find.text('Comment'));
      await tester.pumpAndSettle();
      expect(find.text(communityTextWarning), findsOneWidget);
      expect(community.posts.single.replies.length, 1);

      await tester.tap(find.byTooltip('Comment actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report comment'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<ReportReason>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReportReason.harassment.label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      final (target, reason) = moderation.reports.single;
      expect(target.kind, ReportKind.comment);
      expect(target.parentId, post.id);
      expect(target.contentId, post.replies.single.id);
      expect(reason, ReportReason.harassment);
      expect(find.text('Report sent to Compass moderators.'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Post actions'));
      await tester.tap(find.byTooltip('Post actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('This post is unavailable.'), findsOneWidget);
      expect(community.visiblePosts, isEmpty);
      expect(community.posts.single.id, post.id);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open block list'));
      await tester.pumpAndSettle();
      expect(find.text('Jordan Lee'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unblock').last);
      await tester.pumpAndSettle();
      expect(moderation.isBlocked('student123'), isFalse);
      expect(community.visiblePosts.single.id, post.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('incoming messages can be reported and blocked', (tester) async {
    final moderation = _ModerationFixture();
    addTearDown(moderation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open conversation'),
              onPressed: () => openSchoolConversation(
                context,
                chat: _ChatFixture(),
                peerId: 'student123',
                peerName: 'Jordan Lee',
                moderation: moderation,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open conversation'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report message'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ReportReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportReason.unsafe.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    final (target, reason) = moderation.reports.single;
    expect(target.kind, ReportKind.message);
    expect(target.parentId, 'me:student123');
    expect(target.contentId, 'student123:abc');
    expect(reason, ReportReason.unsafe);

    await tester.tap(find.byTooltip('Conversation actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock this person to send messages.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Incoming message'), findsOneWidget);
  });

  testWidgets('campus photos expose the post report action', (tester) async {
    final moderation = _ModerationFixture();
    final community = _community(moderation);
    final photo = await rootBundle.load('assets/campus_photos/courtyard.jpg');
    community.posts = [
      CommunityPost(
        id: 'campus-album',
        title: 'Campus photos',
        body: 'A photo from this morning.',
        authorId: 'student123',
        authorName: 'Jordan Lee',
        category: PostCategory.gallery,
        subtag: 'Campus',
        at: DateTime.now(),
        photos: [base64Encode(photo.buffer.asUint8List())],
      ),
    ];
    addTearDown(community.dispose);
    addTearDown(moderation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(Brightness.light),
        home: CampusPhotosPage(community: community, onCompose: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Post actions'));
    await tester.tap(find.byTooltip('Post actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ReportReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportReason.inappropriate.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    final (target, reason) = moderation.reports.single;
    expect(target.kind, ReportKind.post);
    expect(target.contentId, 'campus-album');
    expect(reason, ReportReason.inappropriate);
    await moderation.block('student123', 'Jordan Lee');
    await tester.pumpAndSettle();
    expect(find.text('Campus photos'), findsOneWidget);
  });
}

CommunityController _community(_ModerationFixture moderation) =>
    CommunityController(
      school: demoSchools.first,
      account: const LocalAccount(
        email: 'alex@alderline.example',
        name: 'Alex Chen',
        grade: 11,
        salt: '',
        passwordHash: '',
      ),
      write: (_) async {},
    )..moderation = moderation;

class _ModerationFixture extends SchoolModeration {
  final reports = <(SchoolReportTarget, ReportReason)>[];
  final _blocked = <String, BlockedSchoolMember>{};

  @override
  List<BlockedSchoolMember> get blockedPeople => _blocked.values.toList();

  @override
  bool get hasLoadError => false;

  @override
  bool get hasLoadedBlocks => true;

  @override
  bool isBlocked(String uid) => _blocked.containsKey(uid);

  @override
  void refreshBlocks() {}

  @override
  Future<void> block(String peerId, String displayName) async {
    _blocked[peerId] = BlockedSchoolMember(peerId, displayName);
    notifyListeners();
  }

  @override
  Future<void> unblock(String peerId) async {
    _blocked.remove(peerId);
    notifyListeners();
  }

  @override
  Future<void> report(SchoolReportTarget target, ReportReason reason) async {
    reports.add((target, reason));
  }
}

class _ChatFixture implements SchoolChatRepository {
  @override
  String get uid => 'me';

  @override
  String createMessageId() => 'outgoing-message';

  @override
  Stream<List<SchoolChatMessage>> watchMessages(String friendUid) =>
      Stream.value([
        SchoolChatMessage(
          id: '$friendUid:abc',
          senderId: friendUid,
          text: 'Incoming message',
          createdAt: DateTime(2026, 11, 26),
        ),
      ]);

  @override
  Future<List<SchoolChatMessage>> loadOlderMessages(
    String friendUid,
    SchoolChatMessage before,
  ) async => [];

  @override
  Future<void> sendMessage(
    String friendUid, {
    required String messageId,
    required String text,
  }) async {}
}
