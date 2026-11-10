import 'package:compass_flutter/src/community_feed.dart';
import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/app_session.dart';

void main() {
  testWidgets(
    'composer restores a closed draft, posts its tags and saves comments',
    (tester) async {
      const account = LocalAccount(
        email: 'alex@alderline.example',
        name: 'Alex Chen',
        grade: 11,
        salt: '',
        passwordHash: '',
      );
      final c = CommunityController(
        school: demoSchools.first,
        account: account,
        write: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: localCompassTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openPostComposer(context, c),
                child: const Text('Compose'),
              ),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Compose'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Badminton after class',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Meet us at the gym at four.',
      );
      // Dismiss before the debounce fires: closing still flushes the final draft.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(c.composerDraft['title'], 'Badminton after class');
      await tapVisible(tester, find.text('Compose'));
      expect(find.text('Badminton after class'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<PostCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clubs').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Post').last);
      final post = c.posts.first;
      expect(post.authorId, 'me');
      expect(post.category, PostCategory.club);
      expect(post.subtag, 'Badminton');
      expect(c.composerDraft, isEmpty);
      await tester.pumpWidget(
        MaterialApp(
          theme: localCompassTheme(Brightness.light),
          home: PostDetail(community: c, postId: post.id),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'I will be there.');
      await tapVisible(tester, find.text('Comment'));
      expect(c.posts.first.replies.single.body, 'I will be there.');
      expect(tester.takeException(), isNull);
    },
  );
}
