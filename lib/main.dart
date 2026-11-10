import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/compass_welcome.dart';
import 'src/calendar_storage.dart';
import 'src/app_ui.dart';
import 'src/local_accounts.dart';
import 'src/community_models.dart';
import 'src/school_auth_page.dart';
import 'src/preview_shell.dart';
import 'src/preview_theme.dart';
import 'src/recommendations.dart';
import 'src/school_calendar_data.dart';
import 'src/school_demo.dart';

const _selectedSchoolKey = 'compass.preview.selectedSchool';

String _cultureReadKey(DemoSchool school, String id) =>
    'compass.preview.${school.id}.culture.read.$id';

String _legacyCultureReadKey(String id) => 'compass.preview.culture.read.$id';

String _friendKey(DemoSchool school, String id) =>
    'compass.preview.${school.id}.friend.${school.student.id}.$id';

String _ucInterestKey(DemoSchool school) =>
    'compass.preview.${school.id}.ucInterest';

String _requirementCompletedKey(DemoSchool school, String requirementId) =>
    'compass.preview.${school.id}.req.completed.$requirementId';

Iterable<String> _requirementIdsFor(DemoSchool school) => {
  for (final requirement in school.graduationRequirements) requirement.id,
  for (final requirement in school.ucRequirements) requirement.id,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesAsync();
  Map<String, Object?> saved = {};
  try {
    final all = await preferences.getAll();
    saved = {
      for (final entry in all.entries)
        if (entry.key.startsWith('compass.preview.')) entry.key: entry.value,
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
  const CompassApp({super.key, required this.preferences, required this.saved});

  final SharedPreferencesAsync preferences;
  final Map<String, Object?> saved;

  @override
  State<CompassApp> createState() => _CompassAppState();
}

class _CompassAppState extends State<CompassApp> {
  ThemeMode _themeMode = ThemeMode.system;
  DemoSchool? _school;
  LocalAccount? _account;
  final _accountsBySchool = <String, LocalAccounts>{};
  final _communities = <String, CommunityController>{};
  late final Map<String, Object?> _stored;
  bool _choosingSchool = false;
  final _pendingWrites = <String>{};
  final _readIdsBySchool = <String, Set<String>>{};
  final _friendIdsBySchool = <String, Set<String>>{};
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
      _accountsBySchool[school.id] = LocalAccounts(
        widget.preferences,
        school,
        saved[accountStoreKey(school)],
      );
      final account = _accountsBySchool[school.id]!.find(
        saved['compass.preview.${school.id}.session'] as String? ?? '',
      );
      if (account != null) {
        final key = accountCalendarKey(school, account);
        _calendarsByAccount[key] = ImportedSchoolCalendar.fromStorage(
          saved[key],
        );
      }
      _preferencesBySchool[school.id] = StudentPreferences.fromStorage(
        saved[studentPreferencesKey(school)],
        school,
      );
      if (saved[_selectedSchoolKey] == school.id) _school = school;
      _readIdsBySchool[school.id] = {
        for (final item in school.guide)
          if ((saved[_cultureReadKey(school, item.id)] ??
                  (school.id == 'alderline'
                      ? saved[_legacyCultureReadKey(item.id)]
                      : null)) ==
              true)
            item.id,
      };
      _friendIdsBySchool[school.id] = {
        for (final chat in school.conversations) chat.personId,
        for (final person in school.classmates)
          if (saved[_friendKey(school, person.id)] == true) person.id,
      };
      _ucInterestBySchool[school.id] = saved[_ucInterestKey(school)] == true;
      _completedBySchool[school.id] = {
        for (final id in _requirementIdsFor(school))
          if (saved[_requirementCompletedKey(school, id)] case final Object raw)
            if (raw is int)
              id: raw.clamp(0, 99)
            else if (raw is num)
              id: raw.toInt().clamp(0, 99),
      };
    }
    if (_school case final school?) {
      _account = _accountsBySchool[school.id]!.find(
        saved['compass.preview.${school.id}.session'] as String? ?? '',
      );
      if (_account == null) _school = null;
    }
  }

  @override
  void dispose() {
    for (final controller in _communities.values) {
      controller.dispose();
    }
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
          await widget.preferences.setString(key, value);
          _stored[key] = value;
        },
      ),
    );
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await widget.preferences.setString('compass.preview.theme', mode.name);
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _logout() async {
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

  Future<void> _chooseSchool(BuildContext context) async {
    if (_choosingSchool) return;
    _choosingSchool = true;
    try {
      final school = await Navigator.of(context).push<DemoSchool>(
        MaterialPageRoute(
          builder: (_) => _SchoolPicker(currentSchool: _school),
        ),
      );
      if (!mounted || school == null) return;
      if (!context.mounted) return;
      final existing = _accountsBySchool[school.id]!.find(
        _stored['compass.preview.${school.id}.session'] as String? ?? '',
      );
      final account =
          existing ??
          await Navigator.of(context).push<LocalAccount>(
            MaterialPageRoute(
              builder: (_) => SchoolAuthPage(
                school: school,
                accounts: _accountsBySchool[school.id]!,
              ),
            ),
          );
      if (!mounted || account == null) return;
      try {
        await migrateAccountCalendar(
          widget.preferences,
          _stored,
          school,
          account,
        );
        _calendarsByAccount[accountCalendarKey(
          school,
          account,
        )] = ImportedSchoolCalendar.fromStorage(
          _stored[accountCalendarKey(school, account)],
        );
        await widget.preferences.setString(
          'compass.preview.${school.id}.session',
          account.email,
        );
        await widget.preferences.setString(_selectedSchoolKey, school.id);
        _stored['compass.preview.${school.id}.session'] = account.email;
        if (mounted) {
          setState(() {
            _school = school;
            _account = account;
          });
        }
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

  Future<void> _setFlag(String key, bool value, VoidCallback update) async {
    if (!_pendingWrites.add(key)) return;
    try {
      // Separate keys keep writes to different schools and items independent.
      // https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync-class.html
      await widget.preferences.setBool(key, value);
      if (mounted) setState(update);
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

  Future<void> _addFriend(DemoSchool school, String id) async {
    final friendIds = _friendIdsBySchool[school.id]!;
    if (friendIds.contains(id)) return;
    await _setFlag(_friendKey(school, id), true, () => friendIds.add(id));
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
            .fold<int>(0, (sum, item) => sum + (completed[item.id] ?? 0));
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
    theme: localCompassTheme(Brightness.light),
    darkTheme: localCompassTheme(Brightness.dark),
    themeMode: _themeMode,
    home: Builder(
      builder: (context) {
        final school = _school;
        final account = _account;
        if (school == null || account == null) {
          return CompassWelcome(onFindSchool: () => _chooseSchool(context));
        }
        return PreviewShell(
          key: ValueKey(school.id),
          school: school,
          onSwitchSchool: () => _chooseSchool(context),
          themeMode: _themeMode,
          onChangeTheme: _setTheme,
          onLogout: _logout,
          community: _community(school, account),
          accountEmail: account.email,
          localPreferences: widget.preferences,
          initialSaved: _stored,
          cultureReadIds: _readIdsBySchool[school.id]!,
          onToggleCultureRead: (id) => _toggleCultureRead(school, id),
          friendIds: _friendIdsBySchool[school.id]!,
          onAddFriend: (id) => _addFriend(school, id),
          preferences: _preferencesBySchool[school.id]!,
          onSavePreferences: (next) => _savePreferences(school, next),
          calendar: _calendarsByAccount[accountCalendarKey(school, account)],
          onSaveCalendar: (next) => _saveCalendar(school, account, next),
          ucInterest: _ucInterestBySchool[school.id] ?? false,
          onUcInterestChanged: (value) => _setUcInterest(school, value),
          completedByRequirement: _completedBySchool[school.id]!,
          onAdjustRequirementCompleted: (requirement, next) =>
              _setRequirementCompleted(school, requirement, next),
        );
      },
    ),
  );
}

class _SchoolPicker extends StatefulWidget {
  const _SchoolPicker({required this.currentSchool});
  final DemoSchool? currentSchool;
  @override
  State<_SchoolPicker> createState() => _SchoolPickerState();
}

class _SchoolPickerState extends State<_SchoolPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final results =
        demoSchools
            .where(
              (school) => '${school.name} ${school.location}'
                  .toLowerCase()
                  .contains(_query),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ContentColumn(
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
            if (results.isEmpty) const Text('No schools found.'),
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
                  shortSchoolName(results[i]),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, results[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
