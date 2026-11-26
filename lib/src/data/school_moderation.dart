import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Keep this baseline in sync with communityTextOk in firestore.rules.
final _abusiveText = RegExp(
  r'\b(kill\s+yourself|i\s+will\s+kill\s+you|fuck\s+you)\b',
  caseSensitive: false,
);

bool communityTextAllowed(String text) => !_abusiveText.hasMatch(text);

const communityTextWarning =
    'Remove threatening or abusive language before sending.';

enum ReportKind { post, comment, message }

enum ReportReason {
  harassment('Harassment or bullying'),
  unsafe('Threats or unsafe content'),
  privacy('Personal information or an image shared without permission'),
  inappropriate('Inappropriate content'),
  spam('Spam'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

class SchoolReportTarget {
  const SchoolReportTarget.post(this.contentId)
    : kind = ReportKind.post,
      parentId = '';

  const SchoolReportTarget.comment(this.parentId, this.contentId)
    : kind = ReportKind.comment;

  SchoolReportTarget.message(String uid, String peerId, this.contentId)
    : kind = ReportKind.message,
      parentId = ([uid, peerId]..sort()).join(':');

  final ReportKind kind;
  final String parentId, contentId;
}

class BlockedSchoolMember {
  const BlockedSchoolMember(this.uid, this.displayName);

  final String uid, displayName;
}

abstract class SchoolModeration extends ChangeNotifier {
  List<BlockedSchoolMember> get blockedPeople;
  bool get hasLoadError;
  bool get hasLoadedBlocks;
  bool isBlocked(String uid);
  void refreshBlocks();
  Future<void> block(String peerId, String displayName);
  Future<void> unblock(String peerId);
  Future<void> report(SchoolReportTarget target, ReportReason reason);
}

class FirebaseSchoolModeration extends SchoolModeration {
  FirebaseSchoolModeration({
    required this.firestore,
    required this.auth,
    required this.schoolId,
    required this.uid,
  }) {
    refreshBlocks();
  }

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final String schoolId, uid;
  final _blocked = <String, BlockedSchoolMember>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  List<BlockedSchoolMember> get blockedPeople => _blocked.values.toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

  @override
  bool hasLoadError = false;

  @override
  bool hasLoadedBlocks = false;

  @override
  bool isBlocked(String uid) => _blocked.containsKey(uid);

  DocumentReference<Map<String, dynamic>> get _school =>
      firestore.collection('schools').doc(schoolId);

  CollectionReference<Map<String, dynamic>> get _blockList => firestore
      .collection('users')
      .doc(uid)
      .collection('schools')
      .doc(schoolId)
      .collection('blocked');

  void _requireAccount() {
    if (auth.currentUser?.uid != uid) {
      throw StateError('Sign in again to use school safety controls.');
    }
  }

  @override
  void refreshBlocks() {
    unawaited(_subscription?.cancel());
    _subscription = _blockList.snapshots().listen(
      (snapshot) {
        if (auth.currentUser?.uid != uid) return;
        _blocked
          ..clear()
          ..addEntries(
            snapshot.docs.map(
              (doc) => MapEntry(
                doc.id,
                BlockedSchoolMember(
                  doc.id,
                  doc.data()['displayName'] as String? ?? 'School member',
                ),
              ),
            ),
          );
        hasLoadedBlocks = true;
        hasLoadError = false;
        notifyListeners();
      },
      onError: (Object error) {
        hasLoadError = true;
        notifyListeners();
      },
    );
  }

  @override
  Future<void> block(String peerId, String displayName) async {
    _requireAccount();
    await _blockList
        .doc(peerId)
        .set({
          'targetUid': peerId,
          'displayName': displayName.isEmpty ? 'School member' : displayName,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 18));
  }

  @override
  Future<void> unblock(String peerId) async {
    _requireAccount();
    await _blockList.doc(peerId).delete().timeout(const Duration(seconds: 18));
  }

  @override
  Future<void> report(SchoolReportTarget target, ReportReason reason) async {
    _requireAccount();
    final postId = target.kind == ReportKind.post
        ? target.contentId
        : target.parentId;
    final post = _school.collection('posts').doc(postId);
    final content = switch (target.kind) {
      ReportKind.post => post,
      ReportKind.comment => post.collection('replies').doc(target.contentId),
      ReportKind.message =>
        _school
            .collection('friendRequests')
            .doc(target.parentId)
            .collection('messages')
            .doc(target.contentId),
    };
    final report = _school.collection('moderationReports').doc();
    await firestore
        .runTransaction((transaction) async {
          _requireAccount();
          final data = (await transaction.get(content)).data();
          if (data == null) {
            throw StateError('This content is no longer available.');
          }
          final message = target.kind == ReportKind.message;
          transaction.set(report, {
            'kind': target.kind.name,
            'parentId': target.parentId,
            'contentId': target.contentId,
            'reason': reason.name,
            'reporterId': uid,
            'targetUid': data[message ? 'senderId' : 'authorId'],
            'title': target.kind == ReportKind.post ? data['title'] : '',
            'body': data[message ? 'text' : 'body'],
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
        })
        .timeout(const Duration(seconds: 18));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
