import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../campus_photo_media.dart';
import '../community_models.dart';
import '../data/firestore_repositories.dart';
import '../data/friend_repository.dart';
import '../data/school_chat_repository.dart';
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

  late final FriendRepository friends = FirebaseFriendRepository(
    firestore: gateway.firestore,
    auth: gateway.auth,
    schoolId: school.id,
    uid: uid,
  );
  late final SchoolChatRepository chat = FirebaseSchoolChatRepository(
    firestore: gateway.firestore,
    auth: gateway.auth,
    schoolId: school.id,
    uid: uid,
  );

  CommunityController? controller;
  String? _baseline;
  String? _latest;
  String? _lastState;
  bool _suppress = false;
  Timer? _timer;
  final _acknowledgedGalleryPosts = <String, CommunityPost>{};

  String get _postsKey => 'compass.sync.$uid.${school.id}.postsAt';
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
      await controller.replaceLists(
        posts: mergePosts(
          local: controller.posts,
          remote: remotePosts,
          uid: uid,
        ),
      );
      _baseline = controller.encode();
      _latest = _baseline;
      _lastState = jsonEncode(readState().toMap());
      _suppress = false;
      await _seedOwned(
        remotePostsEmpty: remotePosts.isEmpty,
        hadState: state != null,
        controller: controller,
      );
      final now = DateTime.now().toIso8601String();
      await gateway.preferences.setString(_postsKey, now);
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
    required bool remotePostsEmpty,
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
      if (remotePostsEmpty) {
        final delta = diffEncoded(
          previousEncoded: null,
          nextEncoded: controller.encode(),
          uid: uid,
        );
        await gateway.applyDelta(
          school.id,
          CommunityDelta(
            upsertPosts: delta.upsertPosts,
            upsertReplies: delta.upsertReplies,
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

  Future<void> publishGalleryPost(CommunityPost post) async {
    if (post.category != PostCategory.gallery ||
        !post.sharedGalleryMedia ||
        !ownsAuthor(post.authorId, uid) ||
        post.photos.isEmpty ||
        post.photos.length > galleryPhotoLimit ||
        !post.photos.every(isSharedGalleryPhoto)) {
      throw ArgumentError('Choose up to $galleryPhotoLimit photos to publish.');
    }
    // Only the post document is written. Replies are a separate collection.
    // The composer keeps the same ID on retry, including after a timeout.
    await gateway
        .applyDelta(school.id, CommunityDelta(upsertPosts: [post]), uid)
        .timeout(const Duration(seconds: 18));
    _acknowledgedGalleryPosts[post.id] = post;
  }

  Future<void> flush() async {
    final current = controller;
    final encoded = _latest ?? current?.encode();
    if (current == null || encoded == null) return;
    final changes = diffEncoded(
      previousEncoded: _baseline,
      nextEncoded: encoded,
      uid: uid,
      acknowledgedPosts: _acknowledgedGalleryPosts,
    );
    // Real direct messages live under an accepted friend request and use the
    // chat repository. Existing local demo threads are never uploaded here.
    final delta = CommunityDelta(
      profile: changes.profile,
      upsertPosts: changes.upsertPosts,
      deletePostIds: changes.deletePostIds,
      upsertReplies: changes.upsertReplies,
      deleteReplies: changes.deleteReplies,
    );
    final state = readState();
    final stateJson = jsonEncode(state.toMap());
    final stateChanged = stateJson != _lastState;
    if (delta.isEmpty && !stateChanged) {
      _baseline = encoded;
      _forgetAcknowledgedPosts(encoded);
      return;
    }
    try {
      if (stateChanged) await gateway.saveState(uid, school.id, state);
      if (!delta.isEmpty) await gateway.applyDelta(school.id, delta, uid);
      _baseline = encoded;
      _lastState = stateJson;
      _forgetAcknowledgedPosts(encoded);
    } catch (_) {
      _reportOffline();
    }
  }

  void _forgetAcknowledgedPosts(String encoded) {
    if (_acknowledgedGalleryPosts.isEmpty) return;
    final snapshot = jsonDecode(encoded) as Map<String, dynamic>;
    for (final post in snapshot['posts'] as List) {
      _acknowledgedGalleryPosts.remove((post as Map)['id']);
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

  Future<void> dispose() async {
    _timer?.cancel();
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
