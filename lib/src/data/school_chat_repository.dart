import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'school_moderation.dart';

const schoolChatMessageLimit = 4000;
const schoolChatMessagePageSize = 50;

class SchoolChatMessage {
  const SchoolChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id, senderId, text;
  final DateTime createdAt;
}

class SchoolChatActionException implements Exception {
  const SchoolChatActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SchoolChatRepository {
  String get uid;

  String createMessageId();

  Stream<List<SchoolChatMessage>> watchMessages(String friendUid);

  Future<List<SchoolChatMessage>> loadOlderMessages(
    String friendUid,
    SchoolChatMessage before,
  );

  Future<void> sendMessage(
    String friendUid, {
    required String messageId,
    required String text,
  });
}

class FirebaseSchoolChatRepository implements SchoolChatRepository {
  const FirebaseSchoolChatRepository({
    required this.firestore,
    required this.auth,
    required this.schoolId,
    required this.uid,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final String schoolId;

  @override
  final String uid;

  static final _validUid = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _validMessageId = RegExp(r'^[A-Za-z0-9]{20}$');

  CollectionReference<Map<String, dynamic>> get _friendRequests => firestore
      .collection('schools')
      .doc(schoolId)
      .collection('friendRequests');

  void _requireAccount() {
    if (auth.currentUser?.uid != uid) {
      throw const SchoolChatActionException('Sign in again to open chat.');
    }
  }

  CollectionReference<Map<String, dynamic>> _messages(String friendUid) {
    if (uid == friendUid || !_validUid.hasMatch(friendUid)) {
      throw const SchoolChatActionException('Choose an accepted friend.');
    }
    final participants = [uid, friendUid]..sort();
    return _friendRequests.doc(participants.join(':')).collection('messages');
  }

  Query<Map<String, dynamic>> _history(String friendUid) =>
      _messages(friendUid)
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true);

  List<SchoolChatMessage> _readPage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _requireAccount();
    return [
      for (final doc in snapshot.docs.reversed)
        if (doc.data() case {
          'senderId': final String senderId,
          'text': final String text,
          'createdAt': final Timestamp createdAt,
        })
          SchoolChatMessage(
            id: doc.id,
            senderId: senderId,
            text: text,
            createdAt: createdAt.toDate(),
          ),
    ];
  }

  @override
  String createMessageId() => _friendRequests.doc().id;

  @override
  Stream<List<SchoolChatMessage>> watchMessages(String friendUid) async* {
    _requireAccount();
    yield* _history(friendUid)
        .limit(schoolChatMessagePageSize)
        .snapshots()
        .map(_readPage);
  }

  @override
  Future<List<SchoolChatMessage>> loadOlderMessages(
    String friendUid,
    SchoolChatMessage before,
  ) async {
    _requireAccount();
    final page = await _history(friendUid)
        .startAfter([Timestamp.fromDate(before.createdAt), before.id])
        .limit(schoolChatMessagePageSize)
        .get(const GetOptions(source: Source.server));
    return _readPage(page);
  }

  @override
  Future<void> sendMessage(
    String friendUid, {
    required String messageId,
    required String text,
  }) async {
    _requireAccount();
    final body = text.trim();
    if (body.isEmpty || body.length > schoolChatMessageLimit) {
      throw const SchoolChatActionException(
        'Enter a message with up to $schoolChatMessageLimit characters.',
      );
    }
    if (!communityTextAllowed(body)) {
      throw const SchoolChatActionException(communityTextWarning);
    }
    if (!_validMessageId.hasMatch(messageId)) {
      throw const SchoolChatActionException(
        'Start a new message and try again.',
      );
    }

    final ref = _messages(friendUid).doc('$uid:$messageId');
    // Users can retry when the acknowledgement is lost. Read the same document
    // first so the retry cannot overwrite a delivered message or add a duplicate.
    try {
      await firestore.runTransaction((transaction) async {
        _requireAccount();
        final sent = (await transaction.get(ref)).data();
        if (sent != null) {
          if (sent['senderId'] == uid && sent['text'] == body) return;
          throw const SchoolChatActionException(
            'This message was already sent. Start a new message.',
          );
        }
        transaction.set(ref, {
          'senderId': uid,
          'text': body,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const SchoolChatActionException(
          'Messaging is unavailable with this person.',
        );
      }
      rethrow;
    }
  }
}
