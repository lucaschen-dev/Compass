import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local_accounts.dart';
import '../school_demo.dart';

class UnavailableAccounts implements SchoolAccounts {
  UnavailableAccounts(this.school);
  final DemoSchool school;

  @override
  String emailFor(String username) => schoolEmailFor(school, username);

  @override
  LocalAccount? find(String sessionKey) => null;

  @override
  Future<LocalAccount?> restore(String sessionKey) async => null;

  @override
  bool get supportsGoogle => false;

  @override
  String? get googleDisplayName => null;

  @override
  Future<LocalAccount?> signInWithGoogle() async {
    throw const AccountException('Google sign-in is not available.');
  }

  @override
  Future<LocalAccount> finishGoogleProfile({
    required String name,
    required int grade,
  }) async {
    throw const AccountException('Google sign-in is not available.');
  }

  @override
  Future<void> cancelGoogle() async {}

  @override
  Future<LocalAccount> login(String username, String password) async {
    emailFor(username);
    throw const AccountException(
      'Could not reach Compass. Check your connection and try again.',
    );
  }

  @override
  Future<LocalAccount> create({
    required String username,
    required String password,
    required String name,
    required int grade,
  }) async {
    emailFor(username);
    validateNewAccount(password: password, name: name, grade: grade);
    throw const AccountException(
      'Could not save your account. Please try again.',
    );
  }
}

