import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/compass_welcome.dart';
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
    saved = await preferences.getAll(
      allowList: {
        _selectedSchoolKey,
        for (final school in demoSchools) ...{
          studentPreferencesKey(school),
          schoolCalendarKey(school.id),
          for (final item in school.guide) _cultureReadKey(school, item.id),
          for (final person in school.classmates) _friendKey(school, person.id),
          _ucInterestKey(school),
          for (final id in _requirementIdsFor(school))
            _requirementCompletedKey(school, id),
          if (school.id == 'alderline')
            for (final item in school.guide) _legacyCultureReadKey(item.id),
        },
      },
    );
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
  bool _choosingSchool = false;
  final _pendingWrites = <String>{};
  final _readIdsBySchool = <String, Set<String>>{};
  final _friendIdsBySchool = <String, Set<String>>{};
  final _preferencesBySchool = <String, StudentPreferences>{};
  final _calendarsBySchool = <String, ImportedSchoolCalendar?>{};
  final _ucInterestBySchool = <String, bool>{};
  final _completedBySchool = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    final saved = widget.saved;
    for (final school in demoSchools) {
      _calendarsBySchool[school.id] = ImportedSchoolCalendar.fromStorage(
        saved[schoolCalendarKey(school.id)],
      );
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
  }

  Future<void> _chooseSchool(BuildContext context) async {
    if (_choosingSchool) return;
    _choosingSchool = true;
    try {
      final school = await Navigator.of(context).push<DemoSchool>(
        MaterialPageRoute(
          builder: (_) => _SchoolPicker(
            currentSchool: _school,
            appearanceAction: _appearanceAction(),
          ),
        ),
      );
      if (!mounted || school == null || _school?.id == school.id) return;
      setState(() => _school = school);
      try {
        await widget.preferences.setString(_selectedSchoolKey, school.id);
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
    ImportedSchoolCalendar? calendar,
  ) async {
    final key = schoolCalendarKey(school.id);
    if (!_pendingWrites.add(key)) throw StateError('Calendar is being saved.');
    try {
      if (calendar == null) {
        await widget.preferences.remove(key);
      } else {
        await widget.preferences.setString(key, calendar.toStorage());
      }
      if (mounted) setState(() => _calendarsBySchool[school.id] = calendar);
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Widget _appearanceAction() => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return IconButton(
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
        onPressed: () {
          setState(
            () => _themeMode = isDark ? ThemeMode.light : ThemeMode.dark,
          );
        },
      );
    },
  );

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
        if (school == null) {
          return CompassWelcome(
            appearanceAction: _appearanceAction(),
            onFindSchool: () => _chooseSchool(context),
          );
        }
        return PreviewShell(
          key: ValueKey(school.id),
          school: school,
          onSwitchSchool: () => _chooseSchool(context),
          themeMode: _themeMode,
          onChangeTheme: (mode) => setState(() => _themeMode = mode),
          cultureReadIds: _readIdsBySchool[school.id]!,
          onToggleCultureRead: (id) => _toggleCultureRead(school, id),
          friendIds: _friendIdsBySchool[school.id]!,
          onAddFriend: (id) => _addFriend(school, id),
          preferences: _preferencesBySchool[school.id]!,
          onSavePreferences: (next) => _savePreferences(school, next),
          calendar: _calendarsBySchool[school.id],
          onSaveCalendar: (next) => _saveCalendar(school, next),
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
  const _SchoolPicker({
    required this.currentSchool,
    required this.appearanceAction,
  });

  final DemoSchool? currentSchool;
  final Widget appearanceAction;

  @override
  State<_SchoolPicker> createState() => _SchoolPickerState();
}

class _SchoolPickerState extends State<_SchoolPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final results = demoSchools.where(
      (school) =>
          '${school.name} ${school.location}'.toLowerCase().contains(_query),
    );

    return Scaffold(
      appBar: AppBar(actions: [widget.appearanceAction]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Find your school',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose a fictional campus to explore.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search schools',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (query) =>
                        setState(() => _query = query.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 16),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No matching schools. Try another name.'),
                    ),
                  for (final school in results)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: ExcludeSemantics(child: Text(school.initials)),
                        ),
                        title: Text(school.name),
                        subtitle: Text(school.location),
                        selected: school.id == widget.currentSchool?.id,
                        trailing: Icon(
                          school.id == widget.currentSchool?.id
                              ? Icons.check
                              : Icons.chevron_right,
                        ),
                        onTap: () => Navigator.of(context).pop(school),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
