import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'school_demo.dart';

String accountStoreKey(DemoSchool school) =>
    'compass.preview.${school.id}.accounts';
String schoolEmailDomain(DemoSchool school) => '${school.id}.example';

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
}

class LocalAccount {
  const LocalAccount({
    required this.email,
    required this.name,
    required this.grade,
    required this.salt,
    required this.passwordHash,
  });
  final String email;
  final String name;
  final int grade;
  final String salt;
  final String passwordHash;
  Map<String, Object> toJson() => {
    'email': email,
    'name': name,
    'grade': grade,
    'salt': salt,
    'passwordHash': passwordHash,
  };
  factory LocalAccount.fromJson(Map<String, dynamic> json) => LocalAccount(
    email: json['email'] as String,
    name: json['name'] as String,
    grade: json['grade'] as int,
    salt: json['salt'] as String,
    passwordHash: json['passwordHash'] as String,
  );
}

/// Device-local demonstration accounts. These do not verify school membership
/// or send mail. A real school must use a configured identity/email service.
class LocalAccounts {
  LocalAccounts(this.preferences, this.school, Object? stored) {
    try {
      if (stored is String) {
        for (final raw in jsonDecode(stored) as List) {
          final account = LocalAccount.fromJson(raw as Map<String, dynamic>);
          if (account.email.endsWith('@${schoolEmailDomain(school)}')) {
            _accounts[account.email] = account;
          }
        }
      }
    } catch (_) {
      _accounts.clear();
    }
  }
  final SharedPreferencesAsync preferences;
  final DemoSchool school;
  final _accounts = <String, LocalAccount>{};
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );
  LocalAccount? find(String email) => _accounts[email];

  String emailFor(String username) {
    final value = username.trim().toLowerCase();
    final suffix = '@${schoolEmailDomain(school)}';
    final local = value.endsWith(suffix)
        ? value.substring(0, value.length - suffix.length)
        : value;
    if (!RegExp(r'^[a-z0-9][a-z0-9._+\-]{0,63}$').hasMatch(local)) {
      throw const AccountException('Enter your school email username.');
    }
    return '$local$suffix';
  }

  Future<String> _hash(String password, List<int> salt) async {
    // Platform Web Crypto is used in browsers; only salted hashes are saved.
    // https://pub.dev/documentation/cryptography/latest/cryptography/Pbkdf2-class.html
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  Future<LocalAccount> create({
    required String username,
    required String password,
    required String name,
    required int grade,
  }) async {
    final email = emailFor(username);
    if (_accounts.containsKey(email)) {
      throw const AccountException('This demo account already exists. Log in.');
    }
    if (password.length < 10 || password.length > 128) {
      throw const AccountException(
        'Use a password between 10 and 128 characters.',
      );
    }
    if (name.trim().length < 2 || name.trim().length > 60) {
      throw const AccountException('Enter your full name (2–60 characters).');
    }
    if (grade < 9 || grade > 12) {
      throw const AccountException('Choose your grade.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final account = LocalAccount(
      email: email,
      name: name.trim(),
      grade: grade,
      salt: base64Encode(salt),
      passwordHash: await _hash(password, salt),
    );
    final next = {..._accounts, email: account};
    await preferences.setString(
      accountStoreKey(school),
      jsonEncode(next.values.map((a) => a.toJson()).toList()),
    );
    _accounts[email] = account;
    return account;
  }

  Future<LocalAccount> login(String username, String password) async {
    final email = emailFor(username);
    final account = _accounts[email];
    // Hash even an unknown username, keeping the two failure paths consistent.
    final hash = await _hash(
      password,
      account == null ? List.filled(16, 0) : base64Decode(account.salt),
    );
    var different = 0;
    final expected = account?.passwordHash ?? base64Encode(List.filled(32, 0));
    if (hash.length != expected.length) different = 1;
    for (var i = 0; i < min(hash.length, expected.length); i++) {
      different |= hash.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    if (account == null || different != 0) {
      throw const AccountException('Email or password is incorrect.');
    }
    return account;
  }
}
