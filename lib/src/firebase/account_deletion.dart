import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const deletionReceiptKey = 'compass.deletion.receipt';

class FirebaseAccountDeletion {
  FirebaseAccountDeletion({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  User get _user =>
      auth.currentUser ??
      (throw FirebaseAuthException(code: 'user-token-expired'));

  bool get canVerifyWithGoogle =>
      kIsWeb &&
      _user.providerData.any((provider) => provider.providerId == 'google.com');

  bool get canVerifyWithPassword =>
      _user.providerData.any((provider) => provider.providerId == 'password');

  Future<bool> needsVerification() async {
    final signIn = (await _user.getIdTokenResult()).authTime;
    return signIn == null ||
        DateTime.now().difference(signIn) >= const Duration(minutes: 4);
  }

  Future<void> verify({String? password}) async {
    final user = _user;
    if (password != null) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (canVerifyWithGoogle) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.getIdToken(true);
  }

  Future<String> request() async {
    final uid = _user.uid;
    final job = firestore.collection('accountDeletionRequests').doc(uid);
    final receipts = firestore.collection('accountDeletionReceipts');
    final random = Random.secure();
    final id = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return firestore.runTransaction((transaction) async {
      final previous = await transaction.get(job);
      if (previous.data() case {'receipt': final String receipt}) {
        return receipt;
      }
      if (auth.currentUser?.uid != uid) {
        throw FirebaseAuthException(code: 'user-token-expired');
      }
      transaction.set(job, {
        'status': 'pending',
        'receipt': id,
        'requestedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(receipts.doc(id), {'status': 'pending'});
      return id;
    });
  }

  Stream<String?> track(String receipt) => firestore
      .collection('accountDeletionReceipts')
      .doc(receipt)
      .snapshots()
      .map((event) => event.data()?['status'] as String?);
}
