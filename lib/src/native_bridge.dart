import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'store.dart';
import 'planner.dart';
import 'photos.dart';

/// Native SwiftUI presentation; Dart stores remain the only business-data owner.
/// https://docs.flutter.dev/platform-integration/platform-channels
class NativeBridge {
  static const channel = MethodChannel('community.buckley.compass/native');
  final CampusStore store;
  final PlannerStore planner;
  Timer? polling;
  bool active = true;
  NativeBridge(this.store, this.planner);
  Json state() => {
    'snapshot': store.snapshot == null
        ? null
        : {
            ...store.snapshot!,
            'posts': store.posts,
            'conversations': store.chats,
          },
    'isDemo': store.demo,
    'restoring': store.restoring,
    'error': store.error,
    'saved': store.saved.toList(),
    'serverURL':
        store.prefs.getString('serverURL') ?? 'https://api.buckley.community',
    'draft': _draft().isEmpty ? null : _draft(),
    'planner': {
      'todos': planner.todos,
      'assignments': planner.assignments,
      'connected': planner.connected,
      'syncing': planner.syncing,
      'error': planner.error,
      'lastSync': planner.lastSync,
    },
  };
  Json _draft() {
    try {
      return jsonDecode(store.prefs.getString('draft.${store.scope}') ?? '{}')
          as Json;
    } catch (_) {
      return {};
    }
  }

  Future<void> emit() async {
    await channel.invokeMethod<void>('state', jsonEncode(state()));
  }

  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      try {
        final result = await action(call.method, args);
        await emit();
        return result;
      } catch (e) {
        throw PlatformException(code: 'compass', message: e.toString());
      }
    });
    store.addListener(changed);
    planner.addListener(changed);
    await channel.invokeMethod<void>('ready');
    await store.restore();
    await changed();
    polling = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!active) return;
      await store.refresh();
    });
  }

  Future<void> changed() async {
    final next = store.snapshot == null ? 'signed-out' : store.scope;
    if (planner.scope != next) await planner.load(next);
    await emit();
  }

  void dispose() {
    polling?.cancel();
    store.removeListener(changed);
    planner.removeListener(changed);
    channel.setMethodCallHandler(null);
  }

  Future<dynamic> action(String method, Json a) async {
    switch (method) {
      case 'getState':
        return jsonEncode(state());
      case 'active':
        active = a['value'] == true;
        if (active) await store.refresh();
        return null;
      case 'demo':
        await store.enterDemo();
        return null;
      case 'connect':
        await store.connect(text(a, 'url'));
        return null;
      case 'requestCode':
        await store.connect(text(a, 'url'));
        await store.requestCode(text(a, 'email'));
        return null;
      case 'login':
        await store.connect(text(a, 'url'));
        await store.authenticate(
          text(a, 'email'),
          text(a, 'credential'),
          code: a['code'] == true,
        );
        return null;
      case 'password':
        await store.setPassword(text(a, 'password'));
        return null;
      case 'profile':
        await store.profile(Map<String, dynamic>.from(a['profile'] as Map));
        return null;
      case 'signOut':
        await store.signOut();
        return null;
      case 'refresh':
        await store.refresh();
        return null;
      case 'save':
        await store.toggleSave(text(a, 'id'));
        return null;
      case 'publish':
        final draft = Map<String, dynamic>.from(a['draft'] as Map)
          ..remove('askedName');
        final result = await store.publish(draft);
        await store.prefs.remove('draft.${store.scope}');
        return result;
      case 'draft':
        await store.prefs.setString(
          'draft.${store.scope}',
          jsonEncode(a['draft']),
        );
        return null;
      case 'reply':
        return store.reply(text(a, 'id'), text(a, 'body'));
      case 'deleteReply':
        await store.deleteReply(text(a, 'id'));
        return null;
      case 'managePost':
        await store.managePost(
          text(a, 'id'),
          anonymous: a['anonymous'] as bool?,
        );
        return null;
      case 'ownPosts':
        return store.ownPosts();
      case 'members':
        return store.members();
      case 'report':
        await store.report(text(a, 'id'), text(a, 'reason'));
        return null;
      case 'block':
        await store.block(text(a, 'id'));
        return null;
      case 'startChat':
        return store.startChat(Map<String, dynamic>.from(a['person'] as Map));
      case 'createGroup':
        return store.createGroup(text(a, 'title'), rows(a['members']));
      case 'leave':
        await store.leave(text(a, 'id'));
        return null;
      case 'send':
        await store.send(
          text(a, 'id'),
          text(a, 'body'),
          replyID: a['replyID'] as String?,
          mediaID: a['mediaID'] as String?,
        );
        return null;
      case 'retract':
        await store.retract(text(a, 'chatID'), text(a, 'id'));
        return null;
      case 'photo':
        return store.photo(text(a, 'id'));
      case 'uploadPhoto':
        final bytes = await compute(preparePhoto, a['bytes'] as Uint8List);
        return store.uploadPhoto(bytes);
      case 'uploadMedia':
        var bytes = a['bytes'] as Uint8List;
        if (a['kind'] == 'photo') bytes = await compute(preparePhoto, bytes);
        return store.uploadMedia(text(a, 'id'), bytes, text(a, 'kind'));
      case 'media':
        return store.media(text(a, 'id'));
      case 'todoSave':
        await planner.saveTodo(Map<String, dynamic>.from(a['todo'] as Map));
        return null;
      case 'todoRemove':
        await planner.remove(text(a, 'id'));
        return null;
      case 'assignmentTodo':
        await planner.addAssignment(
          Map<String, dynamic>.from(a['assignment'] as Map),
        );
        return null;
      case 'feed':
        await planner.connect(text(a, 'url'));
        if (planner.error != null) throw Exception(planner.error);
        return null;
      case 'syncFeed':
        await planner.sync();
        if (planner.error != null) throw Exception(planner.error);
        return null;
      case 'disconnectFeed':
        await planner.disconnect();
        return null;
      case 'admin':
        final result = await store.administrator(
          text(a, 'path'),
          method: text(a, 'method', 'POST'),
          body: a['body'] is Map
              ? Map<String, dynamic>.from(a['body'] as Map)
              : null,
        );
        if (a['method'] != 'GET' && !text(a, 'path').endsWith('/list')) {
          await store.refresh();
        }
        return result;
      default:
        throw MissingPluginException(method);
    }
  }
}
