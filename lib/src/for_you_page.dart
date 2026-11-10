import 'package:flutter/material.dart';

import 'demo_activities.dart';
import 'recommendations.dart';
import 'school_demo.dart';

class ForYouPage extends StatelessWidget {
  const ForYouPage({
    super.key,
    required this.school,
    required this.preferences,
    required this.onSavePreferences,
  });

  final DemoSchool school;
  final StudentPreferences preferences;
  final Future<void> Function(StudentPreferences) onSavePreferences;

  Future<void> _edit(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    // https://api.flutter.dev/flutter/material/showModalBottomSheet.html
    builder: (_) => _PreferencesEditor(
      school: school,
      preferences: preferences,
      onSave: onSavePreferences,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recommendations = recommendFor(school, preferences);
    final hasInterests = preferences.interests.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: PageStorageKey((school.id, 'for-you')),
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth >= 600 ? 40 : 20,
          constraints.maxWidth >= 600 ? 28 : 12,
          constraints.maxWidth >= 600 ? 40 : 20,
          28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  school.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'For you',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    if (hasInterests)
                      OutlinedButton.icon(
                        key: const ValueKey('edit-preferences'),
                        onPressed: () => _edit(context),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Preferences'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!hasInterests)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.interests_outlined, size: 32),
                          const SizedBox(height: 16),
                          Text(
                            'Choose what you enjoy',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const ValueKey('choose-preferences'),
                            onPressed: () => _edit(context),
                            child: const Text('Choose preferences'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    preferences.sortedInterests.join(' · '),
                    key: const ValueKey('preference-summary'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (preferences.meetupTime != MeetupTime.any) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Meetups: ${preferences.meetupTime.label}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, content) {
                      final sections = [
                        _RecommendationSection(
                          title: 'Peers',
                          emptyMessage:
                              'No classmates share these interests yet.',
                          children: [
                            for (final match in recommendations.peers)
                              _PeerCard(match: match),
                          ],
                        ),
                        _RecommendationSection(
                          title: 'Clubs',
                          emptyMessage: 'No clubs match. Try another interest or meetup time.',
                          children: [
                            for (final match in recommendations.clubs)
                              _ActivityCard(
                                match: match,
                                icon: Icons.groups_outlined,
                              ),
                          ],
                        ),
                        _RecommendationSection(
                          title: 'Events',
                          emptyMessage: 'No events match. Try another interest or meetup time.',
                          children: [
                            for (final match in recommendations.events)
                              _ActivityCard(
                                match: match,
                                icon: Icons.event_outlined,
                              ),
                          ],
                        ),
                      ];
                      if (content.maxWidth >= 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < sections.length; i++) ...[
                              if (i > 0) const SizedBox(width: 20),
                              Expanded(child: sections[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < sections.length; i++) ...[
                            if (i > 0) const SizedBox(height: 24),
                            sections[i],
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesEditor extends StatefulWidget {
  const _PreferencesEditor({
    required this.school,
    required this.preferences,
    required this.onSave,
  });

  final DemoSchool school;
  final StudentPreferences preferences;
  final Future<void> Function(StudentPreferences) onSave;

  @override
  State<_PreferencesEditor> createState() => _PreferencesEditorState();
}

class _PreferencesEditorState extends State<_PreferencesEditor> {
  late final _interests = widget.preferences.interests.toSet();
  late var _meetupTime = widget.preferences.meetupTime;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        StudentPreferences(interests: _interests, meetupTime: _meetupTime),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save preferences. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your preferences',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preferences',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.school.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text('Interests', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              // Native multi-select chips wrap at narrow widths.
              // https://api.flutter.dev/flutter/material/FilterChip-class.html
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interest in availableInterests(widget.school))
                    FilterChip(
                      key: ValueKey('interest-$interest'),
                      label: Text(interest),
                      selected: _interests.contains(interest),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _interests.add(interest);
                              } else {
                                _interests.remove(interest);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Meetup time', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in MeetupTime.values)
                    ChoiceChip(
                      key: ValueKey('meetup-${time.name}'),
                      label: Text(time.label),
                      selected: _meetupTime == time,
                      onSelected: _saving
                          ? null
                          : (selected) {
                              if (selected) setState(() => _meetupTime = time);
                            },
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('reset-preferences'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _interests.clear();
                            _meetupTime = MeetupTime.any;
                            _error = null;
                          }),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('save-preferences'),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Saving…' : 'Save preferences',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });
  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w400),
        ),
      ),
      const SizedBox(height: 10),
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        ...children,
    ],
  );
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.match});
  final InterestMatch<DemoPerson> match;

  @override
  Widget build(BuildContext context) {
    final person = match.item;
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('peer-${person.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: ExcludeSemantics(child: Text(person.initials)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name, style: theme.textTheme.titleMedium),
                      Text(
                        'Grade ${person.grade}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              person.bio,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Shared: ${match.sharedInterests.join(' · ')}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.match, required this.icon});
  final InterestMatch<DemoActivity> match;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final activity = match.item;
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('activity-${activity.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activity.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              activity.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              '${activity.when}\n${activity.location}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Matches: ${match.sharedInterests.join(' · ')}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editStudentPreferences(
  BuildContext context,
  DemoSchool school,
  StudentPreferences preferences,
  Future<void> Function(StudentPreferences) onSave,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => _PreferencesEditor(
    school: school,
    preferences: preferences,
    onSave: onSave,
  ),
);
