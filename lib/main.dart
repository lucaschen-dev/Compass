import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/account_deletion_ui.dart';
import 'src/compass_welcome.dart';
import 'src/calendar_storage.dart';
import 'src/app_ui.dart';
import 'src/local_accounts.dart';
import 'src/community_models.dart';
import 'src/mac_window_layout.dart';
import 'src/school_auth_page.dart';
import 'src/preview_shell.dart';
import 'src/preview_theme.dart';
import 'src/data/firestore_repositories.dart';
import 'src/data/school_registry.dart';
import 'src/data/sync_codec.dart';
import 'src/data/user_state.dart';
import 'src/demo_activities.dart';
import 'src/existing_account_sign_in.dart';
import 'src/live_calendar_service.dart';
import 'src/firebase/account_deletion.dart';
import 'src/firebase/compass_remote.dart';
import 'src/firebase/compass_scope.dart';
import 'src/firebase/firebase_accounts.dart';
import 'src/firebase/firebase_bootstrap.dart';
import 'src/firebase/firebase_test_env.dart';
import 'src/recommendations.dart';
import 'src/school_calendar_data.dart';
import 'src/school_demo.dart';
import 'src/school_registration_page.dart';

const _selectedSchoolKey = 'compass.preview.selectedSchool';

String _cultureReadKey(DemoSchool school, String id) =>
    'compass.preview.${school.id}.culture.read.$id';

String _legacyCultureReadKey(String id) => 'compass.preview.culture.read.$id';

String _friendKey(DemoSchool school, LocalAccount account) =>
    'compass.preview.${school.id}.friends.${Uri.encodeComponent(account.sessionKey)}';

String _ucInterestKey(DemoSchool school) =>
    'compass.preview.${school.id}.ucInterest';

String _requirementCompletedKey(DemoSchool school, String requirementId) =>
    'compass.preview.${school.id}.req.completed.$requirementId';

Iterable<String> _requirementIdsFor(DemoSchool school) => {
  for (final requirement in school.graduationRequirements) requirement.id,
  for (final requirement in school.ucRequirements) requirement.id,
};

DemoSchool _schoolFromRegistry(RegisteredSchool school) => DemoSchool(
  id: school.id,
  name: school.name,
  location: school.location,
  initials: school.name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase(),
  emailDomain: school.emailDomain,
  brandColor: int.tryParse(school.color.replaceFirst('#', ''), radix: 16),
  student: const DemoPerson(
    id: 'me',
    name: 'Student',
    grade: 9,
    bio: '',
    interests: [],
  ),
  classmates: const [],
  announcements: const [],
  conversations: const [],
  guide: const [],
  courses: const [],
  graduationRequirements: const [],
  ucRequirements: const [],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  final preferences = SharedPreferencesAsync();
  Map<String, Object?> saved = {};
  try {
    final all = await preferences.getAll();
    saved = {
      for (final entry in all.entries)
        if (entry.key.startsWith('compass.preview.') ||
            entry.key == deletionReceiptKey)
          entry.key: entry.value,
    };
    for (final school in demoSchools) {
      final accounts = LocalAccounts(
        preferences,
        school,
        saved[accountStoreKey(school)],
      );
      final account = accounts.find(
        saved['compass.preview.${school.id}.session'] as String? ?? '',
      );
      if (account != null) {
        await migrateAccountCalendar(preferences, saved, school, account);
      }
    }
  } catch (error) {
    debugPrint('Could not load saved Compass preview data: $error');
  }

  runApp(CompassApp(preferences: preferences, saved: saved));
}

class CompassApp extends StatefulWidget {
  const CompassApp({
    super.key,
    required this.preferences,
    required this.saved,
    this.schoolRegistry,
  });

  final SharedPreferencesAsync preferences;
  final Map<String, Object?> saved;
  final SchoolRegistry? schoolRegistry;

  @override
  State<CompassApp> createState() => _CompassAppState();
}

