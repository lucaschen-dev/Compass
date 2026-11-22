import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../community_models.dart';
import 'repositories.dart';
import 'sync_codec.dart';
import 'user_state.dart';

class FirestoreGateway {
  FirestoreGateway(this.firestore, this.preferences, {FirebaseAuth? auth})
    : auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final SharedPreferencesAsync preferences;
  final FirebaseAuth auth;
  bool _catalogLoaded = false;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> stateRef(String uid, String schoolId) =>
      _user(uid).collection('schools').doc(schoolId);

  CollectionReference<Map<String, dynamic>> _posts(String schoolId) =>
      firestore.collection('schools').doc(schoolId).collection('posts');

  CollectionReference<Map<String, dynamic>> _threads(
    String schoolId,
    String uid,
  ) => stateRef(uid, schoolId).collection('threads');

  Future<List<Map<String, Object?>>> listSchools() async {
    if (_catalogLoaded) {
      final cached = await _cachedSchools();
      if (cached != null) return cached;
    }
    try {
      final snap = await firestore.collection('schools').get();
      final schools = [
        for (final doc in snap.docs)
          <String, Object?>{'id': doc.id, ...doc.data()},
      ];
      if (schools.isNotEmpty) {
        await preferences.setString(
          'compass.catalog.schools',
          jsonEncode(schools),
        );
        _catalogLoaded = true;
        return schools;
      }
    } catch (_) {}
    final cached = await _cachedSchools();
    if (cached != null) return cached;
    return LocalSchoolCatalogRepository().listSchools();
  }

