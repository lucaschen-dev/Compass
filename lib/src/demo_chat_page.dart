import 'package:flutter/material.dart';

import 'school_demo.dart';

enum _ChatSection { messages, friends }

class DemoChatPage extends StatefulWidget {
  const DemoChatPage({
    super.key,
    required this.school,
    required this.friendIds,
    required this.onAddFriend,
  });

  final DemoSchool school;
  final Set<String> friendIds;
  final ValueChanged<String> onAddFriend;

  @override
  State<DemoChatPage> createState() => _DemoChatPageState();
}

class _DemoChatPageState extends State<DemoChatPage> {
  var _section = _ChatSection.messages;
  var _showClassmates = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          key: PageStorageKey((widget.school.id, _section)),
          padding: EdgeInsets.fromLTRB(
            wide ? 40 : 20,
            wide ? 48 : 28,
            wide ? 40 : 20,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.school.name.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      'Chat',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // https://api.flutter.dev/flutter/material/SegmentedButton-class.html
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<_ChatSection>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _ChatSection.messages,
                          label: Text('Messages'),
                        ),
                        ButtonSegment(
                          value: _ChatSection.friends,
                          label: Text('Friends'),
                        ),
                      ],
                      selected: {_section},
                      onSelectionChanged: (value) {
                        setState(() => _section = value.single);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_section == _ChatSection.messages)
                    _ConversationList(school: widget.school)
                  else
                    _FriendsList(
                      school: widget.school,
                      friendIds: widget.friendIds,
                      showClassmates: _showClassmates,
                      onToggleClassmates: () {
                        setState(() => _showClassmates = !_showClassmates);
                      },
                      onAddFriend: widget.onAddFriend,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.school});

  final DemoSchool school;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeading('Conversations'),
      const SizedBox(height: 8),
      for (final conversation in school.conversations)
        _ConversationTile(
          person: school.classmate(conversation.personId),
          studentId: school.student.id,
          conversation: conversation,
        ),
    ],
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.person,
    required this.studentId,
    required this.conversation,
  });

  final DemoPerson person;
  final String studentId;

  final DemoConversation conversation;

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.messages.last;
    return _ChatCard(
      child: ListTile(
        key: ValueKey('demo-conversation-${person.id}'),
        leading: _StudentAvatar(person: person),
        title: Text(person.name),
        subtitle: Text(
          lastMessage.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ConversationPage(
              person: person,
              studentId: studentId,
              conversation: conversation,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({
    required this.school,
    required this.friendIds,
    required this.showClassmates,
    required this.onToggleClassmates,
    required this.onAddFriend,
  });

  final DemoSchool school;
  final Set<String> friendIds;
  final bool showClassmates;
  final VoidCallback onToggleClassmates;
  final ValueChanged<String> onAddFriend;

  @override
  Widget build(BuildContext context) {
    final classmates = school.classmates.where(
      (person) => person.id != school.student.id,
    );
    final friends = classmates.where((person) => friendIds.contains(person.id));
    final available = classmates.where(
      (person) => !friendIds.contains(person.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            const _SectionHeading('Your friends'),
            FilledButton.tonalIcon(
              onPressed: onToggleClassmates,
              icon: Icon(
                showClassmates ? Icons.check_rounded : Icons.person_add_alt_1,
              ),
              label: Text(showClassmates ? 'Done' : 'Add friends'),
            ),
          ],
        ),
        if (showClassmates) ...[
          const SizedBox(height: 8),
          _ChatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeading('Classmates'),
                      if (available.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'You’ve added everyone in the classmate list.',
                        ),
                      ],
                    ],
                  ),
                ),
                for (final person in available)
                  _PersonTile(
                    key: ValueKey('demo-add-${person.id}'),
                    person: person,
                    trailing: TextButton(
                      onPressed: () => onAddFriend(person.id),
                      child: Text('Add', semanticsLabel: 'Add ${person.name}'),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (friends.isEmpty) const Text('Your friends will appear here.'),
        for (final person in friends)
          _ChatCard(
            child: _PersonTile(
              key: ValueKey('demo-friend-${person.id}'),
              person: person,
            ),
          ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({super.key, required this.person, this.trailing});

  final DemoPerson person;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _StudentAvatar(person: person),
    title: Text(person.name),
    subtitle: Text('Grade ${person.grade}'),
    trailing: trailing,
  );
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.person});

  final DemoPerson person;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Text(person.initials),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card.outlined(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 8),
    child: child,
  );
}

class _ConversationPage extends StatelessWidget {
  const _ConversationPage({
    required this.person,
    required this.studentId,
    required this.conversation,
  });

  final DemoPerson person;
  final String studentId;
  final DemoConversation conversation;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(person.name)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sample conversation',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 20),
                for (final message in conversation.messages) ...[
                  _MessageBubble(
                    message: message,
                    peerName: person.name,
                    outgoing: message.senderId == studentId,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.peerName,
    required this.outgoing,
  });

  final DemoMessage message;
  final String peerName;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = outgoing ? colors.onPrimaryContainer : colors.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .85),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: outgoing
                  ? colors.primaryContainer
                  : colors.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${outgoing ? 'You' : peerName} · ${message.time}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      height: 1.4,
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
}
