import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'course_catalog.dart';
import 'school_demo.dart';

class CulturePage extends StatefulWidget {
  const CulturePage({
    super.key,
    required this.school,
    required this.readIds,
    required this.onToggleRead,
  });
  final DemoSchool school;
  final Set<String> readIds;
  final Future<void> Function(String) onToggleRead;
  @override
  State<CulturePage> createState() => _CulturePageState();
}

class _CulturePageState extends State<CulturePage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final sections = [
      (label: 'Dress code', icon: Icons.checkroom_outlined),
      (label: 'Grade', icon: Icons.layers_outlined),
      (label: 'Faculty & classrooms', icon: Icons.apartment_outlined),
      (label: 'Campus life', icon: Icons.people_outline),
      (label: 'Course catalog', icon: Icons.menu_book_outlined),
    ];
    return ContentColumn(
      children: [
        Text('Guide', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search guide',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 28),
        for (final section in sections)
          if (_query.isEmpty ||
              section.label.toLowerCase().contains(_query) ||
              widget.school.guide.any(
                (g) =>
                    '${g.title} ${g.description}'.toLowerCase().contains(
                      _query,
                    ) &&
                    ((section.label == 'Dress code' &&
                            g.category.toLowerCase().contains('dress')) ||
                        (section.label == 'Campus life' &&
                            !g.category.toLowerCase().contains('dress'))),
              )) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              leading: Icon(section.icon, size: 27),
              title: Text(
                section.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 22),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _GuideSection(
                    school: widget.school,
                    title: section.label,
                    readIds: widget.readIds,
                    onToggleRead: widget.onToggleRead,
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
      ],
    );
  }
}

class _GuideSection extends StatefulWidget {
  const _GuideSection({
    required this.school,
    required this.title,
    required this.readIds,
    required this.onToggleRead,
  });
  final DemoSchool school;
  final String title;
  final Set<String> readIds;
  final Future<void> Function(String) onToggleRead;
  @override
  State<_GuideSection> createState() => _GuideSectionState();
}

class _GuideSectionState extends State<_GuideSection> {
  @override
  Widget build(BuildContext context) {
    final dress = widget.title == 'Dress code';
    final notes = widget.school.guide.where(
      (g) => dress
          ? g.category.toLowerCase().contains('dress')
          : !g.category.toLowerCase().contains('dress'),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ContentColumn(
        children: [
          if (widget.title == 'Course catalog')
            CourseCatalog(school: widget.school, showTitle: false)
          else if (widget.title == 'Grade')
            for (final grade in [9, 10, 11, 12])
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Grade $grade'),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(switch (grade) {
                      9 => 'Meet your adviser, learn your campus routines, and build a balanced course schedule.',
                      10 => 'Explore electives and clubs. Check your graduation progress with your adviser.',
                      11 => 'Review your remaining requirements and plan next year’s courses.',
                      _ => 'Confirm your graduation checklist, final courses, and application deadlines with your adviser.',
                    }),
                  ),
                ],
              )
          else if (widget.title == 'Faculty & classrooms') ...[
            Text(
              'Faculty directory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            for (final entry in [
              (
                name: 'Morgan Lee',
                role: 'Student adviser',
                room: 'Main office',
              ),
              (name: 'Sam Rivera', role: 'Science', room: 'Room 204'),
              (
                name: 'Taylor Park',
                role: 'Arts',
                room: widget.school.id == 'alderline'
                    ? 'Art studio'
                    : 'Auditorium',
              ),
            ]) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                leading: StudentAvatar(name: entry.name),
                title: Text(entry.name),
                subtitle: Text('${entry.role} · ${entry.room}'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(entry.name),
                    content: Text(
                      '${entry.role}\n${entry.room}\n${entry.name.toLowerCase().replaceAll(' ', '.')}@${widget.school.id}.example',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
            ],
          ] else
            for (final note in notes) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      note.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await appSave(
                            context,
                            () => widget.onToggleRead(note.id),
                          );
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                          widget.readIds.contains(note.id)
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 18,
                        ),
                        label: Text(
                          widget.readIds.contains(note.id)
                              ? 'Read'
                              : 'Mark as read',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
        ],
      ),
    );
  }
}
