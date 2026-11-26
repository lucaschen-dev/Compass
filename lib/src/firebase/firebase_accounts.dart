import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local_accounts.dart';
import '../school_demo.dart';

// App Store builds use Compass-owned email/password accounts. Google remains
// available on the web and other native platforms for existing customers.
bool get allowsGoogleSignIn =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS);

Future<User> signInToCompassWithPassword(
  FirebaseAuth auth,
  String email,
  String password,
) async {
  try {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AccountException('Could not log in. Please try again.');
    }
    return user;
  } on FirebaseAuthException catch (error) {
    throw _authError(error, creating: false);
  }
}

Future<Never> createCompassPasswordAccount(
  FirebaseAuth auth,
  String email,
  String password,
) async {
  validateNewPassword(password);
  final User? user;
  try {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    user = credential.user;
  } on FirebaseAuthException catch (error) {
    throw _authError(error, creating: true);
  }
  if (user == null) {
    throw const AccountException(
      'Could not save your account. Please try again.',
    );
  }
  try {
    await user.sendEmailVerification();
  } on FirebaseAuthException {
    // Keep verification available when the account was created but the email
    // request failed. The user can resend it without making another account.
    throw EmailVerificationRequired(email, sent: false);
  }
  throw EmailVerificationRequired(email, sent: true);
}

