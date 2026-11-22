import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'community_models.dart';
import 'school_demo.dart';

/// Opens the same school directory from Chat and from new-student shortcuts.
Future<void> openSchoolFriendDirectory(
  BuildContext context, {
  required DemoSchool school,
  required Set<String> friendIds,
  required Future<void> Function(String) onAddFriend,
  bool Function(String personId)? isBlocked,
  Future<void> Function(DemoPerson)? onMessage,
}) async {
  final person = await Navigator.of(context).push<DemoPerson>(
    MaterialPageRoute(
      builder: (_) => _SchoolFriendDirectory(
        school: school,
        friendIds: friendIds,
        onAddFriend: onAddFriend,
        isBlocked: isBlocked,
        canMessage: onMessage != null,
      ),
    ),
  );
  if (person != null && onMessage != null && context.mounted) {
    await appSave(context, () => onMessage(person));
  }
}

class _SchoolFriendDirectory extends StatefulWidget {
  const _SchoolFriendDirectory({
    required this.school,
    required this.friendIds,
    required this.onAddFriend,
    required this.isBlocked,
    required this.canMessage,
  });

  final DemoSchool school;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;
  final bool Function(String)? isBlocked;
  final bool canMessage;

  @override
  State<_SchoolFriendDirectory> createState() => _SchoolFriendDirectoryState();
}

class _SchoolFriendDirectoryState extends State<_SchoolFriendDirectory> {
  final _adding = <String>{};
  String _query = '';

  Future<void> _add(DemoPerson person) async {
    setState(() => _adding.add(person.id));
    try {
      await widget.onAddFriend(person.id);
    } catch (_) {
      if (mounted) showAppError(context, 'Could not add ${person.name}.');
    } finally {
      if (mounted) setState(() => _adding.remove(person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final classmates = widget.school.classmates.where((person) {
      final details = '${person.name} grade ${person.grade}';
      return details.toLowerCase().contains(_query);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Add friend')),
      body: ContentColumn(
        children: [
          Text(
            'Explore sample classmates at ${shortSchoolName(widget.school)}. '
            'Added friends stay in your Compass account.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search classmates',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (query) =>
                setState(() => _query = query.trim().toLowerCase()),
          ),
          const SizedBox(height: 14),
          if (classmates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No classmates match your search.'),
            ),
          for (final person in classmates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: StudentAvatar(name: person.name, radius: 19),
              title: Text(person.name),
              subtitle: Text('Grade ${person.grade}'),
              trailing: _friendAction(person),
            ),
        ],
      ),
    );
  }

  Widget _friendAction(DemoPerson person) {
    if (widget.isBlocked?.call(person.id) == true) return const Text('Blocked');
    if (widget.friendIds.contains(person.id)) {
      return widget.canMessage
          ? TextButton(
              onPressed: () => Navigator.pop(context, person),
              child: const Text('Message'),
            )
          : const Text('Added');
    }
    return TextButton(
      onPressed: _adding.contains(person.id) ? null : () => _add(person),
      child: Text(_adding.contains(person.id) ? 'Adding…' : 'Add friend'),
    );
  }
}

bool isBlockedClassmate(CommunityController community, String personId) =>
    community.threads.any(
      (thread) =>
          !thread.group && thread.left && thread.members.contains(personId),
    );
