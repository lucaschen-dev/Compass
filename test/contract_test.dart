import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:compass_flutter/src/api.dart';
import 'package:compass_flutter/src/data.dart';

void main() {
  final url = Platform.environment['COMPASS_TEST_API'];
  test(
    'Flutter talks to unchanged Python backend through real HTTP',
    () async {
      final a = CampusApi(url!), b = CampusApi(url);
      addTearDown(a.close);
      addTearDown(b.close);
      for (final client in [a, b]) {
        final who = client == a ? 'alice' : 'bob';
        final auth = await client.request(
          'auth/login',
          method: 'POST',
          body: {
            'email': '$who@students.example.edu',
            'password': 'fixture-password-123',
          },
        ) as Json;
        client.token = text(auth, 'token');
      }
      final alice = await a.request('bootstrap') as Json,
          bob = await b.request('bootstrap') as Json;
      await a.request(
        'posts',
        method: 'POST',
        body: {
          'title': 'Flutter HTTP integration',
          'body': 'An anonymous post from the port.',
          'kind': 'Question',
          'anonymous': true,
          'groupID': 'all',
          'visibility': 'school',
          'priority': 'normal',
        },
      );
      final posts = rows((await b.request('bootstrap') as Json)['posts']);
      final post = posts.firstWhere(
        (p) => p['title'] == 'Flutter HTTP integration',
      );
      expect(post['author'], isNull);
      await b.request(
        'posts/${post['id']}/replies',
        method: 'POST',
        body: {'body': 'Reply over real HTTP'},
      );
      final refreshed = rows((await a.request('bootstrap') as Json)['posts'])
          .firstWhere((p) => p['id'] == post['id']);
      expect(rows(refreshed['replies']).length, 1);
      final chat = await a.request(
        'conversations',
        method: 'POST',
        body: {'peerID': (bob['me'] as Json)['id']},
      ) as Json;
      final sent = await a.request(
        'conversations/${chat['id']}/messages',
        method: 'POST',
        body: {'body': 'Message over real HTTP'},
      ) as Json;
      expect(
        (sent['message'] as Json)['senderID'],
        (alice['me'] as Json)['id'],
      );
      await a.request(
        'conversations/${chat['id']}/messages/${(sent['message'] as Json)['id']}',
        method: 'DELETE',
      );
      final conversations = rows(
        (await b.request('bootstrap') as Json)['conversations'],
      );
      expect(
        rows(conversations.firstWhere((c) => c['id'] == chat['id'])['messages'])
            .last['retracted'],
        true,
      );
      final admin = await a.request(
        'admin/posts/list',
        method: 'POST',
        body: {
          'status': 'all',
          'query': 'Flutter HTTP integration',
          'offset': 0,
        },
      ) as Json;
      expect(
        rows(admin['items']).first['authorEmail'],
        'alice@students.example.edu',
      );
      await expectLater(
        b.request(
          'admin/posts/list',
          method: 'POST',
          body: {'status': 'all', 'offset': 0},
        ),
        throwsA(isA<ApiException>()),
      );
    },
    skip: url == null
        ? 'Set COMPASS_TEST_API to the disposable loopback fixture.'
        : false,
  );
}
