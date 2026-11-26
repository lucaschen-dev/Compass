import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_ui.dart';

const compassPolicyBase =
    'https://github.com/lucaschen-dev/Compass/blob/main/docs';

Future<void> openCompassPolicy(BuildContext context, String document) async {
  final uri = Uri.parse('$compassPolicyBase/$document.md');
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep the URL available when the platform cannot open a browser.
  }
  if (context.mounted) {
    showAppError(context, 'Open $uri in a browser.');
  }
}

class CompassPolicyLinks extends StatelessWidget {
  const CompassPolicyLinks({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => openCompassPolicy(context, 'privacy'),
        child: const Text('Privacy policy'),
      ),
      TextButton(
        onPressed: () => openCompassPolicy(context, 'support'),
        child: const Text('Support'),
      ),
    ],
  );
}
