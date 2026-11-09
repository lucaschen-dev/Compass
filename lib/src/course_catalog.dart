import 'package:flutter/material.dart';

import 'school_demo.dart';

class CourseCatalog extends StatefulWidget {
  const CourseCatalog({super.key, required this.school});
  final DemoSchool school;

  @override
  State<CourseCatalog> createState() => _CourseCatalogState();
}

class _CourseCatalogState extends State<CourseCatalog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(covariant CourseCatalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.school.id != widget.school.id) {
      _query = '';
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courses = widget.school.courses.where(
      (course) =>
          course.title.toLowerCase().contains(_query) ||
          course.subject.toLowerCase().contains(_query),
    );
    return Column(
      key: const ValueKey('guide-course-catalog'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Course catalog',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Search courses',
            hintText: 'Course title or subject',
            prefixIcon: Icon(Icons.search),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (courses.isEmpty) const Text('No courses match your search.'),
        for (final course in courses)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${course.subject} · ${course.credits} ${course.credits == 1 ? 'credit' : 'credits'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.prerequisites.isEmpty
                        ? 'No prerequisites'
                        : 'Prerequisites: ${course.prerequisites.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
