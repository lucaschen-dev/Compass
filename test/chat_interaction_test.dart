import 'package:compass_flutter/src/community_models.dart';
import 'package:compass_flutter/src/demo_chat_page.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final school = demoSchools.first;
  late CommunityController community;

  void createCommunity() {
    community = CommunityController(
      school: school,
      account: const LocalAccount(
        email: 'new-student@alderline.example',
        name: 'New Student',
        grade: 9,
      ),
      write: (_) async {},
    );
  }

  tearDown(() => community.dispose());

  Future<void> showChat(WidgetTester tester, Set<String> friends) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(Brightness.light),
        home: Scaffold(
          body: DemoChatPage(
            community: community,
            school: school,
            friendIds: friends,
            onAddFriend: (id) async => friends.add(id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Add friend searches classmates and opens the saved contact', (
    tester,
  ) async {
    createCommunity();
    final friends = <String>{};
    final classmate = school.classmates.firstWhere(
      (person) => !community.threads.any(
        (thread) => !thread.group && thread.members.contains(person.id),
      ),
    );
    await showChat(tester, friends);
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), classmate.name);
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, classmate.name);
    await tester.tap(
      find.descendant(of: row, matching: find.text('Add friend')),
    );
    await tester.pumpAndSettle();
    expect(friends, {classmate.id});
    await tester.tap(find.descendant(of: row, matching: find.text('Message')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationPage), findsOneWidget);
    expect(
      community.threads.where(
        (thread) => !thread.group && thread.members.contains(classmate.id),
      ),
      hasLength(1),
    );
  });

  testWidgets('right swipe quotes a message and focuses the reply composer', (
    tester,
  ) async {
    createCommunity();
    final thread = community.threads.first;
    final original = thread.messages.last;
    await showChat(tester, thread.members.toSet());
    await tester.tap(find.text(thread.name));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.text(original.text),
      const Offset(90, 0),
      const Duration(milliseconds: 220),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cancel reply'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'See you at orientation.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    final sent = community.threads
        .firstWhere((t) => t.id == thread.id)
        .messages
        .last;
    expect(sent.text, 'See you at orientation.');
    expect(sent.replyTo, original.id);
    expect(find.byTooltip('Cancel reply'), findsNothing);
  });

  testWidgets('blocked sample contacts cannot start a replacement chat', (
    tester,
  ) async {
    createCommunity();
    final existing = community.threads.first;
    final contact = existing.members.firstWhere((id) => id != 'me');
    await community.updateThread(existing.copyWith(left: true));
    await showChat(tester, {contact});
    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(existing.name),
      ),
      findsNothing,
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(existing.name));
    await tester.pumpAndSettle();
    expect(
      find.text('Contact blocked. Unblock to write a message.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Send message'), findsNothing);
  });
}
