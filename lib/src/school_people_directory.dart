import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'data/friend_repository.dart';
import 'data/school_moderation.dart';
import 'school_moderation_ui.dart';

Future<void> openSchoolPeopleDirectory(
  BuildContext context, {
  required String schoolName,
  required FriendRepository repository,
  SchoolModeration? moderation,
  void Function(BuildContext, String, String)? onOpenChat,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => SchoolPeopleDirectory(
      schoolName: schoolName,
      repository: repository,
      moderation: moderation,
      onOpenChat: onOpenChat,
    ),
  ),
);

enum _FriendView { people, requests, friends }

class SchoolPeopleDirectory extends StatefulWidget {
  const SchoolPeopleDirectory({
    super.key,
    required this.schoolName,
    required this.repository,
    this.moderation,
    this.onOpenChat,
  });

  final String schoolName;
  final FriendRepository repository;
  final SchoolModeration? moderation;
  final void Function(BuildContext, String, String)? onOpenChat;

  @override
  State<SchoolPeopleDirectory> createState() => _SchoolPeopleDirectoryState();
}

class _SchoolPeopleDirectoryState extends State<SchoolPeopleDirectory> {
  late Stream<List<SchoolDirectoryMember>> _directory;
  late Stream<List<SchoolFriendRequest>> _requests;
  final _working = <String>{};
  final _nameSearch = TextEditingController();
  _FriendView _view = _FriendView.people;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _directory = widget.repository.watchDirectory();
    _requests = widget.repository.watchRequests();
  }

  @override
  void dispose() {
    _nameSearch.dispose();
    super.dispose();
  }

  Future<void> _save(
    String uid,
    Future<void> Function() action,
    String errorMessage,
  ) async {
    if (_working.contains(uid)) return;
    setState(() => _working.add(uid));
    try {
      await action();
    } on FriendActionException catch (error) {
      if (mounted) showAppError(context, error.message);
    } catch (_) {
      if (mounted) showAppError(context, errorMessage);
    } finally {
      if (mounted) setState(() => _working.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends')),
    body: StreamBuilder<List<SchoolDirectoryMember>>(
      stream: _directory,
      builder: (context, directory) => StreamBuilder<List<SchoolFriendRequest>>(
        stream: _requests,
        builder: (context, requests) {
          if (directory.hasError || requests.hasError) {
            return ContentColumn(
              children: [
                const Text('Could not load friends. Check your connection.'),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(_listen),
                    child: const Text('Try again'),
                  ),
                ),
              ],
            );
          }
          if (directory.connectionState == ConnectionState.waiting ||
              requests.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: Listenable.merge([widget.moderation]),
            builder: (context, _) =>
                _content(directory.data ?? [], requests.data ?? []),
          );
        },
      ),
    ),
  );

  Widget _content(
    List<SchoolDirectoryMember> members,
    List<SchoolFriendRequest> requests,
  ) {
    final uid = widget.repository.uid;
    final moderation = widget.moderation;
    final people = {
      for (final member in members)
        if (moderation?.isBlocked(member.uid) != true) member.uid: member.name,
    };
    final byPerson = {
      for (final request in requests)
        if (moderation?.isBlocked(request.otherUid(uid)) != true)
          request.otherUid(uid): request,
    };
    String nameOf(String user) {
      final name = people[user] ?? byPerson[user]?.otherName(uid);
      if (name != null) return name;
      final suffix = user.length > 6 ? user.substring(user.length - 6) : user;
      return 'School member · $suffix';
    }

    int compareNames(String a, String b) =>
        nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());

    final matches =
        people.keys
            .where(
              (user) =>
                  user != uid && nameOf(user).toLowerCase().contains(_query),
            )
            .toList()
          ..sort(compareNames);
    final pending =
        byPerson.keys
            .where(
              (user) => byPerson[user]!.status == FriendRequestStatus.pending,
            )
            .toList()
          ..sort(compareNames);
    final incoming = pending.where((user) => byPerson[user]!.isIncoming(uid));
    final outgoing = pending.where((user) => !byPerson[user]!.isIncoming(uid));
    final friends =
        byPerson.keys
            .where(
              (user) => byPerson[user]!.status == FriendRequestStatus.accepted,
            )
            .toList()
          ..sort(compareNames);

    final children = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _viewChip(_FriendView.people, 'People'),
          _viewChip(
            _FriendView.requests,
            incoming.isEmpty ? 'Requests' : 'Requests (${incoming.length})',
          ),
          _viewChip(_FriendView.friends, 'Friends'),
        ],
      ),
      const SizedBox(height: 16),
      if (_view == _FriendView.people) ...[
        _peopleControls(listed: people.containsKey(uid)),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search by name',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (query) =>
              setState(() => _query = query.trim().toLowerCase()),
          controller: _nameSearch,
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          _empty(
            _query.isEmpty
                ? 'No other school members are listed yet.'
                : 'No one matches your search.',
          ),
        for (final user in matches)
          _PersonRow(
            name: nameOf(user),
            trailing: _peopleAction(user, byPerson[user]),
          ),
      ],
      if (_view == _FriendView.requests) ...[
        if (pending.isEmpty) _empty('No pending requests.'),
        if (incoming.isNotEmpty) ...[
          _section('Received'),
          for (final user in incoming)
            _PersonRow(
              name: nameOf(user),
              actions: [
                FilledButton(
                  onPressed: _working.contains(user)
                      ? null
                      : () => _respond(user, accept: true),
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: _working.contains(user)
                      ? null
                      : () => _respond(user, accept: false),
                  child: const Text('Decline'),
                ),
                if (moderation != null)
                  TextButton(
                    onPressed: () => confirmSchoolBlock(
                      context,
                      moderation,
                      user,
                      nameOf(user),
                    ),
                    child: const Text('Block person'),
                  ),
              ],
            ),
        ],
        if (outgoing.isNotEmpty) ...[
          _section('Sent'),
          for (final user in outgoing)
            _PersonRow(
              name: nameOf(user),
              subtitle: 'Waiting for acceptance',
              trailing: TextButton(
                onPressed: _working.contains(user)
                    ? null
                    : () => _save(
                        user,
                        () => widget.repository.cancelRequest(user),
                        'Could not cancel this request. Please try again.',
                      ),
                child: const Text('Cancel'),
              ),
            ),
        ],
      ],
      if (_view == _FriendView.friends) ...[
        if (friends.isEmpty) _empty('Accepted requests appear here.'),
        for (final user in friends)
          _PersonRow(
            name: nameOf(user),
            trailing: _chatButton(user, nameOf(user)),
            onTap: widget.onOpenChat == null
                ? null
                : () => widget.onOpenChat!(context, user, nameOf(user)),
          ),
      ],
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          key: ValueKey(_view),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    );
  }

  Widget _viewChip(_FriendView view, String label) => ChoiceChip(
    label: Text(label),
    selected: _view == view,
    onSelected: (_) => _select(view),
  );

  void _select(_FriendView view) {
    FocusScope.of(context).unfocus();
    setState(() => _view = view);
  }

  Widget _peopleControls({required bool listed}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Find people at ${widget.schoolName}.'),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: _addByCode,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add by code'),
          ),
          TextButton.icon(
            onPressed: _showMyCode,
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('My Compass code'),
          ),
        ],
      ),
      SwitchListTile(
        value: listed,
        contentPadding: EdgeInsets.zero,
        title: Text('Show my name in ${widget.schoolName} directory'),
        onChanged: _working.contains(widget.repository.uid)
            ? null
            : (publish) => _save(
                widget.repository.uid,
                publish
                    ? widget.repository.publishProfile
                    : widget.repository.hideProfile,
                'Could not update directory visibility. Please try again.',
              ),
      ),
      const SizedBox(height: 12),
    ],
  );

  Future<void> _showMyCode() async {
    final code = widget.repository.myCode;
    final copy = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Compass code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share with someone at ${widget.schoolName}.'),
            const SizedBox(height: 12),
            SelectableText(code),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy code'),
          ),
        ],
      ),
    );
    if (!mounted || copy != true) return;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Compass code copied.')));
      }
    } catch (_) {
      if (mounted) showAppError(context, 'Could not copy your Compass code.');
    }
  }

  Future<void> _addByCode() async {
    var code = '';
    final recipientUid = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, saveDialog) => AlertDialog(
          title: const Text('Add by code'),
          content: TextField(
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Compass code',
              errorText: code == widget.repository.myCode
                  ? 'Enter their code.'
                  : null,
            ),
            onChanged: (value) => saveDialog(() => code = value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: code.isEmpty || code == widget.repository.myCode
                  ? null
                  : () => Navigator.pop(dialogContext, code),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || recipientUid == null) return;
    await _save(recipientUid, () async {
      await widget.repository.sendRequest(recipientUid);
      if (mounted) _select(_FriendView.requests);
    }, 'Could not send a request. Check the code and school, then try again.');
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(text),
  );

  Widget _peopleAction(String uid, SchoolFriendRequest? request) {
    switch (request?.status) {
      case FriendRequestStatus.accepted:
        return const Text('Friend');
      case FriendRequestStatus.pending:
        return TextButton(
          onPressed: () => _select(_FriendView.requests),
          child: Text(
            request!.isIncoming(widget.repository.uid)
                ? 'View request'
                : 'Requested',
          ),
        );
      case FriendRequestStatus.declined:
        return const Text('Request closed');
      case FriendRequestStatus.canceled:
      case null:
        return TextButton(
          onPressed: _working.contains(uid)
              ? null
              : () => _save(
                  uid,
                  () => widget.repository.sendRequest(uid),
                  'Could not send a friend request. Please try again.',
                ),
          child: Text(_working.contains(uid) ? 'Sending…' : 'Send request'),
        );
    }
  }

  Widget? _chatButton(String uid, String name) {
    final open = widget.onOpenChat;
    if (open == null) return null;
    return IconButton(
      tooltip: 'Message $name',
      icon: const Icon(Icons.chat_bubble_outline),
      onPressed: () => open(context, uid, name),
    );
  }

  Future<void> _respond(String uid, {required bool accept}) => _save(
    uid,
    () => widget.repository.respondToRequest(uid, accept: accept),
    'Could not update this request. Please try again.',
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    this.subtitle,
    this.trailing,
    this.actions = const [],
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: StudentAvatar(name: name, radius: 19),
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
        onTap: onTap,
      ),
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 54, bottom: 8),
          child: Wrap(spacing: 8, runSpacing: 4, children: actions),
        ),
    ],
  );
}
