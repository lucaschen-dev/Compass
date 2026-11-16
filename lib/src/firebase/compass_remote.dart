import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../community_models.dart';
import '../data/firestore_repositories.dart';
import '../data/sync_codec.dart';
import '../data/user_state.dart';
import '../school_demo.dart';

const syncOfflineMessage =
    "Saved on this device. Compass couldn't sync that change.";

class CompassRemote {
  CompassRemote({
    required this.uid,
    required this.school,
    required this.gateway,
    required this.readState,
    required this.applyState,
    required this.notice,
  });

  final String uid;
  final DemoSchool school;
  final FirestoreGateway gateway;
  final UserSchoolState Function() readState;
  final Future<void> Function(UserSchoolState state) applyState;
  final ValueNotifier<String?> notice;

  CommunityController? controller;
  String? _baseline;
  String? _latest;
  String? _lastState;
  bool _suppress = false;
  Timer? _timer;
  StreamSubscription<List<ChatMessage>>? _messages;
  String? _watching;
  final _hidden = <String>{};

  String get _hiddenKey => 'compass.sync.$uid.${school.id}.hiddenMessages';
  String get _postsKey => 'compass.sync.$uid.${school.id}.postsAt';
  String get _threadsKey => 'compass.sync.$uid.${school.id}.threadsAt';
  String get _seedKey => 'compass.sync.$uid.${school.id}.seededRemote';

  void onCommunityWrite(String encoded) {
    if (_suppress) {
      _baseline = encoded;
      return;
    }
    _latest = encoded;
    schedulePush();
  }

