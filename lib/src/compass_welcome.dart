import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'compass_backdrop.dart';
import 'compass_policy_links.dart';

class CompassWelcome extends StatelessWidget {
  const CompassWelcome({
    super.key,
    required this.onFindSchool,
    this.onRegisterSchool,
    this.onSignIn,
    this.deletionStatus,
    this.appearanceAction = const SizedBox.shrink(),
  });
  final VoidCallback onFindSchool;
  final VoidCallback? onRegisterSchool;
  final VoidCallback? onSignIn;
  final Widget appearanceAction;
  final Widget? deletionStatus;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: CompassBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    (viewport.maxHeight * .10).clamp(30, 86),
                    24,
                    24,
                  ),
                  child: Column(
                    children: [
                      const Center(child: CompassWordmark(size: 26)),
                      const SizedBox(height: 24),
                      const Spacer(),
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              onPressed: onFindSchool,
                              child: const Text('Find Your School'),
                            ),
                            if (onRegisterSchool != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: onRegisterSchool,
                                child: const Text('Register'),
                              ),
                            ],
                            if (onSignIn != null)
                              TextButton(
                                onPressed: onSignIn,
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                child: const Text('Sign in'),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ?deletionStatus,
                      const CompassPolicyLinks(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
