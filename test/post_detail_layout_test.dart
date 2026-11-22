import 'dart:convert';

import 'package:compass_flutter/src/app_ui.dart';
import 'package:compass_flutter/src/campus_photos_page.dart';
import 'package:compass_flutter/src/community_feed.dart';
import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('Post detail aligns at width ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final photo = await rootBundle.load('assets/campus_photos/courtyard.jpg');
      final post = CommunityPost(
        id: 'photo',
        authorId: 'me',
        title: 'Around campus',
        body: 'A photo from this morning.',
        category: PostCategory.gallery,
        subtag: 'Campus',
        at: DateTime.now().subtract(const Duration(minutes: 10)),
        photos: [base64Encode(photo.buffer.asUint8List())],
        replies: [
          PostReply(
            id: 'reply',
            author: 'me',
            body: 'I like this photo.',
            at: DateTime.now(),
          ),
        ],
      );
      final community = CommunityController(
        school: demoSchools.first,
        account: const LocalAccount(
          email: 'alex@alderline.example',
          name: 'Alex Chen',
          grade: 11,
          salt: '',
          passwordHash: '',
        ),
        write: (_) async {},
      )..posts = [post];
      addTearDown(community.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: localCompassTheme(Brightness.dark),
          home: PostDetail(community: community, postId: post.id),
        ),
      );
      await tester.pumpAndSettle();

      final photoRect = tester.getRect(find.byType(GalleryPostPhotos));
      final field = tester.getRect(find.byType(TextField));
      final avatar = tester.getRect(find.byType(StudentAvatar));
      final time = tester.getRect(find.text(relativeTime(post.at)));
      final menu = tester.getRect(find.byTooltip('Post actions'));
      for (final label in ['Around campus', 'Comments', 'I like this photo.']) {
        expect(tester.getTopLeft(find.text(label)).dx, photoRect.left);
      }
      expect(tester.getRect(find.byType(BackButton)).left, photoRect.left);
      expect(avatar.left, photoRect.left);
      expect(time.center.dy, avatar.center.dy);
      expect(menu.center.dy, avatar.center.dy);
      expect(field.left, photoRect.left);
      expect(field.right, photoRect.right);
      expect(tester.getRect(find.byType(FilledButton)).right, photoRect.right);
      expect(tester.takeException(), isNull);
    });
  }
}
