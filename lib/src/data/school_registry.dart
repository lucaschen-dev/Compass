import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const schoolRegistrationDefaultColor = '#244A73';

final _schoolDomain = RegExp(
  r'^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
);
final _contactAddress = RegExp(r'^[^\s@<>]+@[a-zA-Z0-9.-]+$');
final _schoolHexColor = RegExp(r'^#[A-Fa-f0-9]{6}$');

class RegisteredSchool {
  const RegisteredSchool({
    required this.id,
    required this.name,
    required this.emailDomain,
    this.location = '',
    this.color = schoolRegistrationDefaultColor,
  });

  final String id;
  final String name;
  final String emailDomain;
  final String location;
  final String color;

  static RegisteredSchool? _parse(String id, Map<String, dynamic>? data) {
    if (data == null ||
        (data['status'] != 'approved' && data['status'] != 'review')) {
      return null;
    }
    final name = data['name'];
    final domain = data['emailDomain'];
    if (name is! String ||
        name.trim().isEmpty ||
        domain is! String ||
        domain.length > 253 ||
        !_schoolDomain.hasMatch(domain)) {
      return null;
    }
    final location = data['location'];
    final color = data['color'];
    return RegisteredSchool(
      id: id,
      name: name,
      emailDomain: domain,
      location: location is String ? location : '',
      color: color is String && _schoolHexColor.hasMatch(color)
          ? color
          : schoolRegistrationDefaultColor,
    );
  }
}

abstract interface class SchoolRegistry {
  Future<List<RegisteredSchool>> listApprovedSchools();
  Future<RegisteredSchool?> getApprovedSchool(String id);
}

class FirebaseSchoolRegistry implements SchoolRegistry {
  const FirebaseSchoolRegistry({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _schools =>
      firestore.collection('schoolRegistry');

  @override
  Future<List<RegisteredSchool>> listApprovedSchools() async {
    final snapshot = await _schools
        .where('status', isEqualTo: 'approved')
        .get();
    final schools = <RegisteredSchool>[
      for (final doc in snapshot.docs)
        ?RegisteredSchool._parse(doc.id, doc.data()),
    ];
    schools.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return schools;
  }

  @override
  Future<RegisteredSchool?> getApprovedSchool(String id) async {
    try {
      final doc = await _schools.doc(id).get();
      return RegisteredSchool._parse(doc.id, doc.data());
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }
}

enum SchoolApplicationStatus { pending, approved, rejected }

class SchoolApplicationDraft {
  const SchoolApplicationDraft({
    required this.schoolName,
    required this.applicantName,
    required this.applicantRole,
    required this.contactEmail,
    required this.emailDomain,
    this.location = '',
    this.color = schoolRegistrationDefaultColor,
  });

  final String schoolName;
  final String applicantName;
  final String applicantRole;
  final String contactEmail;
  final String emailDomain;
  final String location;
  final String color;

  Map<String, Object> _checkedData() {
    final name = schoolName.trim();
    final representative = applicantName.trim();
    final role = applicantRole.trim();
    final contact = contactEmail.trim();
    final domain = emailDomain.trim().toLowerCase();
    final place = location.trim();
    final accent = color.trim().toUpperCase();

    if (name.length < 2 ||
        name.length > 120 ||
        representative.length < 2 ||
        representative.length > 80 ||
        role.length < 2 ||
        role.length > 80 ||
        place.length > 120) {
      throw const SchoolRegistrationException(
        'Check the school name, your name and position, and the location.',
      );
    }
    if (domain.length > 253 || !_schoolDomain.hasMatch(domain)) {
      throw const SchoolRegistrationException(
        'Enter the school email domain, such as school.edu.',
      );
    }
    if (contact.length > 254 ||
        !_contactAddress.hasMatch(contact) ||
        contact.split('@').last.toLowerCase() != domain) {
      throw const SchoolRegistrationException(
        'Enter a contact email at the school email domain.',
      );
    }
    if (!_schoolHexColor.hasMatch(accent)) {
      throw const SchoolRegistrationException('Enter a valid school color.');
    }

    return {
      'schoolName': name,
      'applicantName': representative,
      'applicantRole': role,
      'contactEmail': contact,
      'emailDomain': domain,
      'location': place,
      'color': accent,
    };
  }
}

class SchoolApplication {
  const SchoolApplication({
    required this.draft,
    required this.applicantEmail,
    required this.status,
    this.submittedAt,
  });

  final SchoolApplicationDraft draft;
  final String applicantEmail;
  final SchoolApplicationStatus status;
  final DateTime? submittedAt;

  factory SchoolApplication._fromData(Map<String, dynamic> data) {
    final submittedAt = data['submittedAt'];
    return SchoolApplication(
      draft: SchoolApplicationDraft(
        schoolName: data['schoolName'] as String,
        applicantName: data['applicantName'] as String,
        applicantRole: data['applicantRole'] as String,
        contactEmail: data['contactEmail'] as String,
        emailDomain: data['emailDomain'] as String,
        location: data['location'] as String? ?? '',
        color: data['color'] as String? ?? schoolRegistrationDefaultColor,
      ),
      applicantEmail: data['applicantEmail'] as String,
      status: switch (data['status']) {
        'approved' => SchoolApplicationStatus.approved,
        'rejected' => SchoolApplicationStatus.rejected,
        _ => SchoolApplicationStatus.pending,
      },
      submittedAt: submittedAt is Timestamp ? submittedAt.toDate() : null,
    );
  }
}

class SchoolRegistrationException implements Exception {
  const SchoolRegistrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SchoolRegistrationRepository {
  Future<SchoolApplication?> loadMyApplication();
  Future<void> submitApplication(SchoolApplicationDraft draft);
}

class FirebaseSchoolRegistrationRepository
    implements SchoolRegistrationRepository {
  const FirebaseSchoolRegistrationRepository({
    required this.firestore,
    required this.auth,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  DocumentReference<Map<String, dynamic>> _application(String uid) =>
      firestore.collection('schoolApplications').doc(uid);

  User _currentUser() {
    final user = auth.currentUser;
    if (user == null) {
      throw const SchoolRegistrationException('Sign in to register a school.');
    }
    return user;
  }

  @override
  Future<SchoolApplication?> loadMyApplication() async {
    final user = _currentUser();
    final doc = await _application(user.uid).get();
    final data = doc.data();
    return data == null ? null : SchoolApplication._fromData(data);
  }

  @override
  Future<void> submitApplication(SchoolApplicationDraft draft) async {
    final user = _currentUser();
    final email = user.email;
    final token = await user.getIdTokenResult();
    final fields = draft._checkedData();
    final canApply =
        token.signInProvider == 'google.com' ||
        (token.signInProvider == 'password' &&
            email?.toLowerCase() == fields['contactEmail']);
    if (email == null ||
        !user.emailVerified ||
        !canApply ||
        auth.currentUser?.uid != user.uid) {
      throw const SchoolRegistrationException(
        'Use a verified account to register a school. Compass accounts must match the school contact email.',
      );
    }

    final reference = _application(user.uid);
    await firestore.runTransaction((transaction) async {
      if ((await transaction.get(reference)).exists) {
        throw const SchoolRegistrationException(
          'This account already has a school registration application.',
        );
      }
      transaction.set(reference, {
        ...fields,
        'applicantEmail': email,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