class FirebaseSchoolAccounts implements SchoolAccounts {
  FirebaseSchoolAccounts({
    required this.school,
    required this.preferences,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance;

  final DemoSchool school;
  final SharedPreferencesAsync preferences;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final _memory = <String, LocalAccount>{};
  String? _googleName;

  @override
  bool get supportsGoogle => true;

  @override
  String? get googleDisplayName => _googleName;

  @override
  Future<void> cancelGoogle() => auth.signOut();

  @override
  String emailFor(String username) => schoolEmailFor(school, username);

  @override
  LocalAccount? find(String sessionKey) {
    final cached = _memory[sessionKey];
    if (cached == null) return null;
    if (!cached.email.endsWith('@${schoolEmailDomain(school)}')) return null;
    return cached;
  }

  @override
  Future<LocalAccount?> restore(String sessionKey) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) return null;
    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final account = _accountFrom(user, data);
        if (account == null) return null;
        await _remember(account);
        return account;
      }
    } catch (_) {
      return _cached(user.uid);
    }
    return _cached(user.uid);
  }

  @override
  Future<LocalAccount> login(String username, String password) async {
    final email = emailFor(username);
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AccountException('Could not log in. Please try again.');
      }
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) {
        throw const AccountException(
          'This account has no Compass profile. Use First login.',
        );
      }
      final account = _accountFrom(user, data);
      if (account == null) {
        throw const AccountException('This email belongs to a different school.');
      }
      await _remember(account);
      return account;
    } on AccountException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _authError(error, creating: false);
    } on FirebaseException {
      throw const AccountException(
        'Could not reach Compass. Check your connection and try again.',
      );
    }
  }

  @override
  Future<LocalAccount> create({
    required String username,
    required String password,
    required String name,
    required int grade,
  }) async {
    final email = emailFor(username);
    validateNewAccount(password: password, name: name, grade: grade);
    User? user;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = credential.user;
      if (user == null) {
        throw const AccountException(
          'Could not save your account. Please try again.',
        );
      }
      final account = LocalAccount(
        email: email,
        name: name.trim(),
        grade: grade,
        uid: user.uid,
      );
      await user.updateDisplayName(account.name);
      await firestore.collection('users').doc(user.uid).set({
        'email': account.email,
        'name': account.name,
        'grade': account.grade,
        'schoolId': school.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _remember(account);
      return account;
    } on AccountException {
      await _discard(user);
      rethrow;
    } on FirebaseAuthException catch (error) {
      await _discard(user);
      throw _authError(error, creating: true);
    } on FirebaseException {
      await _discard(user);
      throw const AccountException(
        'Could not save your account. Please try again.',
      );
    }
  }

  @override
  Future<LocalAccount?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      final credential = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      final user = credential.user;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        throw const AccountException(
          'Google did not share an email address. Try another account.',
        );
      }
      _googleName = user.displayName;
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return null;
      final account = _accountFrom(user, data);
      if (account == null) {
        await auth.signOut();
        throw const AccountException(
          'This Google account is already used at the other school.',
        );
      }
      await _remember(account);
      return account;
    } on AccountException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _authError(error, creating: false);
    } on FirebaseException {
      throw const AccountException(
        'Could not reach Compass. Check your connection and try again.',
      );
    }
  }

  @override
  Future<LocalAccount> finishGoogleProfile({
    required String name,
    required int grade,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AccountException('Google sign-in is not available.');
    }
    if (name.trim().length < 2 || name.trim().length > 60) {
      throw const AccountException('Enter your full name (2–60 characters).');
    }
    if (grade < 9 || grade > 12) {
      throw const AccountException('Choose your grade.');
    }
    final account = LocalAccount(
      email: email,
      name: name.trim(),
      grade: grade,
      uid: user.uid,
    );
    try {
      await user.updateDisplayName(account.name);
      await firestore.collection('users').doc(user.uid).set({
        'email': account.email,
        'name': account.name,
        'grade': account.grade,
        'schoolId': school.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _remember(account);
      return account;
    } on FirebaseAuthException catch (error) {
      throw _authError(error, creating: true);
    } on FirebaseException {
      throw const AccountException(
        'Could not save your account. Please try again.',
      );
    }
  }

  LocalAccount? _accountFrom(User user, Map<String, dynamic> data) {
    final schoolId = data['schoolId'] as String? ?? '';
    final email = data['email'] as String? ?? user.email ?? '';
    if (schoolId != school.id) return null;
    final schoolEmail = email.endsWith('@${schoolEmailDomain(school)}');
    final google = user.providerData.any((info) => info.providerId == 'google.com');
    if (!schoolEmail && !google) return null;
    final grade = data['grade'];
    return LocalAccount(
      email: email,
      name: data['name'] as String? ?? user.displayName ?? 'Student',
      grade: grade is num ? grade.toInt().clamp(9, 12) : 11,
      uid: user.uid,
    );
  }

  Future<void> _remember(LocalAccount account) async {
    final uid = account.uid;
    if (uid == null) return;
    _memory[uid] = account;
    _memory[account.email] = account;
    await preferences.setString(
      'compass.auth.profile.$uid',
      jsonEncode({
        ...account.toPublicProfileJson(schoolId: school.id),
        'uid': uid,
      }),
    );
  }

  Future<LocalAccount?> _cached(String uid) async {
    final raw = await preferences.getString('compass.auth.profile.$uid');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schoolId'] != school.id) return null;
      final account = LocalAccount(
        email: data['email'] as String,
        name: data['name'] as String,
        grade: (data['grade'] as num).toInt(),
        uid: uid,
      );
      _memory[uid] = account;
      _memory[account.email] = account;
      return account;
    } catch (_) {
      return null;
    }
  }

  Future<void> _discard(User? user) async {
    try {
      await user?.delete();
    } catch (_) {}
  }
}

AccountException _authError(FirebaseAuthException error, {required bool creating}) {
  switch (error.code) {
    case 'email-already-in-use':
      return const AccountException('This demo account already exists. Log in.');
    case 'invalid-email':
      return const AccountException('Enter your school email username.');
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
      return const AccountException('Email or password is incorrect.');
    case 'weak-password':
      return const AccountException(
        'Use a password between 10 and 128 characters.',
      );
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
    case 'web-context-cancelled':
    case 'user-cancelled':
      return const AccountException('Google sign-in was canceled.');
    case 'account-exists-with-different-credential':
      return const AccountException(
        'This email already uses a password. Log in with email instead.',
      );
    case 'operation-not-allowed':
      return const AccountException(
        'Email sign-in is not turned on for this Compass project yet.',
      );
    case 'network-request-failed':
      return const AccountException(
        'Could not reach Compass. Check your connection and try again.',
      );
    case 'too-many-requests':
      return const AccountException(
        'Too many attempts. Wait a moment and try again.',
      );
    default:
      return AccountException(
        creating
            ? 'Could not save your account. Please try again.'
            : 'Could not log in. Please try again.',
      );
  }
}