  void schedulePush() {
    if (_suppress) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      unawaited(flush());
    });
  }

  Future<void> hydrate(CommunityController controller) async {
    this.controller = controller;
    _suppress = true;
    try {
      await loadHidden();
      await gateway.listSchools();
      final state = await gateway.loadState(uid, school.id);
      if (state != null) {
        await applyState(state);
        await controller.replaceLists(
          savedPosts: state.savedPosts.toSet(),
          likedPosts: state.likedPosts.toSet(),
          followedTags: state.followedTags.toSet(),
          clubApplies: state.clubApplies.toSet(),
        );
      }
      final remotePosts = await gateway.fetchPosts(school.id, uid);
      final remoteThreads = await gateway.fetchThreads(school.id);
      await controller.replaceLists(
        posts: mergePosts(
          local: controller.posts,
          remote: remotePosts,
          uid: uid,
        ),
        threads: mergeThreads(
          local: controller.threads,
          remote: remoteThreads,
          uid: uid,
          hidden: _hidden,
        ),
      );
      final remoteEmpty = remotePosts.isEmpty && remoteThreads.isEmpty;
      _baseline = controller.encode();
      _latest = _baseline;
      _lastState = jsonEncode(readState().toMap());
      _suppress = false;
      await _seedOwned(
        remoteEmpty: remoteEmpty,
        hadState: state != null,
        controller: controller,
      );
      final now = DateTime.now().toIso8601String();
      await gateway.preferences.setString(_postsKey, now);
      await gateway.preferences.setString(_threadsKey, now);
    } catch (_) {
      _reportOffline();
    } finally {
      _suppress = false;
      _baseline ??= controller.encode();
      _latest ??= _baseline;
      _lastState ??= jsonEncode(readState().toMap());
    }
  }

  Future<void> _seedOwned({
    required bool remoteEmpty,
    required bool hadState,
    required CommunityController controller,
  }) async {
    if (await gateway.preferences.getBool(_seedKey) == true) return;
    try {
      if (!hadState) {
        final state = readState();
        await gateway.saveState(uid, school.id, state);
        _lastState = jsonEncode(state.toMap());
      }
      if (remoteEmpty) {
        await gateway.applyDelta(
          school.id,
          diffEncoded(
            previousEncoded: null,
            nextEncoded: controller.encode(),
            uid: uid,
          ),
          uid,
        );
      }
      await gateway.preferences.setBool(_seedKey, true);
      _baseline = controller.encode();
    } catch (_) {
      _reportOffline();
    }
  }

  Future<void> flush() async {
    final current = controller;
    final encoded = _latest ?? current?.encode();
    if (current == null || encoded == null) return;
    final delta = diffEncoded(
      previousEncoded: _baseline,
      nextEncoded: encoded,
      uid: uid,
    );
    if (delta.hiddenMessageIds.isNotEmpty) {
      _hidden.addAll(delta.hiddenMessageIds);
      await gateway.preferences.setString(
        _hiddenKey,
        jsonEncode(_hidden.toList()),
      );
    }
    final state = readState();
    final stateJson = jsonEncode(state.toMap());
    final stateChanged = stateJson != _lastState;
    if (delta.isEmpty && !stateChanged) {
      _baseline = encoded;
      return;
    }
    try {
      if (stateChanged) await gateway.saveState(uid, school.id, state);
      if (!delta.isEmpty) await gateway.applyDelta(school.id, delta, uid);
      _baseline = encoded;
      _lastState = stateJson;
    } catch (_) {
      _reportOffline();
    }
  }

  Future<void> refreshPosts({bool force = false}) async {
    if (controller == null) return;
    if (!force && !await _stale(_postsKey)) return;
    try {
      final remote = await gateway.fetchPosts(school.id, uid);
      final merged = mergePosts(
        local: controller!.posts,
        remote: remote,
        uid: uid,
      );
      _suppress = true;
      await controller!.replaceLists(posts: merged);
      await gateway.preferences.setString(
        _postsKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      _reportOffline();
    } finally {
      _suppress = false;
      _baseline = controller?.encode();
    }
  }

  Future<void> refreshThreads({bool force = false}) async {
    if (controller == null) return;
    if (!force && !await _stale(_threadsKey)) return;
    try {
      final remote = await gateway.fetchThreads(school.id);
      final merged = mergeThreads(
        local: controller!.threads,
        remote: remote,
        uid: uid,
        hidden: _hidden,
      );
      _suppress = true;
      await controller!.replaceLists(threads: merged);
      await gateway.preferences.setString(
        _threadsKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      _reportOffline();
    } finally {
      _suppress = false;
      _baseline = controller?.encode();
    }
  }

  Future<void> watchThread(String threadId) async {
    await unwatchThread();
    _watching = threadId;
    try {
      final messages = await gateway.fetchMessages(school.id, threadId, uid);
      await _applyMessages(threadId, messages);
      _messages = gateway.watchMessages(school.id, threadId, uid).listen(
        (incoming) {
          unawaited(_applyMessages(threadId, incoming));
        },
        onError: (_) => _reportOffline(),
      );
    } catch (_) {
      _reportOffline();
    }
  }

  Future<void> unwatchThread() async {
    _watching = null;
    await _messages?.cancel();
    _messages = null;
  }

  Future<void> loadHidden() async {
    final raw = await gateway.preferences.getString(_hiddenKey);
    if (raw == null) return;
    try {
      _hidden.addAll((jsonDecode(raw) as List).whereType<String>());
    } catch (_) {}
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await unwatchThread();
  }

  Future<void> _applyMessages(String threadId, List<ChatMessage> remote) async {
    if (_watching != null && _watching != threadId) return;
    final thread = controller?.threads.where((item) => item.id == threadId).firstOrNull;
    if (thread == null) return;
    final merged = mergeMessages(
      local: thread.messages,
      remote: remote,
      uid: uid,
      hidden: _hidden,
    );
    if (_sameMessages(thread.messages, merged)) return;
    _suppress = true;
    try {
      await controller!.updateThread(thread.copyWith(messages: merged));
    } finally {
      _suppress = false;
      _baseline = controller?.encode();
    }
  }

  Future<bool> _stale(String key) async {
    final raw = await gateway.preferences.getString(key);
    final at = raw == null ? null : DateTime.tryParse(raw);
    if (at == null) return true;
    return DateTime.now().difference(at) > remoteStaleAfter;
  }

  void _reportOffline() {
    notice.value = null;
    notice.value = syncOfflineMessage;
  }
}

bool _sameMessages(List<ChatMessage> left, List<ChatMessage> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i].id != right[i].id ||
        left[i].text != right[i].text ||
        left[i].unsent != right[i].unsent ||
        left[i].reaction != right[i].reaction ||
        left[i].edited != right[i].edited) {
      return false;
    }
  }
  return true;
}