Future<void> sendCompassPasswordReset(FirebaseAuth auth, String email) async {
  try {
    await auth.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (error) {
    // Avoid exposing which addresses already have an account.
    if (error.code != 'user-not-found') {
      throw _authError(error, creating: false);
    }
  }
}

Future<User> verifyCompassEmail(FirebaseAuth auth) async {
  final user = auth.currentUser;
  final email = user?.email;
  if (user == null || email == null) {
    throw const AccountException('Sign in again to verify your email.');
  }
  try {
    await user.reload();
    final refreshed = auth.currentUser;
    if (refreshed == null || refreshed.uid != user.uid) {
      throw const AccountException('Sign in again to verify your email.');
    }
    if (!refreshed.emailVerified) {
      throw EmailVerificationRequired(email, sent: false);
    }
    await refreshed.getIdToken(true);
    return refreshed;
  } on FirebaseAuthException catch (error) {
    throw _authError(error, creating: false);
  }
}

Future<void> resendCompassVerification(FirebaseAuth auth) async {
  final user = auth.currentUser;
  if (user == null) {
    throw const AccountException('Sign in again to verify your email.');
  }
  try {
    await user.sendEmailVerification();
  } on FirebaseAuthException catch (error) {
    throw _authError(error, creating: false);
  }
}

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
  bool get canCreate => false;

  @override
  bool get isDemo => false;

  @override
  Future<void> resetPassword(String username) => resendVerification();

  @override
  Future<void> verifyEmail() => resendVerification();

  @override
  Future<void> resendVerification() async {
    throw const AccountException(
      'Could not reach Compass. Check your connection and try again.',
    );
  }

  @override
  bool get supportsGoogle => false;

  @override
  String? get displayName => null;

  @override
  Future<LocalAccount?> signInWithGoogle() async {
    throw const AccountException('Google sign-in is not available.');
  }

  @override
  Future<LocalAccount> finishVerifiedProfile({
    required String name,
    required int grade,
  }) async {
    throw const AccountException('Could not save your profile.');
  }

  @override
  Future<void> cancelEnrollment() async {}

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

  @override
  bool get canCreate => school.isRegistered;

  @override
  bool get isDemo => false;

  @override
  Future<void> resetPassword(String username) =>
      sendCompassPasswordReset(auth, emailFor(username));

  @override
  Future<void> verifyEmail() async {
    await verifyCompassEmail(auth);
  }

  @override
  Future<void> resendVerification() => resendCompassVerification(auth);

  @override
  bool get supportsGoogle => allowsGoogleSignIn;

  @override
  String? get displayName => auth.currentUser?.displayName;

  @override
  Future<void> cancelEnrollment() => auth.signOut();

  @override
  String emailFor(String username) => schoolEmailFor(school, username);

  @override
  LocalAccount? find(String sessionKey) {
    final cached = _memory[sessionKey];
    final user = auth.currentUser;
    if (cached == null || user == null || cached.uid != user.uid) return null;
    if (school.isRegistered && !_verifiedSchoolEmail(user)) return null;
    return cached;
  }

  @override
  Future<LocalAccount?> restore(String sessionKey) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) return null;
    if (school.isRegistered && !_verifiedSchoolEmail(user)) return null;
    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      if (auth.currentUser?.uid != user.uid) return null;
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
  Future<LocalAccount?> login(String username, String password) async {
    final email = emailFor(username);
    final user = await signInToCompassWithPassword(auth, email, password);
    return _loadOrEnroll(user);
  }

  Future<LocalAccount?> _loadOrEnroll(User user) async {
    if (school.isRegistered && !_verifiedSchoolEmail(user)) {
      if (_isSchoolEmail(user.email)) {
        throw EmailVerificationRequired(user.email!, sent: false);
      }
      await auth.signOut();
      throw AccountException(
        'Sign in with a verified @${schoolEmailDomain(school)} account.',
      );
    }
    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) {
        if (school.isRegistered) return null;
        await auth.signOut();
        throw const AccountException('This school is closed to new accounts.');
      }
      final account = _accountFrom(user, data);
      if (account == null) {
        await auth.signOut();
        throw const AccountException(
          'This email belongs to a different school.',
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
  Future<LocalAccount> create({
    required String username,
    required String password,
    required String name,
    required int grade,
  }) async {
    if (!canCreate) {
      throw const AccountException('This school is closed to new accounts.');
    }
    validateNewAccount(password: password, name: name, grade: grade);
    final email = emailFor(username);
    return createCompassPasswordAccount(auth, email, password);
  }

  @override
  Future<LocalAccount?> signInWithGoogle() async {
    if (!supportsGoogle) {
      throw const AccountException('Google sign-in is not available.');
    }
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
      return await _loadOrEnroll(user);
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
  Future<LocalAccount> finishVerifiedProfile({
    required String name,
    required int grade,
  }) async {
    final user = await verifyCompassEmail(auth);
    final email = user.email;
    if (email == null) {
      throw const AccountException('Verify your school email to continue.');
    }
    if (!school.isRegistered) {
      throw const AccountException('This school is closed to new accounts.');
    }
    if (!_verifiedSchoolEmail(user)) {
      throw AccountException(
        'Sign in with a verified @${schoolEmailDomain(school)} account.',
      );
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
      final reference = firestore.collection('users').doc(user.uid);
      final saved = await firestore.runTransaction((transaction) async {
        final existing = (await transaction.get(reference)).data();
        if (existing != null) {
          final account = _accountFrom(user, existing);
          if (account != null) return account;
          throw const AccountException(
            'This email belongs to a different school.',
          );
        }
        transaction.set(reference, {
          ...account.toPublicProfileJson(schoolId: school.id),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return account;
      });
      await _remember(saved);
      return saved;
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
    if (school.isRegistered) {
      if (!_verifiedSchoolEmail(user) || !_isSchoolEmail(email)) return null;
    } else {
      // A legacy school's membership belongs to the existing UID, including
      // members whose Google email was outside the former school's domain.
      if (email.toLowerCase() != user.email?.toLowerCase()) return null;
    }
    final grade = data['grade'];
    return LocalAccount(
      email: email,
      name: data['name'] as String? ?? user.displayName ?? 'Student',
      grade: grade is num ? grade.toInt().clamp(9, 12) : 11,
      uid: user.uid,
    );
  }

  bool _verifiedSchoolEmail(User user) =>
      user.emailVerified && _isSchoolEmail(user.email);

  bool _isSchoolEmail(String? email) {
    final parts = email?.split('@');
    return parts != null &&
        parts.length == 2 &&
        parts.first.isNotEmpty &&
        parts.last.toLowerCase() == schoolEmailDomain(school);
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
      final user = auth.currentUser;
      if (user == null || user.uid != uid) return null;
      final account = _accountFrom(user, data);
      if (account == null) return null;
      _memory[uid] = account;
      _memory[account.email] = account;
      return account;
    } catch (_) {
      return null;
    }
  }
}

AccountException _authError(
  FirebaseAuthException error, {
  required bool creating,
}) {
  switch (error.code) {
    case 'email-already-in-use':
      return const AccountException(
        'Sign in or set a Compass password with the password reset link.',
      );
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
