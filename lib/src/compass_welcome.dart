import 'package:flutter/material.dart';

class CompassWelcome extends StatelessWidget {
  const CompassWelcome({
    super.key,
    required this.onFindSchool,
    required this.appearanceAction,
  });

  final VoidCallback onFindSchool;
  final Widget appearanceAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: [appearanceAction]),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 36),
                const Text(
                  'Compass',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'LOCAL PREVIEW',
                  style: TextStyle(letterSpacing: 3, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Find your people.\nMake campus feel like home.',
                  style: TextStyle(fontSize: 25, height: 1.4),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onFindSchool,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Find your school'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Explore a fictional school community. Your progress stays on this device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
