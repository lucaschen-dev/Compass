import 'dart:async';

import 'package:compass_flutter/src/data/friend_repository.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_people_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const teacher = SchoolDirectoryMember(uid: 'jordan', name: 'Jordan Lee');
  const classmate = SchoolDirectoryMember(uid: 'morgan', name: 'Morgan Chen');

  Future<void> showPeople(
    WidgetTester tester,
    _FriendFixture repository, {
    void Function(BuildContext, String, String)? onOpenChat,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(repository.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(Brightness.light),
        home: SchoolPeopleDirectory(
          schoolName: 'Alderline',
          repository: repository,
          onOpenChat: onOpenChat,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder view(String title) => find.widgetWithText(ChoiceChip, title);

  testWidgets(
    'search sends a pending request and only acceptance adds a friend',
    (tester) async {
      final repo = _FriendFixture([teacher, classmate]);
      (String, String)? openedChat;
      await showPeople(
        tester,
        repo,
        onOpenChat: (_, uid, name) => openedChat = (uid, name),
      );
      await tester.enterText(find.byType(TextField), 'jordan');
      await tester.pumpAndSettle();
      expect(find.text(teacher.name), findsOneWidget);
      expect(find.text(classmate.name), findsNothing);
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.sent, [teacher.uid]);
      expect(find.text('Requested'), findsOneWidget);

      await tester.tap(view('Friends'));
      await tester.pumpAndSettle();
      expect(find.text(teacher.name), findsNothing);
      expect(find.text('Accepted requests appear here.'), findsOneWidget);
      expect(find.byTooltip('Message Jordan Lee'), findsNothing);
      repo.replaceRequests([
        const SchoolFriendRequest(
          senderId: 'me',
          recipientId: 'jordan',
          status: FriendRequestStatus.accepted,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text(teacher.name), findsOneWidget);
      expect(find.text('Accepted requests appear here.'), findsNothing);
      await tester.tap(find.byTooltip('Message Jordan Lee'));
      expect(openedChat, (teacher.uid, teacher.name));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('incoming request can be accepted even when sender is unlisted', (
    tester,
  ) async {
    final repo = _FriendFixture([classmate]);
    repo.replaceRequests([
      const SchoolFriendRequest(
        senderId: 'jordan',
        senderName: 'Jordan Lee',
        recipientId: 'me',
        status: FriendRequestStatus.pending,
      ),
    ]);
    await showPeople(tester, repo);
    expect(find.text(teacher.name), findsNothing);
    await tester.tap(view('Requests (1)'));
    await tester.pumpAndSettle();
    expect(find.text(teacher.name), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repo.responses, [(teacher.uid, true)]);
    expect(find.text('No pending requests.'), findsOneWidget);
    await tester.tap(view('Friends'));
    await tester.pumpAndSettle();
    expect(find.text(teacher.name), findsOneWidget);
  });

  testWidgets('opt-in controls own listing and exact codes can be requested', (
    tester,
  ) async {
    final repo = _FriendFixture([]);
    await showPeople(tester, repo);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    expect(find.text('My Name'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );

    await tester.tap(find.text('Add by code'));
    await tester.pumpAndSettle();
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, ' HiddenCode ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
    await tester.pumpAndSettle();
    expect(repo.sent, ['HiddenCode']);
    expect(find.text('Waiting for acceptance'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.canceled, ['HiddenCode']);
    expect(find.text('No pending requests.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FriendFixture implements FriendRepository {
  _FriendFixture(this._members);

  List<SchoolDirectoryMember> _members;
  List<SchoolFriendRequest> _currentRequests = [];
  final _membersStream =
      StreamController<List<SchoolDirectoryMember>>.broadcast();
  final _requestsStream =
      StreamController<List<SchoolFriendRequest>>.broadcast();
  final sent = <String>[];
  final canceled = <String>[];
  final responses = <(String, bool)>[];

  @override
  String get uid => 'me';

  @override
  String get myCode => uid;

  @override
  Stream<List<SchoolDirectoryMember>> watchDirectory() async* {
    yield _members;
    yield* _membersStream.stream;
  }

  @override
  Stream<List<SchoolFriendRequest>> watchRequests() async* {
    yield _currentRequests;
    yield* _requestsStream.stream;
  }

  void replaceRequests(List<SchoolFriendRequest> requests) {
    _currentRequests = requests;
    _requestsStream.add(requests);
  }

  @override
  Future<void> publishProfile() async {
    _members = [
      ..._members,
      const SchoolDirectoryMember(uid: 'me', name: 'My Name'),
    ];
    _membersStream.add(_members);
  }

  @override
  Future<void> hideProfile() async {
    _members = _members.where((member) => member.uid != uid).toList();
    _membersStream.add(_members);
  }

  @override
  Future<void> sendRequest(String otherUid) async {
    sent.add(otherUid);
    replaceRequests([
      SchoolFriendRequest(
        senderId: uid,
        recipientId: otherUid,
        status: FriendRequestStatus.pending,
      ),
    ]);
  }

  @override
  Future<void> respondToRequest(String otherUid, {required bool accept}) async {
    responses.add((otherUid, accept));
    replaceRequests([
      SchoolFriendRequest(
        senderId: otherUid,
        senderName: _currentRequests.single.senderName,
        recipientId: uid,
        status: accept
            ? FriendRequestStatus.accepted
            : FriendRequestStatus.declined,
      ),
    ]);
  }

  @override
  Future<void> cancelRequest(String otherUid) async {
    canceled.add(otherUid);
    replaceRequests([
      SchoolFriendRequest(
        senderId: uid,
        recipientId: otherUid,
        status: FriendRequestStatus.canceled,
      ),
    ]);
  }

  Future<void> close() async {
    await _membersStream.close();
    await _requestsStream.close();
  }
}