class _CompassAppState extends State<CompassApp> {
  ThemeMode _themeMode = ThemeMode.system;
  DemoSchool? _school;
  LocalAccount? _account;
  final _accountsBySchool = <String, SchoolAccounts>{};
  final _syncNotice = ValueNotifier<String?>(null);
  CompassRemote? _remote;
  FirestoreGateway? _gateway;
  late final SchoolRegistry? _registry =
      widget.schoolRegistry ??
      (FirebaseBootstrap.isReady
          ? FirebaseSchoolRegistry(firestore: FirebaseFirestore.instance)
          : null);
  bool _restoring = false;
  final _communities = <String, CommunityController>{};
  late final Map<String, Object?> _stored;
  bool _choosingSchool = false;
  final _pendingWrites = <String>{};
  final _readIdsBySchool = <String, Set<String>>{};
  final _friendIdsByAccount = <String, Set<String>>{};
  final _preferencesBySchool = <String, StudentPreferences>{};
  final _calendarsByAccount = <String, ImportedSchoolCalendar?>{};
  final _ucInterestBySchool = <String, bool>{};
  final _completedBySchool = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    final saved = widget.saved;
    _stored = Map.of(saved);
    _themeMode =
        ThemeMode.values
            .where((m) => m.name == saved['compass.preview.theme'])
            .firstOrNull ??
        ThemeMode.system;
    for (final school in demoSchools) {
      _initializeSchool(school);
      if (saved[_selectedSchoolKey] == school.id) _school = school;
    }
    if (_school case final school?) {
      _account = _accountsBySchool[school.id]!.find(
        saved['compass.preview.${school.id}.session'] as String? ?? '',
      );
      if (_account == null) _school = null;
    }
    if (FirebaseBootstrap.isReady) {
      _restoring = true;
      unawaited(_restoreRemoteSession());
    }
  }

  void _initializeSchool(DemoSchool school) {
    if (_accountsBySchool.containsKey(school.id)) return;
    final saved = _stored;
    _accountsBySchool[school.id] = _accountsFor(
      school,
      saved[accountStoreKey(school)],
    );
    final account = _accountsBySchool[school.id]!.find(
      saved['compass.preview.${school.id}.session'] as String? ?? '',
    );
    if (account != null) {
      final key = accountCalendarKey(school, account);
      _calendarsByAccount[key] = ImportedSchoolCalendar.fromStorage(saved[key]);
    }
    _preferencesBySchool[school.id] = StudentPreferences.fromStorage(
      saved[studentPreferencesKey(school)],
      school,
    );
    _readIdsBySchool[school.id] = {
      for (final item in school.guide)
        if ((saved[_cultureReadKey(school, item.id)] ??
                (school.id == 'alderline'
                    ? saved[_legacyCultureReadKey(item.id)]
                    : null)) ==
            true)
          item.id,
    };
    _ucInterestBySchool[school.id] = saved[_ucInterestKey(school)] == true;
    _completedBySchool[school.id] = {
      for (final id in _requirementIdsFor(school))
        if (saved[_requirementCompletedKey(school, id)] case final num value)
          id: value.toInt().clamp(0, 99),
    };
  }

  SchoolAccounts _accountsFor(DemoSchool school, Object? stored) {
    if (FirebaseBootstrap.isReady) {
      return FirebaseSchoolAccounts(
        school: school,
        preferences: widget.preferences,
      );
    }
    if (isFlutterTest) return LocalAccounts(widget.preferences, school, stored);
    return UnavailableAccounts(school);
  }

  Future<void> _restoreRemoteSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await _enterExistingAccount(user);
    } catch (error) {
      debugPrint('Could not restore the Compass session: $error');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<bool> _enterExistingAccount(User user) async {
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final schoolId = profile.data()?['schoolId'] as String?;
    if (schoolId == null || !mounted) return false;
    var school = demoSchools.where((item) => item.id == schoolId).firstOrNull;
    if (school == null) {
      final registered = await _registry?.getApprovedSchool(schoolId);
      if (registered == null) return false;
      school = _schoolFromRegistry(registered);
    }
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return false;
    }
    _initializeSchool(school);
    final account = await _accountsBySchool[school.id]!.restore(user.uid);
    if (account == null || !mounted) return false;
    await _enterSchool(school, account);
    return true;
  }

  Future<User?> _googleUser() async {
    final provider = GoogleAuthProvider();
    final auth = FirebaseAuth.instance;
    final credential = kIsWeb
        ? await auth.signInWithPopup(provider)
        : await auth.signInWithProvider(provider);
    return credential.user;
  }

  Future<void> _signInExisting(BuildContext context) async {
    final auth = FirebaseAuth.instance;
    Future<void> enter(User? user) async {
      if (user != null && await _enterExistingAccount(user)) return;
      throw const AccountException(
        'This account has no school profile. Find your school to join.',
      );
    }

    await openExistingAccountSignIn(
      context,
      onPassword: (email, password) async =>
          enter(await signInToCompassWithPassword(auth, email, password)),
      onPasswordReset: (email) => sendCompassPasswordReset(auth, email),
      onGoogle: allowsGoogleSignIn
          ? () async => enter(await _googleUser())
          : null,
    );
  }

  Future<void> _registerSchool(BuildContext context) async {
    final auth = FirebaseAuth.instance;
    if (!allowsGoogleSignIn && auth.currentUser?.emailVerified != true) {
      final verified = await openExistingAccountSignIn(
        context,
        onPassword: (email, password) async {
          await signInToCompassWithPassword(auth, email, password);
          await verifyCompassEmail(auth);
        },
        onCreate: (email, password) => createCompassPasswordAccount(
          auth,
          email,
          password,
        ),
        onPasswordReset: (email) => sendCompassPasswordReset(auth, email),
        onVerify: () async => verifyCompassEmail(auth),
        onResendVerification: () => resendCompassVerification(auth),
        pendingAccountActions: _unlinkedAccountActions(context),
      );
      if (!verified || !context.mounted) return;
    }
    final repository = FirebaseSchoolRegistrationRepository(
      firestore: FirebaseFirestore.instance,
      auth: auth,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (registrationContext) => SchoolRegistrationPage(
          initialContactEmail: allowsGoogleSignIn
              ? null
              : auth.currentUser?.email,
          accountActions: _unlinkedAccountActions(registrationContext),
          loadApplication: () async {
            if (auth.currentUser == null) return null;
            return repository.loadMyApplication();
          },
          submit: (draft) async {
            if (allowsGoogleSignIn) {
              final user = auth.currentUser;
              final token = await user?.getIdTokenResult();
              if (user == null ||
                  !user.emailVerified ||
                  token?.signInProvider != 'google.com') {
                await _googleUser();
              }
            } else if (auth.currentUser?.email?.toLowerCase() !=
                draft.contactEmail) {
              throw const SchoolRegistrationException(
                'Your school contact email must match your Compass account email.',
              );
            }
            return repository.submitApplication(draft);
          },
        ),
      ),
    );
  }

  Widget _unlinkedAccountActions(BuildContext routeContext) {
    final auth = FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      initialData: auth.currentUser,
      builder: (context, snapshot) => snapshot.data == null
          ? const SizedBox.shrink()
          : AccountDeletionButton(
              onRequested: (receipt) async {
                await _rememberDeletionReceipt(receipt);
                await auth.signOut();
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              },
            ),
    );
  }

  @override
  void dispose() {
    for (final controller in _communities.values) {
      controller.dispose();
    }
    unawaited(_remote?.dispose());
    _syncNotice.dispose();
    super.dispose();
  }

  CommunityController _community(DemoSchool school, LocalAccount account) {
    final key = communityStoreKey(school, account);
    return _communities.putIfAbsent(
      key,
      () => CommunityController(
        school: school,
        account: account,
        saved: _stored[key],
        write: (value) async {
          final cached = compactSharedGalleryCache(value);
          await widget.preferences.setString(key, cached);
          _stored[key] = cached;
          final remote = _remote;
          if (remote != null &&
              remote.uid == account.uid &&
              remote.school.id == school.id) {
            remote.onCommunityWrite(value);
          }
        },
      ),
    );
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await widget.preferences.setString('compass.preview.theme', mode.name);
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _rememberDeletionReceipt(String receipt) async {
    await widget.preferences.setString(deletionReceiptKey, receipt);
    if (mounted) setState(() => _stored[deletionReceiptKey] = receipt);
  }

  Future<void> _dismissDeletionReceipt() async {
    await widget.preferences.remove(deletionReceiptKey);
    if (mounted) setState(() => _stored.remove(deletionReceiptKey));
  }

  Future<void> _finishDeletionRequest(String receipt) async {
    final account = _account;
    final school = _school;
    await _rememberDeletionReceipt(receipt);
    await _logout();
    if (account == null || school == null) return;
    final prefix = 'compass.preview.${school.id}';
    final legacyCalendar = schoolCalendarKey(school.id);
    final legacyOwner = '$legacyCalendar.legacyOwner';
    final keys = {
      communityStoreKey(school, account),
      accountCalendarKey(school, account),
      calendarPromptKey(school.id, account.email),
      _friendKey(school, account),
      if (account.uid case final uid?) 'compass.auth.profile.$uid',
      if (_stored[legacyOwner] == account.email) ...[
        legacyOwner,
        legacyCalendar,
        calendarFeedKey(school.id),
      ],
    };
    final allKeys = await widget.preferences.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('$prefix.culture.read.') ||
          key.startsWith('$prefix.req.completed.') ||
          key == studentPreferencesKey(school) ||
          key == _ucInterestKey(school) ||
          key.startsWith('compass.sync.${account.uid}.${school.id}.')) {
        keys.add(key);
      }
    }
    await widget.preferences.clear(allowList: keys);
    _friendIdsByAccount.remove(_friendKey(school, account));
    _communities.remove(communityStoreKey(school, account))?.dispose();
    _calendarsByAccount.remove(accountCalendarKey(school, account));
    _accountsBySchool.remove(school.id);
    _preferencesBySchool.remove(school.id);
    _readIdsBySchool.remove(school.id);
    _completedBySchool.remove(school.id);
    _ucInterestBySchool.remove(school.id);
    for (final key in keys) {
      _stored.remove(key);
    }
  }

  Future<void> _logout() async {
    if (FirebaseBootstrap.isReady) {
      await FirebaseAuth.instance.signOut();
    }
    await _remote?.dispose();
    _remote = null;
    if (_school case final school?) {
      await widget.preferences.remove('compass.preview.${school.id}.session');
      _stored.remove('compass.preview.${school.id}.session');
    }
    await widget.preferences.remove(_selectedSchoolKey);
    if (mounted) {
      setState(() {
        _account = null;
        _school = null;
      });
    }
  }

  Future<void> _enterSchool(DemoSchool school, LocalAccount account) async {
    await migrateAccountCalendar(widget.preferences, _stored, school, account);
    _calendarsByAccount[accountCalendarKey(
      school,
      account,
    )] = ImportedSchoolCalendar.fromStorage(
      _stored[accountCalendarKey(school, account)],
    );
    await widget.preferences.setString(
      'compass.preview.${school.id}.session',
      account.sessionKey,
    );
    await widget.preferences.setString(_selectedSchoolKey, school.id);
    _stored['compass.preview.${school.id}.session'] = account.sessionKey;
    await _bindRemote(school, account);
    if (mounted) {
      setState(() {
        _school = school;
        _account = account;
      });
    }
  }

  Future<void> _bindRemote(DemoSchool school, LocalAccount account) async {
    final uid = account.uid;
    await _remote?.dispose();
    if (!FirebaseBootstrap.isReady || uid == null) {
      _remote = null;
      return;
    }
    _gateway ??= FirestoreGateway(
      FirebaseFirestore.instance,
      widget.preferences,
    );
    final remote = CompassRemote(
      uid: uid,
      school: school,
      gateway: _gateway!,
      readState: () => _stateFor(school, account),
      applyState: (state) => _applyState(school, account, state),
      notice: _syncNotice,
    );
    _remote = remote;
    await remote.hydrate(_community(school, account));
  }

  UserSchoolState _stateFor(DemoSchool school, LocalAccount account) {
    final preferences = _preferencesBySchool[school.id] ?? StudentPreferences();
    final community = _communities[communityStoreKey(school, account)];
    final friends = _friendsFor(school, account).toList()..sort();
    return UserSchoolState(
      interests: preferences.sortedInterests,
      meetupTime: preferences.meetupTime.name,
      friends: friends,
      clubApplies: (community?.clubApplies ?? const <String>{}).toList()
        ..sort(),
      requirementProgress: Map<String, int>.from(
        _completedBySchool[school.id] ?? const {},
      ),
      guideProgress: (_readIdsBySchool[school.id] ?? const <String>{}).toList()
        ..sort(),
      savedPosts: (community?.savedPosts ?? const <String>{}).toList()..sort(),
      likedPosts: (community?.likedPosts ?? const <String>{}).toList()..sort(),
      followedTags: (community?.followedTags ?? const <String>{}).toList()
        ..sort(),
    );
  }

  Future<void> _applyState(
    DemoSchool school,
    LocalAccount account,
    UserSchoolState state,
  ) async {
    final preferences = StudentPreferences(
      interests: state.interests,
      meetupTime: MeetupTime.values.firstWhere(
        (time) => time.name == state.meetupTime,
        orElse: () => MeetupTime.any,
      ),
    );
    await widget.preferences.setString(
      studentPreferencesKey(school),
      preferences.toStorage(),
    );
    final friends = _rosterFriends(school, state.friends)
      ..addAll(_friendsFor(school, account));
    await _saveFriends(school, account, friends);
    final previousRead = _readIdsBySchool[school.id] ?? {};
    final nextRead = state.guideProgress.toSet();
    for (final id in previousRead.difference(nextRead)) {
      await widget.preferences.remove(_cultureReadKey(school, id));
    }
    for (final id in nextRead) {
      await widget.preferences.setBool(_cultureReadKey(school, id), true);
    }
    final previousProgress = _completedBySchool[school.id] ?? {};
    for (final id in previousProgress.keys) {
      if (!state.requirementProgress.containsKey(id)) {
        await widget.preferences.remove(_requirementCompletedKey(school, id));
      }
    }
    for (final entry in state.requirementProgress.entries) {
      await widget.preferences.setInt(
        _requirementCompletedKey(school, entry.key),
        entry.value,
      );
    }
    _preferencesBySchool[school.id] = preferences;
    _readIdsBySchool[school.id] = nextRead;
    _completedBySchool[school.id] = Map<String, int>.from(
      state.requirementProgress,
    );
    if (mounted) setState(() {});
  }

  void _noteSync() => _remote?.schedulePush();

  Future<void> _chooseSchool(BuildContext context) async {
    if (_choosingSchool) return;
    _choosingSchool = true;
    try {
      final school = await Navigator.of(context).push<DemoSchool>(
        MaterialPageRoute(
          builder: (_) => _SchoolPicker(
            loadSchools: _loadSchools,
            production: _registry != null || !isFlutterTest,
          ),
        ),
      );
      if (!mounted || school == null) return;
      if (!context.mounted) return;
      _initializeSchool(school);
      final existing = _accountsBySchool[school.id]!.find(
        _stored['compass.preview.${school.id}.session'] as String? ?? '',
      );
      final account =
          existing ??
          await Navigator.of(context).push<LocalAccount>(
            MaterialPageRoute(
              builder: (authContext) => SchoolAuthPage(
                school: school,
                accounts: _accountsBySchool[school.id]!,
                pendingAccountActions: FirebaseBootstrap.isReady
                    ? _unlinkedAccountActions(authContext)
                    : null,
              ),
            ),
          );
      if (!mounted || account == null) return;
      try {
        await _enterSchool(school, account);
      } catch (error) {
        debugPrint('Could not save selected school: $error');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remember this school.')),
        );
      }
    } finally {
      _choosingSchool = false;
    }
  }

  Future<List<DemoSchool>> _loadSchools() async {
    final registry = _registry;
    if (registry == null) return isFlutterTest ? demoSchools : const [];
    return (await registry.listApprovedSchools())
        .map(_schoolFromRegistry)
        .toList();
  }

  Future<void> _setFlag(String key, bool value, VoidCallback update) async {
    if (!_pendingWrites.add(key)) return;
    try {
      // Separate keys keep writes to different schools and items independent.
      // https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync-class.html
      await widget.preferences.setBool(key, value);
      if (mounted) setState(update);
      _noteSync();
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Future<void> _toggleCultureRead(DemoSchool school, String id) {
    final readIds = _readIdsBySchool[school.id]!;
    final markRead = !readIds.contains(id);
    return _setFlag(_cultureReadKey(school, id), markRead, () {
      if (markRead) {
        readIds.add(id);
      } else {
        readIds.remove(id);
      }
    });
  }

  Set<String> _rosterFriends(DemoSchool school, Iterable<String> savedIds) => {
    for (final chat in school.conversations) chat.personId,
    for (final person in school.classmates)
      if (savedIds.contains(person.id)) person.id,
  };

  Set<String> _friendsFor(DemoSchool school, LocalAccount account) {
    final key = _friendKey(school, account);
    return _friendIdsByAccount.putIfAbsent(key, () {
      final saved = _stored[key];
      return _rosterFriends(
        school,
        saved is List ? saved.whereType<String>() : const [],
      );
    });
  }

  Future<void> _saveFriends(
    DemoSchool school,
    LocalAccount account,
    Set<String> friends,
  ) async {
    final key = _friendKey(school, account);
    final ids = friends.toList()..sort();
    final current = _friendsFor(school, account);
    await widget.preferences.setStringList(key, ids);
    _stored[key] = ids;
    current
      ..clear()
      ..addAll(ids);
  }

  Future<void> _addFriend(
    DemoSchool school,
    LocalAccount account,
    String id,
  ) async {
    final friends = _friendsFor(school, account);
    if (friends.contains(id) || !school.classmates.any((p) => p.id == id)) {
      return;
    }
    final key = _friendKey(school, account);
    if (!_pendingWrites.add(key)) {
      throw StateError('Friend list is being saved.');
    }
    try {
      await _saveFriends(school, account, {...friends, id});
      if (mounted) setState(() {});
      final remote = _remote;
      if (remote != null &&
          remote.uid == account.uid &&
          remote.school.id == school.id) {
        remote.schedulePush();
      }
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Future<void> _setUcInterest(DemoSchool school, bool value) {
    return _setFlag(_ucInterestKey(school), value, () {
      _ucInterestBySchool[school.id] = value;
    });
  }

  Future<void> _setRequirementCompleted(
    DemoSchool school,
    DemoCreditRequirement requirement,
    int next,
  ) async {
    final key = _requirementCompletedKey(school, requirement.id);
    if (!_pendingWrites.add(key)) return;
    final capped = next.clamp(0, requirement.maxTracked);
    final completed = _completedBySchool[school.id]!;
    final DemoCreditRequirement? totalRequirement =
        requirement.countsTowardCourseTotal
        ? school.graduationRequirements
              .where((item) => item.id.endsWith('-total'))
              .firstOrNull
        : null;
    try {
      await widget.preferences.setInt(key, capped);
      completed[requirement.id] = capped;

      if (totalRequirement != null) {
        final courseSum = school
            .requirementsChecklist(
              ucInterest: _ucInterestBySchool[school.id] ?? false,
            )
            .where((item) => item.countsTowardCourseTotal)
            .fold<int>(0, (total, item) => total + (completed[item.id] ?? 0));
        final totalKey = _requirementCompletedKey(school, totalRequirement.id);
        final currentTotal = completed[totalRequirement.id] ?? 0;
        final fromSubjects = courseSum.clamp(0, totalRequirement.maxTracked);
        // Extra subject courses raise the 25-course total, never lower it.
        if (fromSubjects > currentTotal) {
          await widget.preferences.setInt(totalKey, fromSubjects);
          completed[totalRequirement.id] = fromSubjects;
        }
      }

      if (!mounted) return;
      setState(() {});
      _noteSync();
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Future<void> _savePreferences(
    DemoSchool school,
    StudentPreferences next,
  ) async {
    final key = studentPreferencesKey(school);
    if (!_pendingWrites.add(key)) {
      throw StateError('Preferences are already being saved.');
    }
    try {
      // One JSON value keeps a school's interests and meetup time together.
      // https://pub.dev/packages/shared_preferences#sharedpreferencesasync
      await widget.preferences.setString(key, next.toStorage());
      if (mounted) setState(() => _preferencesBySchool[school.id] = next);
      _noteSync();
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Future<void> _saveCalendar(
    DemoSchool school,
    LocalAccount account,
    ImportedSchoolCalendar? calendar,
  ) async {
    final key = accountCalendarKey(school, account);
    if (!_pendingWrites.add(key)) throw StateError('Calendar is being saved.');
    try {
      await widget.preferences.setString(key, calendar?.toStorage() ?? 'null');
      _stored[key] = calendar?.toStorage() ?? 'null';
      if (mounted) setState(() => _calendarsByAccount[key] = calendar);
    } finally {
      _pendingWrites.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Compass · Local schools',
    debugShowCheckedModeBanner: false,
    builder: !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
        ? macWindowLayout
        : null,
    theme: localCompassTheme(Brightness.light),
    darkTheme: localCompassTheme(Brightness.dark),
    themeMode: _themeMode,
    home: _restoring
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Builder(
            builder: (context) {
              final school = _school;
              final account = _account;
              if (school == null || account == null) {
                final receipt = _stored[deletionReceiptKey] as String?;
                return CompassWelcome(
                  deletionStatus: FirebaseBootstrap.isReady && receipt != null
                      ? DeletionStatus(
                          key: ValueKey(receipt),
                          receipt: receipt,
                          onDismiss: _dismissDeletionReceipt,
                        )
                      : null,
                  onFindSchool: () => _chooseSchool(context),
                  onRegisterSchool: FirebaseBootstrap.isReady
                      ? () => _registerSchool(context)
                      : null,
                  onSignIn: FirebaseBootstrap.isReady
                      ? () => _signInExisting(context)
                      : null,
                );
              }
              return CompassScope(
                remote: _remote,
                child: PreviewShell(
                  key: ValueKey(communityStoreKey(school, account)),
                  school: school,
                  onSwitchSchool: () => _chooseSchool(context),
                  themeMode: _themeMode,
                  onChangeTheme: _setTheme,
                  onLogout: _logout,
                  onRequestDeletion: _remote == null
                      ? null
                      : _finishDeletionRequest,
                  community: _community(school, account),
                  accountEmail: account.email,
                  localPreferences: widget.preferences,
                  initialSaved: _stored,
                  cultureReadIds: _readIdsBySchool[school.id]!,
                  onToggleCultureRead: (id) => _toggleCultureRead(school, id),
                  friendIds: _friendsFor(school, account),
                  onAddFriend: (id) => _addFriend(school, account, id),
                  preferences: _preferencesBySchool[school.id]!,
                  onSavePreferences: (next) => _savePreferences(school, next),
                  calendar:
                      _calendarsByAccount[accountCalendarKey(school, account)],
                  onSaveCalendar: (next) =>
                      _saveCalendar(school, account, next),
                  ucInterest: _ucInterestBySchool[school.id] ?? false,
                  onUcInterestChanged: (value) => _setUcInterest(school, value),
                  completedByRequirement: _completedBySchool[school.id]!,
                  onAdjustRequirementCompleted: (requirement, next) =>
                      _setRequirementCompleted(school, requirement, next),
                ),
              );
            },
          ),
  );
}

class _SchoolPicker extends StatefulWidget {
  const _SchoolPicker({required this.loadSchools, required this.production});
  final Future<List<DemoSchool>> Function() loadSchools;
  final bool production;
  @override
  State<_SchoolPicker> createState() => _SchoolPickerState();
}

class _SchoolPickerState extends State<_SchoolPicker> {
  String _query = '';
  late Future<List<DemoSchool>> _schools = widget.loadSchools();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      top: false,
      child: FutureBuilder<List<DemoSchool>>(
        future: _schools,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ContentColumn(
              maxWidth: 560,
              children: [
                const Text('Could not load schools.'),
                TextButton(
                  onPressed: () =>
                      setState(() => _schools = widget.loadSchools()),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          return _catalog(context, snapshot.data ?? const []);
        },
      ),
    ),
  );

  Widget _catalog(BuildContext context, List<DemoSchool> schools) {
    final results =
        schools
            .where(
              (school) => '${school.name} ${school.location}'
                  .toLowerCase()
                  .contains(_query),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return ContentColumn(
      maxWidth: 560,
      children: [
        Text(
          'Find your school',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 28),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search schools',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 32),
        if (results.isEmpty)
          Text(
            widget.production && schools.isEmpty
                ? 'No approved schools yet.'
                : 'No schools found.',
          ),
        for (var i = 0; i < results.length; i++) ...[
          if (i == 0 || results[i].name[0] != results[i - 1].name[0])
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Text(
                results[i].name[0],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            leading: SchoolMark(school: results[i], size: 42),
            title: Text(
              results[i].isRegistered
                  ? results[i].name
                  : shortSchoolName(results[i]),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, results[i]),
          ),
        ],
      ],
    );
  }
}
