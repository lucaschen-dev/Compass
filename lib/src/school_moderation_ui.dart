import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'data/school_moderation.dart';

Future<void> showSchoolReport(
  BuildContext context,
  SchoolModeration moderation,
  SchoolReportTarget target,
) async {
  ReportReason? selected;
  final reason = await showDialog<ReportReason>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Report ${target.kind.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compass moderators will receive the reported content for review.',
              ),
              const SizedBox(height: 16),
              DropdownButton<ReportReason>(
                isExpanded: true,
                value: selected,
                hint: const Text('Choose a reason'),
                items: [
                  for (final reason in ReportReason.values)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => selected = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            child: const Text('Send report'),
          ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await moderation.report(target, reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Report sent to Compass moderators.')),
        );
    }
  } catch (_) {
    if (context.mounted) {
      showAppError(context, 'Could not send the report. Please try again.');
    }
  }
}

Future<void> confirmSchoolBlock(
  BuildContext context,
  SchoolModeration moderation,
  String uid,
  String displayName,
) async {
  final blocked = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $displayName?'),
      content: const Text(
        'Compass will hide this person’s posts and comments for you. '
        'You will no longer be able to message each other or send friend requests.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (blocked != true || !context.mounted) return;
  try {
    await moderation.block(uid, displayName);
  } catch (_) {
    if (context.mounted) {
      showAppError(context, 'Could not block this person. Please try again.');
    }
  }
}

class SchoolContentActions extends StatelessWidget {
  const SchoolContentActions({
    super.key,
    required this.moderation,
    required this.target,
    this.authorId,
    this.authorName,
  });

  final SchoolModeration moderation;
  final SchoolReportTarget target;
  final String? authorId, authorName;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip:
        '${target.kind.name[0].toUpperCase()}${target.kind.name.substring(1)} actions',
    padding: EdgeInsets.zero,
    onSelected: (value) {
      if (value == 'report') {
        showSchoolReport(context, moderation, target);
      } else if (authorId != null && authorName != null) {
        confirmSchoolBlock(context, moderation, authorId!, authorName!);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'report', child: Text('Report ${target.kind.name}')),
      if (authorId != null && authorName != null)
        const PopupMenuItem(value: 'block', child: Text('Block person')),
    ],
  );
}

Future<void> openBlockedPeople(
  BuildContext context,
  SchoolModeration moderation,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => _BlockedPeoplePage(moderation: moderation)),
);

class _BlockedPeoplePage extends StatelessWidget {
  const _BlockedPeoplePage({required this.moderation});
  final SchoolModeration moderation;

  Future<void> _unblock(
    BuildContext context,
    BlockedSchoolMember member,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Unblock ${member.displayName}?',
      action: 'Unblock',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await moderation.unblock(member.uid);
    } catch (_) {
      if (context.mounted) {
        showAppError(
          context,
          'Could not unblock this person. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked people')),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: moderation,
        builder: (context, _) {
          final people = moderation.blockedPeople;
          return ContentColumn(
            maxWidth: 560,
            children: [
              if (moderation.hasLoadError) ...[
                const Text('Could not refresh your blocked people.'),
                TextButton(
                  onPressed: moderation.refreshBlocks,
                  child: const Text('Try again'),
                ),
              ] else if (!moderation.hasLoadedBlocks)
                const Center(child: CircularProgressIndicator())
              else if (people.isEmpty)
                const Text('You haven’t blocked anyone at this school.'),
              for (final person in people)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(person.displayName),
                  trailing: TextButton(
                    onPressed: () => _unblock(context, person),
                    child: const Text('Unblock'),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
