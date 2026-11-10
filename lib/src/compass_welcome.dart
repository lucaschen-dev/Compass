import 'package:flutter/material.dart';

import 'app_ui.dart';

class CompassWelcome extends StatelessWidget {
  const CompassWelcome({
    super.key,
    required this.onFindSchool,
    this.appearanceAction = const SizedBox.shrink(),
  });
  final VoidCallback onFindSchool;
  final Widget appearanceAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: (viewport.maxHeight * .10).clamp(36, 86),
                ),
                child: const CompassWordmark(size: 26),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: 320,
                  child: FilledButton(
                    onPressed: onFindSchool,
                    child: const Text('Find Your School'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