  Future<List<Map<String, Object?>>?> _cachedSchools() async {
    final raw = await preferences.getString('compass.catalog.schools');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> publicProfile(String schoolId, String email) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _user(uid).get();
      final data = doc.data();
      if (data == null || data['schoolId'] != schoolId || data['email'] != email) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<UserSchoolState?> loadState(String uid, String schoolId) async {
    final doc = await stateRef(uid, schoolId).get();
    final data = doc.data();
    if (data == null) return null;
    return UserSchoolState.fromMap(data);
  }

  Future<void> saveState(String uid, String schoolId, UserSchoolState state) {
    final payload = state.toMap();
    if (containsForbiddenRemoteKeys(payload)) {
      throw StateError('Private state included a field that stays on the device.');
    }
    return stateRef(uid, schoolId).set({
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveProfile({
    required String uid,
    required String name,
    required int grade,
  }) => _user(uid).set({
    'name': name,
    'grade': grade,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<List<CommunityPost>> fetchPosts(String schoolId, String uid) async {
    final snap = await _posts(schoolId).get();
    final posts = <CommunityPost>[];
    final unnamed = <DocumentReference<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final replies = await doc.reference.collection('replies').get();
      if (data['anonymous'] != true &&
          data['authorId'] == uid &&
          savedAuthorName(data) == null) {
        unnamed.add(doc.reference);
      }
      for (final reply in replies.docs) {
        final replyData = reply.data();
        if (replyData['authorId'] == uid &&
            savedAuthorName(replyData) == null) {
          unnamed.add(reply.reference);
        }
      }
      posts.add(
        localPostFromRemote(
          {...data, 'id': doc.id},
          uid,
          replies: [
            for (final reply in replies.docs)
              localReplyFromRemote({...reply.data(), 'id': reply.id}, uid),
          ],
        ),
      );
    }
    if (unnamed.isNotEmpty) {
      unawaited(_backfillAuthorNames(schoolId, uid, unnamed));
    }
    return posts;
  }

  Future<String?> _verifiedAuthorName(String schoolId, String uid) async {
    if (auth.currentUser?.uid != uid) return null;
    try {
      final data = (await _user(uid).get()).data();
      final name = data?['name'];
      if (auth.currentUser?.uid == uid &&
          data?['schoolId'] == schoolId &&
          name is String &&
          name.trim().isNotEmpty) {
        return name;
      }
    } on FirebaseException {
      // Content still syncs without a name and can be repaired on refresh.
    }
    return null;
  }

  Future<void> _backfillAuthorNames(
    String schoolId,
    String uid,
    List<DocumentReference<Map<String, dynamic>>> unnamed,
  ) async {
    final name = await _verifiedAuthorName(schoolId, uid);
    if (name == null) return;
    for (final doc in unnamed) {
      if (auth.currentUser?.uid != uid) return;
      try {
        // Update only the name. Rules recheck authorship and anonymity if the
        // post was edited, and update cannot recreate a deleted document.
        await doc.update({'authorName': name});
      } on FirebaseException {
        // A later refresh can retry other legacy records.
      }
    }
  }

  Future<void> applyDelta(String schoolId, CommunityDelta delta, String uid) async {
    final profile = delta.profile;
    if (profile != null && profile.name.trim().length >= 2) {
      await saveProfile(uid: uid, name: profile.name.trim(), grade: profile.grade);
    }
    final authorName = delta.upsertReplies.isNotEmpty ||
            delta.upsertPosts.any((post) => !post.anonymous)
        ? await _verifiedAuthorName(schoolId, uid)
        : null;
    for (final post in delta.upsertPosts) {
      final payload = remotePostJson(post, uid, verifiedAuthorName: authorName);
      if (containsForbiddenRemoteKeys(payload)) continue;
      final doc = _posts(schoolId).doc(post.id);
      if (post.sharedGalleryMedia && post.photos.isEmpty) {
        // Offline caches keep only metadata for shared photo posts.
        // Merge metadata edits so a cached post cannot clear server media.
        await doc.set({
          ...payload,
          if (post.anonymous) 'authorName': FieldValue.delete(),
        }, SetOptions(merge: true));
      } else {
        await doc.set(payload);
      }
    }
    for (final id in delta.deletePostIds) {
      final replies = await _posts(schoolId).doc(id).collection('replies').get();
      for (final reply in replies.docs) {
        await reply.reference.delete();
      }
      await _posts(schoolId).doc(id).delete();
    }
    for (final change in delta.upsertReplies) {
      final payload = remoteReplyJson(
        change.reply,
        uid,
        verifiedAuthorName: authorName,
      );
      if (containsForbiddenRemoteKeys(payload)) continue;
      final post = _posts(schoolId).doc(change.postId);
      // Sample posts are local and do not have a Firestore parent.
      if (!(await post.get()).exists) continue;
      await post.collection('replies').doc(change.reply.id).set(payload);
    }
    for (final removal in delta.deleteReplies) {
      await _posts(schoolId)
          .doc(removal.postId)
          .collection('replies')
          .doc(removal.replyId)
          .delete();
    }
    for (final thread in delta.upsertThreads) {
      final payload = remoteThreadJson(thread);
      if (containsForbiddenRemoteKeys(payload)) continue;
      await _threads(schoolId, uid).doc(thread.id).set(payload);
    }
    for (final change in delta.upsertMessages) {
      final payload = remoteMessageJson(change.message, uid);
      if (containsForbiddenRemoteKeys(payload)) continue;
      await _threads(schoolId, uid)
          .doc(change.threadId)
          .collection('messages')
          .doc(change.message.id)
          .set(payload);
    }
  }

  Future<List<ChatThread>> fetchThreads(String schoolId, String uid) async {
    final snap = await _threads(schoolId, uid).get();
    return [
      for (final doc in snap.docs)
        localThreadFromRemote({...doc.data(), 'id': doc.id}),
    ];
  }

  Future<List<ChatMessage>> fetchMessages(
    String schoolId,
    String threadId,
    String uid,
  ) async {
    final snap = await _threads(schoolId, uid)
        .doc(threadId)
        .collection('messages')
        .get();
    return [
      for (final doc in snap.docs)
        localMessageFromRemote({...doc.data(), 'id': doc.id}, uid),
    ];
  }

  Stream<List<ChatMessage>> watchMessages(
    String schoolId,
    String threadId,
    String uid,
  ) => _threads(schoolId, uid)
      .doc(threadId)
      .collection('messages')
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs)
            localMessageFromRemote({...doc.data(), 'id': doc.id}, uid),
        ],
      );
}

class FirestoreSchoolCatalogRepository implements SchoolCatalogRepository {
  FirestoreSchoolCatalogRepository(this.gateway);
  final FirestoreGateway gateway;

  @override
  Future<List<Map<String, Object?>>> listSchools() => gateway.listSchools();

  @override
  Future<Map<String, Object?>?> getSchool(String schoolId) async {
    final schools = await listSchools();
    return schools.where((school) => school['id'] == schoolId).firstOrNull;
  }
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this.gateway);
  final FirestoreGateway gateway;

  @override
  Future<Map<String, Object?>?> publicProfile(String schoolId, String email) =>
      gateway.publicProfile(schoolId, email);
}
