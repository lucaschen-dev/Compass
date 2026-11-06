import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compass_flutter/src/data.dart';
import 'package:compass_flutter/src/native_bridge.dart';
import 'package:compass_flutter/src/store.dart';
import 'package:compass_flutter/src/planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  test(
    'Native presentation actions use Dart state and do not export credentials',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          store = CampusStore(await SharedPreferences.getInstance());
      final planner = PlannerStore(prefs);
      final bridge = NativeBridge(store, planner);
      addTearDown(store.dispose);
      addTearDown(planner.dispose);
      await bridge.action('demo', {});
      expect(bridge.state()['isDemo'], true);
      expect((bridge.state()['snapshot'] as Json)['posts'], hasLength(4));
      await bridge.action('publish', {
        'draft': {
          'title': 'Native bridge question',
          'body': 'A post created from a native form.',
          'kind': 'Question',
          'anonymous': false,
          'groupID': 'all',
          'visibility': 'school',
          'priority': 'normal',
        },
      });
      final id = text(store.posts.first, 'id');
      await bridge.action('reply', {'id': id, 'body': 'Reply from SwiftUI'});
      await bridge.action('save', {'id': id});
      expect(
        rows(store.posts.first['replies']).single['body'],
        'Reply from SwiftUI',
      );
      expect(store.saved, contains(id));
      final chat =
          await bridge.action('startChat', {'person': demoAlex}) as Json;
      await bridge.action('send', {
        'id': chat['id'],
        'body': 'Native chat message',
      });
      expect(
        messagePreview(rows(store.chats.first['messages']).last),
        'Native chat message',
      );
      await bridge.action('block', {'id': 'maya'});
      final exported = bridge.state()['snapshot'] as Json;
      expect(
        rows(exported['posts'])
            .where((p) => (p['author'] as Json?)?['id'] == 'maya'),
        isEmpty,
      );
      expect(
        rows(exported['conversations'])
            .where((c) => (c['peer'] as Json?)?['id'] == 'maya'),
        isEmpty,
      );
      final encoded = jsonEncode(bridge.state());
      expect(encoded, isNot(contains('Authorization')));
      expect(encoded, isNot(contains('feed.demo')));
    },
  );
  test('Channel handshake streams updates and releases its timer', () async {
    final emitted = <Json>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeBridge.channel, (call) async {
          if (call.method == 'state') {
            emitted.add(jsonDecode(call.arguments as String) as Json);
          }
          return null;
        });
    final prefs = await SharedPreferences.getInstance(),
        store = CampusStore(await SharedPreferences.getInstance());
    final planner = PlannerStore(prefs);
    final bridge = NativeBridge(store, planner);
    await bridge.start();
    await bridge.action('demo', {});
    await bridge.changed();
    expect(emitted.last['isDemo'], true);
    expect(emitted.last['restoring'], false);
    bridge.dispose();
    store.dispose();
    planner.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeBridge.channel, null);
  });
}
