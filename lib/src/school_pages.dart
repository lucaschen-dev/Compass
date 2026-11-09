import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'school_demo.dart';
import 'school_calendar_card.dart';
import 'school_calendar_data.dart';

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key, required this.school});

  final DemoSchool school;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final posts = school.announcements;
    final wordmark = school.name.replaceFirst(RegExp(r' High School$'), '');

    return _SchoolPage(
      school: school,
      title: 'Home',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.building_2_fill, size: 28),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      wordmark.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: school.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: 'Fictional school demo',
                    excludeSemantics: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          'DEMO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (posts.isNotEmpty) ...[
                const SizedBox(height: 26),
                Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.pin,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Important',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                _AnnouncementCard(posts.first, pinned: true),
              ],
              if (posts.length > 1) ...[
                const SizedBox(height: 29),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionHeading('Latest posts'),
                    Text(
                      '${posts.length - 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final post in posts.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _AnnouncementCard(post),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DemoProfilePage extends StatefulWidget {
  const DemoProfilePage({
    super.key,
    required this.school,
    required this.ucInterest,
    required this.onUcInterestChanged,
  });

  final DemoSchool school;
  final bool ucInterest;
  final ValueChanged<bool> onUcInterestChanged;

  @override
  State<DemoProfilePage> createState() => _DemoProfilePageState();
}

class _DemoProfilePageState extends State<DemoProfilePage> {
  late bool _ucInterest = widget.ucInterest;

  @override
  void didUpdateWidget(covariant DemoProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ucInterest != widget.ucInterest) {
      _ucInterest = widget.ucInterest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final school = widget.school;
    final student = school.student;

    return _SchoolPage(
      school: school,
      title: 'Profile',
      children: [
        _SchoolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: ExcludeSemantics(child: Text(student.initials)),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  student.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Grade ${student.grade} · ${school.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              const _SectionHeading('About me'),
              const SizedBox(height: 6),
              Text(
                student.bio,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
              const _SectionHeading('Interests'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final interest in student.interests)
                    Semantics(
                      label: interest,
                      excludeSemantics: true,
                      child: Chip(label: Text(interest)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SchoolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeading('Settings'),
              const SizedBox(height: 6),
              Text(
                'Extra UC-only items are added to your Courses checklist.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Interested to enroll in UC'),
                subtitle: const Text(
                  'Adds UC requirements that are not already covered by '
                  'grades 9–12 graduation rules.',
                ),
                value: _ucInterest,
                onChanged: (value) {
                  setState(() => _ucInterest = value);
                  widget.onUcInterestChanged(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DemoAcademicsPage extends StatefulWidget {
  const DemoAcademicsPage({
    super.key,
    required this.school,
    required this.ucInterest,
    required this.completedByRequirement,
    required this.onAdjustCompleted,
    required this.calendar,
    required this.onSaveCalendar,
  });

  final DemoSchool school;
  final bool ucInterest;
  final ImportedSchoolCalendar? calendar;
  final Future<void> Function(ImportedSchoolCalendar?) onSaveCalendar;
  final Map<String, int> completedByRequirement;
  final Future<void> Function(DemoCreditRequirement requirement, int next)
  onAdjustCompleted;

  @override
  State<DemoAcademicsPage> createState() => _DemoAcademicsPageState();
}

class _DemoAcademicsPageState extends State<DemoAcademicsPage> {
  int _completed(DemoCreditRequirement requirement) =>
      widget.completedByRequirement[requirement.id] ?? 0;

  @override
  Widget build(BuildContext context) {
    final school = widget.school;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final requirements = school.requirementsChecklist(
      ucInterest: widget.ucInterest,
    );

    return _SchoolPage(
      school: school,
      title: 'Academics',
      children: [
        Text(
          school.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        SchoolCalendarCard(
          key: ValueKey(school.id),
          schoolId: school.id,
          calendar: widget.calendar,
          onSaveCalendar: widget.onSaveCalendar,
        ),
        const SizedBox(height: 24),
        _RequirementsCard(
          title: 'Graduation Requirements',
          subtitle: widget.ucInterest
              ? '9–12 and UC requirements'
              : '9–12 requirements',
          instructions:
              'Mark what you have completed to see what you still need.',
          requirements: requirements,
          completedFor: _completed,
          onAdjust: widget.onAdjustCompleted,
        ),
      ],
    );
  }
}

class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard({
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.requirements,
    required this.completedFor,
    required this.onAdjust,
  });

  final String title;
  final String subtitle;
  final String instructions;
  final List<DemoCreditRequirement> requirements;
  final int Function(DemoCreditRequirement requirement) completedFor;
  final Future<void> Function(DemoCreditRequirement requirement, int next)
  onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Overall totals (e.g. 25 courses) already include the subject rows.
    final summaryRequirements = [
      for (final requirement in requirements)
        if (!requirement.id.endsWith('-total')) requirement,
    ];
    final remaining = summaryRequirements.fold<int>(0, (total, requirement) {
      final done = completedFor(requirement).clamp(0, requirement.credits);
      final stillNeed = requirement.credits - done;
      return total + (stillNeed > 0 ? stillNeed : 0);
    });
    final requiredTotal = summaryRequirements.fold<int>(
      0,
      (total, requirement) => total + requirement.credits,
    );
    final completedTotal = requiredTotal - remaining;

    return _SchoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(title),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            instructions,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 10),
          for (final requirement in requirements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _RequirementProgressRow(
                requirement: requirement,
                completed: completedFor(requirement),
                onAdjust: onAdjust,
              ),
            ),
          const Divider(height: 18),
          _CreditRow(
            remaining == 0 ? 'All subject requirements met' : 'Still need',
            remaining == 0 ? completedTotal : remaining,
            emphasize: true,
            unitLabel: remaining == 1 ? 'unit' : 'units',
          ),
        ],
      ),
    );
  }
}

class _RequirementProgressRow extends StatelessWidget {
  const _RequirementProgressRow({
    required this.requirement,
    required this.completed,
    required this.onAdjust,
  });

  final DemoCreditRequirement requirement;
  final int completed;
  final Future<void> Function(DemoCreditRequirement requirement, int next)
  onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tracked = completed.clamp(0, requirement.maxTracked);
    final towardRequired = tracked.clamp(0, requirement.credits);
    final needed = requirement.credits - towardRequired;
    final met = needed == 0;
    final hasExtra = requirement.maxTracked > requirement.credits;
    final progressLabel = tracked > requirement.credits
        ? '${requirement.amountLabel(tracked)} logged'
        : '${requirement.amountLabel(tracked)} of '
              '${requirement.amountLabel(requirement.credits)}'
              '${hasExtra ? ' required' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requirement.subject,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (requirement.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      requirement.detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (hasExtra) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Up to ${requirement.amountLabel(requirement.maxTracked)} '
                      'recommended',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    progressLabel,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: met ? colors.primary : null,
                      fontWeight: met ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    met
                        ? 'Complete'
                        : 'Need ${requirement.amountLabel(needed)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: met ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              tooltip: 'Remove completed ${requirement.unitLabel}',
              onPressed: tracked == 0
                  ? null
                  : () => onAdjust(requirement, tracked - 1),
              icon: const Icon(Icons.remove_circle_outline),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: requirement.credits == 0
                      ? 0
                      : towardRequired / requirement.credits,
                  minHeight: 8,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Add completed ${requirement.unitLabel}',
              onPressed: tracked >= requirement.maxTracked
                  ? null
                  : () => onAdjust(requirement, tracked + 1),
              icon: const Icon(Icons.add_circle_outline),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow(
    this.label,
    this.credits, {
    this.emphasize = false,
    this.unitLabel,
  });

  final String label;
  final int credits;
  final bool emphasize;
  final String? unitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    final unit = unitLabel ?? (credits == 1 ? 'credit' : 'credits');
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text('$credits $unit', style: style),
      ],
    );
  }
}

class _SchoolPage extends StatelessWidget {
  const _SchoolPage({
    required this.school,
    required this.title,
    required this.children,
  });

  final DemoSchool school;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          key: PageStorageKey((school.id, title)),
          padding: EdgeInsets.fromLTRB(
            wide ? 40 : 16,
            wide ? 28 : 8,
            wide ? 40 : 16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(this.announcement, {this.pinned = false});

  final DemoAnnouncement announcement;
  final bool pinned;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(announcement.label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                Text(announcement.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(announcement.message, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 18),
                Text(
                  '${announcement.author} · ${announcement.when}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final secondary = colors.onSurfaceVariant;
    final initials = announcement.author
        .split(' ')
        .take(2)
        .map((word) => word[0])
        .join();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (pinned) ...[
                    Icon(CupertinoIcons.pin_fill, size: 13, color: secondary),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    announcement.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                announcement.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                announcement.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: colors.surfaceContainerHighest,
                      foregroundColor: secondary,
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      announcement.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    announcement.when,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: secondary,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    header: true,
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}
