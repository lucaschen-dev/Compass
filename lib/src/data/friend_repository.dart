import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendRequestStatus { pending, accepted, declined, canceled }

class SchoolDirectoryMember {
  const SchoolDirectoryMember({required this.uid, required this.name});

  final String uid;
  final String name;
}

class SchoolFriendRequest {
  const SchoolFriendRequest({
    required this.senderId,
    required this.recipientId,
    required this.status,
    this.senderName,
    this.recipientName,
  });

  final String senderId;
  final String recipientId;
  final FriendRequestStatus status;
  final String? senderName;
  final String? recipientName;

  bool isIncoming(String uid) => recipientId == uid;

  String otherUid(String uid) => isIncoming(uid) ? senderId : recipientId;

  String? otherName(String uid) => isIncoming(uid) ? senderName : recipientName;

  factory SchoolFriendRequest.fromMap(Map<String, dynamic> data) {
    return SchoolFriendRequest(
      senderId: data['senderId'] as String,
      recipientId: data['recipientId'] as String,
      status: FriendRequestStatus.values.byName(data['status'] as String),
      senderName: data['senderName'] as String?,
      recipientName: data['recipientName'] as String?,
    );
  }
}

class FriendActionException implements Exception {
  const FriendActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class FriendRepository {
  String get uid;

  String get myCode;

  Stream<List<SchoolDirectoryMember>> watchDirectory();

  Stream<List<SchoolFriendRequest>> watchRequests();

  Future<void> publishProfile();

  Future<void> hideProfile();

  Future<void> sendRequest(String otherUid);

  Future<void> respondToRequest(String otherUid, {required bool accept});

  Future<void> cancelRequest(String otherUid);
}

class FirebaseFriendRepository implements FriendRepository {
  const FirebaseFriendRepository({
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

  @override
  String get myCode => uid;

  static final _validUid = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  DocumentReference<Map<String, dynamic>> get _school =>
      firestore.collection('schools').doc(schoolId);

  DocumentReference<Map<String, dynamic>> get _profile =>
      firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _directory =>
      _school.collection('directory');

  CollectionReference<Map<String, dynamic>> get _requests =>
      _school.collection('friendRequests');

  void _requireAccount() {
    if (auth.currentUser?.uid != uid) {
      throw const FriendActionException('Sign in again to use school friends.');
    }
  }

  List<String> _pair(String otherUid) {
    if (otherUid == uid) {
      throw const FriendActionException('This is your own Compass code.');
    }
    if (!_validUid.hasMatch(otherUid)) {
      throw const FriendActionException('Enter a valid Compass code.');
    }
    return [uid, otherUid]..sort();
  }

  Future<String> _profileName(Transaction transaction) async {
    final data = (await transaction.get(_profile)).data();
    final name = data?['name'];
    if (data?['schoolId'] != schoolId || name is! String) {
      throw const FriendActionException(
        'Complete your profile before using school friends.',
      );
    }
    return name;
  }

  @override
  Stream<List<SchoolDirectoryMember>> watchDirectory() async* {
    _requireAccount();
    yield* _directory.orderBy('name').snapshots().map((snapshot) {
      _requireAccount();
      return [
        for (final doc in snapshot.docs)
          SchoolDirectoryMember(
            uid: doc.id,
            name: doc.data()['name'] as String,
          ),
      ];
    });
  }

  @override
  Stream<List<SchoolFriendRequest>> watchRequests() async* {
    _requireAccount();
    yield* _requests.where('participants', arrayContains: uid).snapshots().map((
      snapshot,
    ) {
      _requireAccount();
      return [
        for (final doc in snapshot.docs)
          SchoolFriendRequest.fromMap(doc.data()),
      ];
    });
  }

  @override
  Future<void> publishProfile() {
    _requireAccount();
    return firestore.runTransaction((transaction) async {
      _requireAccount();
      final name = await _profileName(transaction);
      transaction.set(_directory.doc(uid), {'name': name});
    });
  }

  @override
  Future<void> hideProfile() {
    _requireAccount();
    return _directory.doc(uid).delete();
  }

  @override
  Future<void> sendRequest(String otherUid) {
    _requireAccount();
    final recipientId = otherUid.trim();
    final participants = _pair(recipientId);
    final ref = _requests.doc(participants.join(':'));
    return firestore.runTransaction((transaction) async {
      _requireAccount();
      final data = (await transaction.get(ref)).data();
      if (data != null) {
        final request = SchoolFriendRequest.fromMap(data);
        switch (request.status) {
          case FriendRequestStatus.pending:
            if (request.senderId == uid) return;
            throw const FriendActionException(
              'This person already sent you a friend request.',
            );
          case FriendRequestStatus.accepted:
            throw const FriendActionException('You are already friends.');
          case FriendRequestStatus.declined:
            throw const FriendActionException(
              'This friend request was declined.',
            );
          case FriendRequestStatus.canceled:
            break;
        }
      }
      final name = await _profileName(transaction);
      transaction.set(ref, {
        'participants': participants,
        'senderId': uid,
        'recipientId': recipientId,
        'senderName': name,
        'status': FriendRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> respondToRequest(String otherUid, {required bool accept}) {
    return _finishRequest(
      otherUid,
      accept ? FriendRequestStatus.accepted : FriendRequestStatus.declined,
    );
  }

  @override
  Future<void> cancelRequest(String otherUid) {
    return _finishRequest(otherUid, FriendRequestStatus.canceled);
  }

  Future<void> _finishRequest(String otherUid, FriendRequestStatus next) {
    _requireAccount();
    final ref = _requests.doc(_pair(otherUid).join(':'));
    return firestore.runTransaction((transaction) async {
      _requireAccount();
      final data = (await transaction.get(ref)).data();
      if (data == null) {
        throw const FriendActionException(
          'This friend request is no longer available.',
        );
      }
      final request = SchoolFriendRequest.fromMap(data);
      final actor = next == FriendRequestStatus.canceled
          ? request.senderId
          : request.recipientId;
      if (actor != uid) {
        throw const FriendActionException(
          'You cannot make this change to the friend request.',
        );
      }
      if (request.status == next) return;
      if (request.status != FriendRequestStatus.pending) {
        throw const FriendActionException(
          'This friend request is no longer pending.',
        );
      }
      transaction.update(ref, {
        if (next == FriendRequestStatus.accepted)
          'recipientName': await _profileName(transaction),
        'status': next.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
