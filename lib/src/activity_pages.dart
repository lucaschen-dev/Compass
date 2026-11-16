import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'community_models.dart';
import 'demo_activities.dart';
import 'school_demo.dart';

DemoActivity spotlightActivity(List<DemoActivity> activities, String schoolId) {
  if (activities.isEmpty) {
    throw StateError('No activities available for $schoolId');
  }
  final index = schoolId.codeUnits.fold<int>(0, (a, b) => a + b) %
      activities.length;
  return activities[index];
}

Future<void> openActivityDirectory(
  BuildContext context, {
  required DemoSchool school,
  required CommunityController community,
  required Set<String> friendIds,
  required Future<void> Function(String) onAddFriend,
  required bool clubs,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ActivityDirectoryPage(
        school: school,
        community: community,
        friendIds: friendIds,
        onAddFriend: onAddFriend,
        clubs: clubs,
      ),
    ),
  );
}

Future<void> openActivityDetail(
  BuildContext context, {
  required DemoSchool school,
  required CommunityController community,
  required DemoActivity activity,
  required Set<String> friendIds,
  required Future<void> Function(String) onAddFriend,
  required bool club,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => club
          ? ClubDetailPage(
              school: school,
              community: community,
              club: activity,
              friendIds: friendIds,
              onAddFriend: onAddFriend,
            )
          : EventDetailPage(school: school, event: activity),
    ),
  );
}

class ActivityDirectoryPage extends StatefulWidget {
  const ActivityDirectoryPage({
    super.key,
    required this.school,
    required this.community,
    required this.friendIds,
    required this.onAddFriend,
    required this.clubs,
  });

  final DemoSchool school;
  final CommunityController community;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;
  final bool clubs;

  @override
  State<ActivityDirectoryPage> createState() => _ActivityDirectoryPageState();
}

class _ActivityDirectoryPageState extends State<ActivityDirectoryPage> {
  var _query = '';
  String? _interest;
  MeetupTime? _meetup;

  List<DemoActivity> get _all =>
      widget.clubs ? widget.school.clubs : widget.school.events;

  List<String> get _interests =>
      ({for (final item in _all) ...item.interests}.toList()..sort());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _all.where((item) {
      final haystack =
          '${item.title} ${item.description} ${item.location} ${item.when}'
              .toLowerCase();
      if (_query.isNotEmpty && !haystack.contains(_query)) return false;
      if (_interest != null && !item.interests.contains(_interest)) {
        return false;
      }
      if (_meetup != null &&
          _meetup != MeetupTime.any &&
          item.meetupTime != _meetup) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.clubs ? 'All clubs' : 'All events')),
      body: ContentColumn(
        children: [
          TextField(
            key: ValueKey(widget.clubs ? 'club-search' : 'event-search'),
            decoration: InputDecoration(
              hintText: widget.clubs ? 'Search clubs' : 'Search events',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Any interest'),
                    selected: _interest == null,
                    onSelected: (_) => setState(() => _interest = null),
                  ),
                ),
                for (final interest in _interests)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(interest),
                      selected: _interest == interest,
                      onSelected: (_) => setState(
                        () => _interest = _interest == interest
                            ? null
                            : interest,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final time in MeetupTime.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(time.label),
                      selected: (_meetup ?? MeetupTime.any) == time,
                      onSelected: (_) => setState(
                        () => _meetup = time == MeetupTime.any ? null : time,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                widget.clubs
                    ? 'No clubs match yet.'
                    : 'No events match yet.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          for (final item in filtered)
            Card(
              key: ValueKey('directory-${item.id}'),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text('${item.when}\n${item.location}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openActivityDetail(
                  context,
                  school: widget.school,
                  community: widget.community,
                  activity: item,
                  friendIds: widget.friendIds,
                  onAddFriend: widget.onAddFriend,
                  club: widget.clubs,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ClubDetailPage extends StatelessWidget {
  const ClubDetailPage({
    super.key,
    required this.school,
    required this.community,
    required this.club,
    required this.friendIds,
    required this.onAddFriend,
  });

  final DemoSchool school;
  final CommunityController community;
  final DemoActivity club;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;

  DemoPerson? _person(String id) =>
      school.classmates.where((person) => person.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final applied = community.clubApplies.contains(club.id);
        final leaders = [
          for (final id in club.leaderIds)
            if (_person(id) != null) _person(id)!,
        ];
        final members = [
          for (final id in club.memberIds)
            if (_person(id) != null) _person(id)!,
        ];
        return Scaffold(
          appBar: AppBar(title: Text(club.title)),
          body: ContentColumn(
            children: [
              Text(club.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${club.when} · ${club.location}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(club.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interest in club.interests)
                    Chip(label: Text(interest)),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: ValueKey('club-apply-${club.id}'),
                onPressed: () => appSave(
                  context,
                  () => community.toggleClubApply(club.id),
                ),
                child: Text(applied ? 'Cancel application' : 'Apply to join'),
              ),
              if (applied) ...[
                const SizedBox(height: 8),
                Text(
                  'Your application is saved on this device for ${school.name}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('Leaders', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (leaders.isEmpty)
                const Text('No leaders listed yet.')
              else
                for (final person in leaders)
                  _MemberTile(
                    person: person,
                    role: 'Leader',
                    friendIds: friendIds,
                    onAddFriend: onAddFriend,
                  ),
              const SizedBox(height: 24),
              Text('Members', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const Text('No members listed yet.')
              else
                for (final person in members)
                  _MemberTile(
                    person: person,
                    role: club.leaderIds.contains(person.id)
                        ? 'Leader'
                        : 'Member',
                    friendIds: friendIds,
                    onAddFriend: onAddFriend,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.school, required this.event});

  final DemoSchool school;
  final DemoActivity event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: ContentColumn(
        children: [
          Text(event.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '${event.when} · ${event.location}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            school.name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(event.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in event.interests) Chip(label: Text(interest)),
              Chip(label: Text(event.meetupTime.label)),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivitySpotlightCard extends StatelessWidget {
  const ActivitySpotlightCard({
    super.key,
    required this.title,
    required this.activity,
    required this.allLabel,
    required this.onOpenAll,
    required this.onOpenActivity,
  });

  final String title;
  final DemoActivity activity;
  final String allLabel;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            TextButton(
              key: ValueKey('open-$allLabel'),
              onPressed: onOpenAll,
              child: Text(allLabel),
            ),
          ],
        ),
        Card(
          key: ValueKey('spotlight-${activity.id}'),
          child: ListTile(
            title: Text(activity.title),
            subtitle: Text('${activity.when}\n${activity.location}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenActivity,
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.person,
    required this.role,
    required this.friendIds,
    required this.onAddFriend,
  });

  final DemoPerson person;
  final String role;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;

  @override
  Widget build(BuildContext context) {
    final isFriend = friendIds.contains(person.id);
    return ListTile(
      key: ValueKey('member-${person.id}'),
      contentPadding: EdgeInsets.zero,
      leading: StudentAvatar(name: person.name),
      title: Text(person.name),
      subtitle: Text('Grade ${person.grade} · $role'),
      trailing: isFriend
          ? const Text('Friends')
          : TextButton(
              key: ValueKey('friend-${person.id}'),
              onPressed: () => appSave(context, () async {
                await onAddFriend(person.id);
              }),
              child: const Text('Add friend'),
            ),
    );
  }
}
