import 'dart:async';

import 'package:compass_flutter/src/data/friend_repository.dart';
import 'package:compass_flutter/src/data/school_chat_repository.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_chat_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const accepted = SchoolFriendRequest(
    senderId: 'me',
    senderName: 'My Name',
    recipientId: 'jordan',
    recipientName: 'Jordan Lee',
    status: FriendRequestStatus.accepted,
  );
  const pending = SchoolFriendRequest(
    senderId: 'morgan',
    senderName: 'Morgan Chen',
    recipientId: 'me',
    status: FriendRequestStatus.pending,
  );

  Future<void> showChat(
    WidgetTester tester,
    _FriendsFixture friends,
    _ChatFixture chat, {
    Brightness brightness = Brightness.light,
    Size size = const Size(320, 700),
    VoidCallback? onAddFriend,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(chat.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(brightness),
        home: Scaffold(
          body: SchoolChatPage(
            friends: friends,
            chat: chat,
            onAddFriend: onAddFriend ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openConversation(WidgetTester tester) async {
    await tester.tap(find.text('Jordan Lee'));
    await tester.pumpAndSettle();
  }

  Finder getComposer() => find.byType(TextField);

  testWidgets('shows only accepted accounts and scopes a chat to that friend', (
    tester,
  ) async {
    var addFriendOpened = false;
    final chat = _ChatFixture();
    await showChat(
      tester,
      const _FriendsFixture([pending, accepted]),
      chat,
      onAddFriend: () => addFriendOpened = true,
    );
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('Morgan Chen'), findsNothing);
    await tester.tap(find.text('Add friend'));
    expect(addFriendOpened, isTrue);
    await openConversation(tester);
    expect(chat.opened, ['jordan']);
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('has a clear empty state when all requests are pending', (
    tester,
  ) async {
    await showChat(
      tester,
      const _FriendsFixture([pending]),
      _ChatFixture(),
      brightness: Brightness.dark,
      size: const Size(1280, 720),
    );
    expect(
      find.text('Your friends appear here after accepting a request.'),
      findsOneWidget,
    );
    expect(find.text('Morgan Chen'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter sends, Shift+Enter inserts a line break and IME is safe', (
    tester,
  ) async {
    final chat = _ChatFixture();
    await showChat(tester, const _FriendsFixture([accepted]), chat);
    await openConversation(tester);
    final field = getComposer();
    await tester.enterText(field, 'Hello');
    final draft = tester.widget<TextField>(field).controller!;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(draft.text, 'Hello\n');
    expect(chat.attempts, isEmpty);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Hello\n朋友',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 6, end: 8),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(chat.attempts, isEmpty);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Hello\n朋友',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chat.attempts.single.text, 'Hello\n朋友');
    expect(draft.text, isEmpty);
    expect(find.text('Hello\n朋友'), findsOneWidget);
  });

  testWidgets(
    'failed send keeps the draft and the keyboard action retries it',
    (tester) async {
      final chat = _ChatFixture()..failNextSend = true;
      await showChat(tester, const _FriendsFixture([accepted]), chat);
      await openConversation(tester);
      final field = getComposer();
      await tester.enterText(field, 'Can we meet after class?');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final draft = tester.widget<TextField>(field).controller!;
      expect(draft.text, 'Can we meet after class?');
      expect(
        find.text('Could not send. Your draft is still here.'),
        findsOneWidget,
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(chat.attempts, hasLength(2));
      expect(chat.attempts.first.id, chat.attempts.last.id);
      expect(chat.messages, hasLength(1));
      expect(draft.text, isEmpty);
    },
  );
}

class _FriendsFixture implements FriendRepository {
  const _FriendsFixture(this.requests);

  final List<SchoolFriendRequest> requests;

  @override
  String get uid => 'me';

  @override
  Stream<List<SchoolFriendRequest>> watchRequests() => Stream.value(requests);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatFixture implements SchoolChatRepository {
  final opened = <String>[];
  final attempts = <({String id, String peerId, String text})>[];
  final messages = <SchoolChatMessage>[];
  final _events = StreamController<List<SchoolChatMessage>>.broadcast();
  var _nextId = 0;
  var failNextSend = false;

  @override
  String get uid => 'me';

  @override
  String createMessageId() => 'message-${_nextId++}';

  @override
  Stream<List<SchoolChatMessage>> watchMessages(String friendUid) async* {
    opened.add(friendUid);
    yield List.of(messages);
    yield* _events.stream;
  }

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
  }) async {
    attempts.add((id: messageId, peerId: friendUid, text: text));
    if (failNextSend) {
      failNextSend = false;
      throw StateError('Network unavailable');
    }
    messages.add(
      SchoolChatMessage(
        id: messageId,
        senderId: uid,
        text: text,
        createdAt: DateTime.utc(2026, 11, 22),
      ),
    );
    _events.add(List.of(messages));
  }

  Future<void> close() => _events.close();
}
