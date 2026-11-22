import 'dart:convert';

import 'package:compass_flutter/src/campus_photo_media.dart';
import 'package:compass_flutter/src/campus_photos_page.dart';
import 'package:compass_flutter/src/community_feed.dart';
import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/data/sync_codec.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/recommendations.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fixtures/app_session.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGOQTV0MAAHIASYg/ATKAAAAAElFTkSuQmCC';
const _account = LocalAccount(
  email: 'alex@alderline.example',
  name: 'Alex Chen',
  grade: 11,
  uid: 'me-uid',
);

CommunityPost _gallery({
  required bool shared,
  required List<String> photos,
  String id = 'campus-morning',
  DateTime? date,
}) => CommunityPost(
  id: id,
  authorId: 'me',
  title: 'Morning news',
  body: 'On the way to the commons',
  category: PostCategory.gallery,
  subtag: 'Campus',
  at: date ?? DateTime(2026, 11, 22, 9),
  sharedGalleryMedia: shared,
  photos: photos,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a landscape JPEG becomes a bounded PNG that meets the share policy',
    () async {
      final source = await rootBundle.load(
        'assets/campus_photos/courtyard.jpg',
      );
      final png = await encodeGalleryPhoto(
        source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
      );
      expect(isSharedGalleryPhoto(png), isTrue);
      expect(png.length, lessThanOrEqualTo(galleryPhotoEncodedLimit));
    },
  );
  test('only bounded published gallery images sync, without filling the local cache', () {
    final max = _pixel.substring(0, 32) + 'A' * (galleryPhotoEncodedLimit - 32);
    final oversized = '${max}AAAA';
    final captionLength = '😀' * 5000;
    final shared = _gallery(
      shared: true,
      photos: [for (var i = 0; i < 6; i++) max, oversized, 'https://invalid/'],
    );
    final remote = remotePostJson(shared, 'me-uid');
    expect(remote['photos'], List.filled(galleryPhotoLimit, max));
    expect(
      utf8.encode(jsonEncode({...remote, 'body': captionLength})).length,
      lessThan(1024 * 1024),
    );
    final incoming = localPostFromRemote(
      Map<String, dynamic>.from(remote),
      'other-uid',
    );
    expect(incoming.photos, shared.photos.take(galleryPhotoLimit));
    expect(incoming.sharedGalleryMedia, isTrue);

    final legacy = _gallery(shared: false, photos: [max], id: 'legacy');
    expect(
      remotePostJson(legacy, 'me-uid')['photos'],
      isEmpty,
      reason: 'Legacy attachments must stay on this device.',
    );
    final cached = jsonDecode(
      compactSharedGalleryCache(
        jsonEncode({
          'posts': [shared.toJson(), legacy.toJson()],
          'composerDraft': {
            'photos': [_pixel],
          },
        }),
      ),
    ) as Map<String, dynamic>;
    final cachedPost = CommunityPost.fromJson(
      cached['posts'][0] as Map<String, dynamic>,
    );
    expect(cachedPost.photos, isEmpty);
    expect(cachedPost.sharedGalleryMedia, isTrue);
    expect(
      remotePostJson(cachedPost, 'me-uid'),
      isNot(contains('photos')),
      reason:
          'A metadata edit to the offline copy must keep the published photos.',
    );
    expect(cached['posts'][1]['photos'], [max]);
    expect(cached['composerDraft']['photos'], [_pixel]);
  });

  test(
    'the automatic sync does not write an acknowledged album a second time',
    () {
      final post = _gallery(shared: true, photos: [_pixel]);
      final snapshot = jsonEncode({
        'posts': [post.toJson()],
      });
      final acknowledged = diffEncoded(
        previousEncoded: null,
        nextEncoded: snapshot,
        uid: 'me-uid',
        acknowledgedPosts: {post.id: post},
      );
      expect(acknowledged.upsertPosts, isEmpty);
      final changed = diffEncoded(
        previousEncoded: null,
        nextEncoded: jsonEncode({
          'posts': [post.copyWith(anonymous: true).toJson()],
        }),
        uid: 'me-uid',
        acknowledgedPosts: {post.id: post},
      );
      expect(changed.upsertPosts.single.anonymous, isTrue);
    },
  );

  testWidgets(
    'campus photos group days and retry a failed school upload without replacing the text draft',
    (tester) async {
      final now = DateTime.now();
      final c =
          CommunityController(
              school: demoSchools.first,
              account: _account,
              write: (_) async {},
            )
            ..posts = [
              _gallery(shared: true, photos: [_pixel], id: 'today', date: now),
              _gallery(
                shared: true,
                photos: [_pixel],
                id: 'yesterday',
                date: DateTime(now.year, now.month, now.day - 1, 9),
              ),
            ]
            ..composerDraft = {
              'title': 'Ordinary text draft',
              'photoDraft': {
                'photos': [_pixel],
              },
            };
      final published = <CommunityPost>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: localCompassTheme(Brightness.light),
          home: Scaffold(
            body: CommunityFeed(
              community: c,
              preferences: StudentPreferences(),
              onSavePreferences: (_) async {},
              friendIds: const {},
              onAddFriend: (_) async {},
              publishGalleryPost: (post) async {
                published.add(post);
                if (published.length == 1) throw StateError('Offline');
              },
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Campus photos'));
      expect(find.byType(CampusPhotosPage), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Yesterday'), 350);
      expect(find.text('Yesterday'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Post photos'), -400);
      await tapVisible(tester, find.text('Post photos'));
      expect(find.text('Add photos (1/4)'), findsOneWidget);
      await tapVisible(tester, find.text('Post'));
      expect(c.posts.length, 2);
      expect(c.composerDraft['photoDraft']['postId'], published.single.id);
      await tapVisible(tester, find.text('Post'));
      expect(published.length, 2);
      expect(published.map((p) => p.id).toSet(), hasLength(1));
      expect(c.posts.first.id, published.last.id);
      expect(c.posts.first.sharedGalleryMedia, isTrue);
      expect(c.composerDraft, {'title': 'Ordinary text draft'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
