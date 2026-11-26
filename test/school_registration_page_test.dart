import 'package:compass_flutter/src/data/school_registry.dart';
import 'package:compass_flutter/src/existing_account_sign_in.dart';
import 'package:compass_flutter/src/firebase/firebase_accounts.dart';
import 'package:compass_flutter/src/local_accounts.dart';
import 'package:compass_flutter/src/preview_theme.dart';
import 'package:compass_flutter/src/school_registration_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('Apple platforms use Compass credentials for native sign-in', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(allowsGoogleSignIn, kIsWeb);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(allowsGoogleSignIn, isTrue);
  });

  testWidgets('password account creation waits for email verification', (
    tester,
  ) async {
    var verified = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => openExistingAccountSignIn(
                  context,
                  onPassword: (_, _) async {},
                  onCreate: (email, _) async =>
                      throw EmailVerificationRequired(email, sent: true),
                  onVerify: () async {
                    verified = true;
                  },
                ),
                child: const Text('Open sign-in'),
              ),
            );
          },
        ),
      ),
    );
    await _tap(tester, find.text('Open sign-in'));
    expect(find.text('Continue with Google'), findsNothing);
    await _tap(tester, find.text('Create Compass account'));
    await _enter(tester, 'Email address', 'office@harbor.edu');
    await _enter(tester, 'Password', 'example account password');
    await _tap(tester, find.text('Create account'));
    expect(
      find.text('Verification email sent to office@harbor.edu.'),
      findsOne,
    );
    expect(verified, isFalse);
    await _tap(tester, find.text('I verified my email'));
    expect(verified, isTrue);
    expect(find.text('Open sign-in'), findsOne);
  });

  testWidgets('school application requires a same-domain contact email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drafts = <SchoolApplicationDraft>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: localCompassTheme(Brightness.dark),
        home: SchoolRegistrationPage(
          loadApplication: () async => null,
          submit: (draft) async => drafts.add(draft),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _enter(tester, 'School name', '  Harbor Academy  ');
    await _enter(tester, 'School email domain', 'HARBOR.EDU');
    await _enter(tester, 'School contact email', 'office@other.edu');
    await _enter(tester, 'School color (optional)', '164a73');
    await _enter(tester, 'Your full name', 'Casey Morgan');
    await _enter(tester, 'Your role at the school', 'Dean');
    await _tap(tester, find.text('Submit for review'));

    expect(drafts, isEmpty);
    expect(find.text('Use an email from the school domain above.'), findsOne);
    await _enter(tester, 'School contact email', 'Office@HARBOR.EDU');
    await _tap(tester, find.text('Submit for review'));

    expect(drafts.single.schoolName, 'Harbor Academy');
    expect(drafts.single.emailDomain, 'harbor.edu');
    expect(drafts.single.contactEmail, 'office@harbor.edu');
    expect(drafts.single.color, '#164A73');
    expect(drafts.single.applicantRole, 'Dean');
    expect(find.text('Application submitted'), findsOne);
    expect(find.textContaining('after approval'), findsOne);
    expect(find.text('School name'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing application displays its review status', (
    tester,
  ) async {
    final app = SchoolRegistrationPage(
      loadApplication: () async => const SchoolApplication(
        draft: SchoolApplicationDraft(
          schoolName: 'Harbor Academy',
          applicantName: 'Casey Morgan',
          applicantRole: 'Dean',
          contactEmail: 'office@harbor.edu',
          emailDomain: 'harbor.edu',
        ),
        applicantEmail: 'casey@harbor.edu',
        status: SchoolApplicationStatus.approved,
      ),
      submit: (_) async =>
          throw StateError('Existing application submitted again'),
    );
    await tester.pumpWidget(MaterialApp(home: app));
    await tester.pumpAndSettle();

    expect(find.text('Application approved'), findsOne);
    expect(find.text('Harbor Academy'), findsOne);
    expect(find.text('Submit for review'), findsNothing);
  });

  for (final google in [false, true]) {
    testWidgets(
      'existing account sign-in returns success (${google ? 'Google' : 'password'})',
      (tester) async {
        bool? result;
        (String, String)? credentials;
        var googleCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await openExistingAccountSignIn(
                        context,
                        onPassword: (email, password) async =>
                            credentials = (email, password),
                        onGoogle: () async => googleCalls++,
                      ),
                  child: const Text('Open sign-in'),
                ),
              ),
            ),
          ),
        );
        await _tap(tester, find.text('Open sign-in'));

        if (google) {
          await _tap(tester, find.text('Continue with Google'));
          expect(googleCalls, 1);
          expect(credentials, isNull);
        } else {
          await _enter(tester, 'Email address', 'casey@harbor.edu');
          await _enter(tester, 'Password', 'test password ');
          await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
          expect(credentials, ('casey@harbor.edu', 'test password '));
          expect(googleCalls, 0);
        }
        expect(result, isTrue);
      },
    );
  }
}
