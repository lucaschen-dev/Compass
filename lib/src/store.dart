import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'data.dart';

// ChangeNotifier + ListenableBuilder: https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html
class CampusStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final FlutterSecureStorage vault;
  CampusApi? api;
  Json? snapshot;
  bool demo = false, restoring = true, refreshing = false;
  String? error;
  Set<String> saved = {}, blocked = {};
  int generation = 0;
  CampusStore(
    this.prefs, {
    this.vault = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });
  Json get me => snapshot?['me'] as Json? ?? demoMe;
  String get scope => demo ? 'demo' : text(me, 'id');
  bool get admin => !demo && me['role'] == 'Administrator';
  List<Json> get posts =>
      rows(snapshot?['posts'])
          .where((p) => !blocked.contains((p['author'] as Json?)?['id']))
          .toList();
  List<Json> get chats => rows(snapshot?['conversations'])
      .where(
        (c) =>
            c['kind'] == 'group' ||
            !blocked.contains((c['peer'] as Json?)?['id']),
      )
      .toList();
  List<Json> get groups => rows(snapshot?['groups']);
  bool get onboarding =>
      !demo &&
      (snapshot?['needsPassword'] == true || snapshot?['needsProfile'] == true);
  void loadPreferences() {
    saved = (prefs.getStringList('saved.$scope') ?? []).toSet();
    blocked = (prefs.getStringList('blocked.$scope') ?? []).toSet();
  }

  Future<void> persist() async {
    if (demo) await prefs.setString('demoSnapshot', jsonEncode(snapshot));
    notifyListeners();
  }

  Future<void> enterDemo() async {
    generation++;
    api?.close();
    api = null;
    error = null;
    demo = true;
    try {
      snapshot = jsonDecode(prefs.getString('demoSnapshot') ?? '') as Json;
    } catch (_) {
      snapshot = demoSnapshot();
    }
    loadPreferences();
    notifyListeners();
  }

  Future<void> connect(String url) async {
    final next = CampusApi(url);
    api?.close();
    api = next;
    await prefs.setString('serverURL', url);
  }

  Future<void> restore() async {
    try {
      final token = await vault.read(key: 'session');
      final url = prefs.getString('serverURL');
      if (token != null && url != null) {
        api = CampusApi(url, token: token);
        snapshot = await api!.request('bootstrap') as Json;
        loadPreferences();
      }
    } on ApiException catch (e) {
      if (e.status == 401) {
        await vault.delete(key: 'session');
      }
      error = e.message;
      snapshot = null;
    } catch (_) {
      error = 'Could not restore your school session. Check your connection or sign in again.';
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> requestCode(String email) async {
    await api!.request('auth/request', method: 'POST', body: {'email': email});
  }

  Future<void> authenticate(
    String email,
    String credential, {
    bool code = false,
  }) async {
    final current = api!;
    final result = await current.request(
      code ? 'auth/verify' : 'auth/login',
      method: 'POST',
      body: {'email': email, code ? 'code' : 'password': credential},
    ) as Json;
    current.token = text(result, 'token');
    try {
      final data = await current.request('bootstrap') as Json;
      await vault.write(key: 'session', value: current.token);
      snapshot = data;
      if (code) snapshot!['needsPassword'] = true;
      demo = false;
      generation++;
      loadPreferences();
      notifyListeners();
    } catch (_) {
      current.token = null;
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (demo || api?.token == null || refreshing || snapshot == null) return;
    refreshing = true;
    final current = api;
    final epoch = generation;
    try {
      final next = await current!.request('bootstrap') as Json;
      if (epoch == generation) {
        snapshot = next;
        error = null;
        notifyListeners();
      }
    } catch (e) {
      if (epoch == generation) {
        error = e.toString();
        notifyListeners();
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> signOut() async {
    generation++;
    final current = api;
    final wasDemo = demo;
    api = null;
    snapshot = null;
    demo = false;
    saved = {};
    blocked = {};
    error = null;
    await vault.delete(key: 'session');
    notifyListeners();
    if (!wasDemo && current?.token != null) {
      try {
        await current!.request('auth/logout', method: 'POST', body: {});
      } catch (_) {
        error = 'Signed out locally. Server revocation could not be confirmed.';
        notifyListeners();
      }
    }
    current?.close();
  }

  Future<void> setPassword(String password) async {
    await api!.request(
      'auth/password',
      method: 'POST',
      body: {'password': password},
    );
    snapshot!['needsPassword'] = false;
    notifyListeners();
  }

  Future<void> profile(Json person) async {
    if (demo) {
      snapshot!['me'] = person;
      await persist();
    } else {
      await api!.request('profile', method: 'PATCH', body: person);
      await refresh();
    }
  }

  Future<void> toggleSave(String id) async {
    if (!saved.add(id)) saved.remove(id);
    await prefs.setStringList('saved.$scope', saved.toList());
    notifyListeners();
  }

  Future<String> publish(Json draft) async {
    if (text(draft, 'title').trim().isEmpty ||
        (draft['kind'] != 'Photo Gallery' &&
            text(draft, 'body').trim().isEmpty)) {
      throw ApiException(0, 'Add a title and a little detail.');
    }
    if (text(draft, 'title').length > 140 ||
        text(draft, 'body').length > 5000) {
      throw ApiException(0, 'Title or details are too long.');
    }
    if (draft['kind'] == 'Photo Gallery' &&
        ((draft['photoIDs'] as List? ?? []).isEmpty ||
            (draft['photoIDs'] as List).length > 20)) {
      throw ApiException(0, 'Choose 1 to 20 photos.');
    }
    if (demo) {
      final p = clone(draft);
      p.addAll({
        'id': newID(),
        'author': draft['anonymous'] == true ? null : clone(me),
        'isMine': true,
        'important': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch / 1000,
        'replies': <Json>[],
        'groupName': text(
          groups.firstWhere(
            (g) => g['id'] == draft['groupID'],
            orElse: () => {},
          ),
          'name',
          'Everyone',
        ),
      });
      snapshot!['posts'] = [p, ...rows(snapshot!['posts'])];
      await persist();
      return 'Saved in demo. No real publication or AI review occurred.';
    }
    final result = await api!.request(
      'posts',
      method: 'POST',
      body: draft,
      timeout: 90,
    ) as Json;
    await refresh();
    return result['status'] == 'published'
        ? 'Posted.'
        : 'Waiting for moderator review.';
  }

  Future<String> uploadPhoto(Uint8List bytes) async {
    if (demo) {
      final id = newID();
      await prefs.setString('photo.$scope.$id', base64Encode(bytes));
      return id;
    }
    return text(
      await api!.request(
        'photos',
        method: 'POST',
        body: {'jpeg': base64Encode(bytes)},
      ) as Json,
      'id',
    );
  }

  Future<Uint8List> photo(String id) async {
    final b64 = demo
        ? prefs.getString('photo.$scope.$id')
        : (await api!.request('photos/$id') as Json)['jpeg'] as String?;
    if (b64 == null) throw ApiException(404, 'Photo unavailable.');
    return base64Decode(b64);
  }

  Future<String> reply(String id, String body) async {
    if (body.trim().isEmpty || body.length > 2000) {
      throw ApiException(0, 'Write a reply of up to 2,000 characters.');
    }
    if (demo) {
      final ps = rows(snapshot!['posts']);
      final p = ps.firstWhere((p) => p['id'] == id);
      p['replies'] = [
        ...rows(p['replies']),
        {'id': newID(), 'author': me, 'body': body},
      ];
      snapshot!['posts'] = ps;
      await persist();
      return 'Saved in demo.';
    }
    final result = await api!.request(
      'posts/$id/replies',
      method: 'POST',
      body: {'body': body},
    ) as Json;
    await refresh();
    return result['status'] == 'published'
        ? 'Reply posted.'
        : 'Reply submitted for human review.';
  }

  Future<void> deleteReply(String id) async {
    if (!demo) await api!.request('replies/$id', method: 'DELETE');
    final ps = rows(snapshot!['posts']);
    for (final p in ps) {
      p['replies'] = rows(p['replies']).where((r) => r['id'] != id).toList();
    }
    snapshot!['posts'] = ps;
    await persist();
  }

  Future<void> managePost(String id, {bool? anonymous}) async {
    if (!demo) {
      await api!.request(
        'posts/$id',
        method: anonymous == null ? 'DELETE' : 'PATCH',
        body: anonymous == null ? null : {'anonymous': anonymous},
      );
    }
    if (demo) {
      final ps = rows(snapshot!['posts']);
      if (anonymous == null) {
        ps.removeWhere((p) => p['id'] == id);
      } else {
        final p = ps.firstWhere((p) => p['id'] == id);
        p['anonymous'] = anonymous;
        p['author'] = anonymous ? null : me;
      }
      snapshot!['posts'] = ps;
      await persist();
    } else {
      await refresh();
    }
  }

  Future<List<Json>> ownPosts() async => demo
      ? posts
            .where(
              (p) =>
                  p['isMine'] == true ||
                  (p['author'] as Json?)?['id'] == me['id'],
            )
            .toList()
      : rows(await api!.request('posts/mine'));
  Future<void> report(String id, String reason) async {
    if (demo) {
      await prefs.setString('demoReport.$id', reason);
    } else {
      await api!.request(
        'reports',
        method: 'POST',
        body: {'postID': id, 'reason': reason},
      );
    }
  }

  Future<void> block(String id) async {
    if (!demo) {
      await api!.request('blocks', method: 'POST', body: {'userID': id});
    }
    blocked.add(id);
    await prefs.setStringList('blocked.$scope', blocked.toList());
    notifyListeners();
  }

  Future<List<Json>> members() async => demo
      ? [demoMaya, demoAlex].where((p) => !blocked.contains(p['id'])).toList()
      : rows(await api!.request('members'));
  Future<Json> startChat(Json person) async {
    for (final c in chats) {
      if (c['kind'] != 'group' && (c['peer'] as Json)['id'] == person['id']) {
        return c;
      }
    }
    if (demo) {
      final c = <String, dynamic>{
        'id': newID(),
        'peer': person,
        'kind': 'direct',
        'participants': [me, person],
        'messages': <Json>[],
      };
      snapshot!['conversations'] = [c, ...chats];
      await persist();
      return c;
    }
    final c = await api!.request(
      'conversations',
      method: 'POST',
      body: {'peerID': person['id']},
    ) as Json;
    await refresh();
    return c;
  }

  Future<Json> createGroup(String title, List<Json> people) async {
    if (title.trim().isEmpty ||
        title.length > 60 ||
        people.length < 2 ||
        people.length > 99) {
      throw ApiException(
        0,
        'Add a group name and choose 2 to 99 other members.',
      );
    }
    if (demo) {
      final c = <String, dynamic>{
        'id': newID(),
        'kind': 'group',
        'title': title,
        'peer': {'name': title},
        'participants': [me, ...people],
        'messages': <Json>[],
      };
      snapshot!['conversations'] = [c, ...chats];
      await persist();
      return c;
    }
    final c = await api!.request(
      'group-conversations',
      method: 'POST',
      body: {
        'title': title,
        'participantIDs': people.map((p) => p['id']).toList(),
      },
    ) as Json;
    await refresh();
    return c;
  }

  Future<void> leave(String id) async {
    if (!demo) {
      await api!.request('conversations/$id/leave', method: 'POST', body: {});
    }
    snapshot!['conversations'] = chats.where((c) => c['id'] != id).toList();
    await persist();
  }

  Future<void> send(
    String id,
    String body, {
    String? replyID,
    String? mediaID,
    String? mediaKind,
  }) async {
    if ((body.trim().isEmpty && mediaID == null) || body.length > 2000) {
      throw ApiException(0, 'Write a message of up to 2,000 characters.');
    }
    Json message;
    if (demo) {
      message = {
        'id': newID(),
        'senderID': me['id'],
        'body': body,
        'createdAt': DateTime.now().millisecondsSinceEpoch / 1000,
        'replyID': replyID,
      };
    } else {
      final result = await api!.request(
        'conversations/$id/messages',
        method: 'POST',
        body: {'body': body, 'replyID': ?replyID, 'mediaID': ?mediaID},
      ) as Json;
      message = result['message'] as Json? ?? {};
    }
    final cs = rows(snapshot!['conversations']);
    final c = cs.firstWhere((c) => c['id'] == id);
    if (message.isNotEmpty) {
      c['messages'] = [
        ...rows(c['messages']).where((m) => m['id'] != message['id']),
        message,
      ];
    }
    snapshot!['conversations'] = cs;
    await persist();
    if (!demo) await refresh();
  }

  Future<void> retract(String chatID, String messageID) async {
    if (!demo) {
      await api!.request(
        'conversations/$chatID/messages/$messageID',
        method: 'DELETE',
      );
    }
    final cs = rows(snapshot!['conversations']);
    final c = cs.firstWhere((c) => c['id'] == chatID);
    final ms = rows(c['messages']);
    final m = ms.firstWhere((m) => m['id'] == messageID);
    m.addAll({'retracted': true, 'body': '', 'mediaID': null, 'replyID': null});
    c['messages'] = ms;
    snapshot!['conversations'] = cs;
    await persist();
  }

  Future<String> uploadMedia(
    String chatID,
    Uint8List bytes,
    String kind,
  ) async {
    if (demo) throw ApiException(0, 'Media messages need a school account.');
    return text(
      await api!.request(
        'conversations/$chatID/media',
        method: 'POST',
        body: {'kind': kind, 'data': base64Encode(bytes)},
        timeout: 180,
      ) as Json,
      'id',
    );
  }

  Future<Json> media(String id) async =>
      await api!.request('chat-media/$id', timeout: 90) as Json;
  Future<dynamic> administrator(
    String path, {
    String method = 'POST',
    Json? body,
  }) async {
    if (!admin) throw ApiException(403, 'Administrator access required.');
    final result = await api!.request(
      'admin/$path',
      method: method,
      body: body,
    );
    return result;
  }

  @override
  void dispose() {
    generation++;
    api?.close();
    super.dispose();
  }
}
