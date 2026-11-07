import 'package:flutter/material.dart';

class CompassWelcome extends StatelessWidget {
  const CompassWelcome({
    super.key,
    required this.onJoinSchool,
    this.onExplore,
    this.joinLabel = 'Join your school',
    required this.description,
    this.communityLabel = 'BUCKLEY COMMUNITY',
    this.appearanceAction,
    this.error,
  });

  final VoidCallback onJoinSchool;
  final VoidCallback? onExplore;
  final String joinLabel;
  final String description;
  final String communityLabel;
  final Widget? appearanceAction;
  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appearanceAction == null
        ? null
        : AppBar(actions: [appearanceAction!]),
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
                Text(
                  communityLabel,
                  style: const TextStyle(letterSpacing: 3, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Find your people.\nMake campus feel like home.',
                  style: TextStyle(fontSize: 25, height: 1.4),
                ),
                const SizedBox(height: 32),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: onJoinSchool,
                  icon: const Icon(Icons.school_outlined),
                  label: Text(joinLabel),
                ),
                if (onExplore != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onExplore,
                    child: const Text('Explore the demo'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  description,
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
