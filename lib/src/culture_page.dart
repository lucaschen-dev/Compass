import 'package:flutter/material.dart';

import 'school_demo.dart';

class CulturePage extends StatelessWidget {
  const CulturePage({
    super.key,
    required this.school,
    required this.readIds,
    required this.onToggleRead,
  });

  final DemoSchool school;
  final Set<String> readIds;
  final ValueChanged<String> onToggleRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sections = <String, List<DemoGuideItem>>{};
    for (final note in school.guide) {
      sections.putIfAbsent(note.category, () => []).add(note);
    }
    final total = school.guide.length;
    final read = school.guide.where((note) => readIds.contains(note.id)).length;
    final progress = '$read of $total read';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          key: PageStorageKey((school.id, 'culture')),
          padding: EdgeInsets.fromLTRB(
            wide ? 40 : 20,
            wide ? 48 : 28,
            wide ? 40 : 20,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FICTIONAL SCHOOL GUIDE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      'Campus guide',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everyday routines and what to wear at '
                    '${school.name}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DefaultTextStyle.merge(
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onPrimaryContainer,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                const Text('Reading progress'),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(progress),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // The live count supplies the progress description.
                          // https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html
                          ExcludeSemantics(
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : read / total,
                              color: colors.onPrimaryContainer,
                              backgroundColor: colors.onPrimaryContainer
                                  .withValues(alpha: .16),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final section in sections.entries) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        section.key,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final note in section.value) ...[
                      const SizedBox(height: 10),
                      _NoteCard(
                        note: note,
                        isRead: readIds.contains(note.id),
                        onToggleRead: () => onToggleRead(note.id),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.isRead,
    required this.onToggleRead,
  });

  final DemoGuideItem note;
  final bool isRead;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final action = isRead ? 'unread' : 'read';

    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              note.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  isRead ? 'Read' : 'Unread',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isRead ? colors.onSurfaceVariant : colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  key: ValueKey('culture-toggle-${note.id}'),
                  onPressed: onToggleRead,
                  child: Text(
                    'Mark as $action',
                    semanticsLabel: 'Mark ${note.title} as $action',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
