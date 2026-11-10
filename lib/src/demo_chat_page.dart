import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'community_models.dart';
import 'school_demo.dart';

class DemoChatPage extends StatefulWidget {
  const DemoChatPage({
    super.key,
    required this.community,
    required this.school,
    required this.friendIds,
    required this.onAddFriend,
  });
  final CommunityController community;
  final DemoSchool school;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;
  @override
  State<DemoChatPage> createState() => _DemoChatPageState();
}

class _DemoChatPageState extends State<DemoChatPage> {
  String _query = '', _filter = 'All';
  Future<void> _new() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NewChat(
      c: widget.community,
      onOpen: _open,
      onAddFriend: widget.onAddFriend,
    ),
  );
  void _open(ChatThread t) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage(c: widget.community, threadId: t.id),
      ),
    );
  }

  Future<void> _actions(ChatThread t) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in [
            (
              label: t.pinned ? 'Unpin' : 'Pin',
              icon: Icons.push_pin_outlined,
              value: 0,
            ),
            (
              label: t.archived ? 'Unarchive' : 'Archive',
              icon: Icons.archive_outlined,
              value: 1,
            ),
            (
              label: t.muted ? 'Unmute' : 'Mute',
              icon: Icons.notifications_off_outlined,
              value: 2,
            ),
            (
              label: t.unread > 0 ? 'Mark as read' : 'Mark as unread',
              icon: Icons.mark_chat_unread_outlined,
              value: 3,
            ),
          ])
            ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () {
                Navigator.pop(context);
                appSave(
                  this.context,
                  () => widget.community.updateThread(switch (action.value) {
                    0 => t.copyWith(pinned: !t.pinned),
                    1 => t.copyWith(archived: !t.archived),
                    2 => t.copyWith(muted: !t.muted),
                    _ => t.copyWith(unread: t.unread > 0 ? 0 : 1),
                  }),
                );
              },
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final threads =
        widget.community.threads
            .where(
              (t) =>
                  t.name.toLowerCase().contains(_query) &&
                  (_filter == 'Archived' ? t.archived : !t.archived) &&
                  (_filter != 'Unread' || t.unread > 0) &&
                  (_filter != 'Groups' || t.group),
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            final ad = a.messages.lastOrNull?.at ?? DateTime(2000),
                bd = b.messages.lastOrNull?.at ?? DateTime(2000);
            return bd.compareTo(ad);
          });
    return ContentColumn(
      children: [
        Row(
          children: [
            Text('Chat', style: Theme.of(context).textTheme.headlineLarge),
            const Spacer(),
            IconButton(
              tooltip: 'New chat',
              onPressed: _new,
              icon: const Icon(Icons.edit_square),
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search conversations',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in ['All', 'Unread', 'Groups', 'Archived'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (threads.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Text('No conversations here.'),
          ),
        for (final t in threads) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            leading: StudentAvatar(name: t.name),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (t.muted)
                  const Icon(Icons.notifications_off_outlined, size: 15),
                if (t.pinned) const Icon(Icons.push_pin_outlined, size: 15),
              ],
            ),
            subtitle: Text(
              t.draft.isNotEmpty
                  ? 'Draft: ${t.draft}'
                  : t.left
                  ? 'Conversation unavailable'
                  : t.messages.lastOrNull?.unsent == true
                  ? 'Message unsent'
                  : t.messages.lastOrNull?.photo != null
                  ? 'Photo'
                  : t.messages.lastOrNull?.text ?? 'Say hello',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  t.messages.lastOrNull == null
                      ? ''
                      : relativeTime(t.messages.last.at),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (t.unread > 0) ...[
                  const SizedBox(height: 6),
                  Badge(label: Text('${t.unread}')),
                ],
              ],
            ),
            onTap: () => _open(t),
            onLongPress: () => _actions(t),
          ),
          const Divider(),
        ],
      ],
    );
  }
}

class _NewChat extends StatefulWidget {
  const _NewChat({required this.c, required this.onOpen, this.onAddFriend});
  final CommunityController c;
  final ValueChanged<ChatThread> onOpen;
  final Future<void> Function(String)? onAddFriend;
  @override
  State<_NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<_NewChat> {
  String _query = '';
  bool _group = false, _busy = false;
  final _members = <String>{};
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create([DemoPerson? person]) async {
    if (_busy) return;
    final group = _group;
    final members = group ? _members.toList() : [person!.id];
    if (group && (_name.text.trim().isEmpty || members.length < 2)) {
      showAppError(context, 'Name the group and choose at least two people.');
      return;
    }
    final id = group ? 'group-${widget.c.newId()}' : 'direct-${person!.id}';
    final existing = widget.c.threads.where((t) => t.id == id).firstOrNull;
    final thread =
        existing ??
        ChatThread(
          id: id,
          name: group ? _name.text.trim() : person!.name,
          members: ['me', ...members],
          messages: [],
          group: group,
        );
    setState(() => _busy = true);
    try {
      if (person != null) await widget.onAddFriend?.call(person.id);
      if (existing == null) {
        await widget.c.change(
          () => widget.c.threads = [...widget.c.threads, thread],
        );
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onOpen(thread);
      }
    } catch (_) {
      if (mounted) {
        showAppError(context, 'Could not create the chat.');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                _group ? 'New group' : 'New chat',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _group = !_group),
                child: Text(_group ? 'Direct' : 'New group'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_group) ...[
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(hintText: 'Group name'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search people',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final person in widget.c.school.classmates.where(
                  (p) => p.name.toLowerCase().contains(_query),
                ))
                  ListTile(
                    leading: StudentAvatar(name: person.name),
                    title: Text(person.name),
                    subtitle: Text('Grade ${person.grade}'),
                    trailing: _group
                        ? Checkbox(
                            value: _members.contains(person.id),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? _members.add(person.id)
                                  : _members.remove(person.id),
                            ),
                          )
                        : null,
                    onTap: () => _group
                        ? setState(
                            () => _members.contains(person.id)
                                ? _members.remove(person.id)
                                : _members.add(person.id),
                          )
                        : _create(person),
                  ),
              ],
            ),
          ),
          if (_group)
            FilledButton(
              onPressed: _busy ? null : () => _create(),
              child: const Text('Create group'),
            ),
        ],
      ),
    ),
  );
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.c, required this.threadId});
  final CommunityController c;
  final String threadId;
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late final _text = TextEditingController(text: thread.draft);
  String? _replyTo, _photo;
  bool _busy = false;
  Timer? _draft;
  ChatThread get thread =>
      widget.c.threads.firstWhere((t) => t.id == widget.threadId);
  @override
  void initState() {
    super.initState();
    if (thread.unread > 0) {
      widget.c.patchThread(thread.id, unread: 0).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _draft?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _draftChanged(String value) {
    _draft?.cancel();
    _draft = Timer(const Duration(milliseconds: 500), () {
      widget.c.patchThread(thread.id, draft: value).catchError((_) {});
    });
  }

  Future<void> _send() async {
    if (_busy || (_text.text.trim().isEmpty && _photo == null)) return;
    _draft?.cancel();
    setState(() => _busy = true);
    try {
      await widget.c.send(
        thread.id,
        text: _text.text,
        replyTo: _replyTo,
        photo: _photo,
      );
      if (mounted) {
        setState(() {
          _text.clear();
          _replyTo = null;
          _photo = null;
        });
      }
    } catch (_) {
      if (mounted) showAppError(context, 'Could not save this message.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _modify(ChatMessage message, {String? text, String? reaction}) =>
      widget.c.change(
        () => widget.c.threads = [
          for (final t in widget.c.threads)
            if (t.id != thread.id)
              t
            else
              t.copyWith(
                messages: [
                  for (final m in t.messages)
                    if (m.id != message.id)
                      m
                    else
                      m.copyWith(
                        text: text,
                        edited: text != null ? true : null,
                        reaction: reaction,
                      ),
                ],
              ),
        ],
      );
  Future<void> _edit(ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 5,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && mounted) {
      await appSave(context, () => _modify(message, text: text));
    }
  }

  Future<void> _actions(ChatMessage message) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!message.unsent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final reaction in ['👍', '❤️', '😂', '🙏'])
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        appSave(
                          context,
                          () => _modify(
                            message,
                            reaction: message.reaction == reaction
                                ? ''
                                : reaction,
                          ),
                        );
                      },
                      child: Text(
                        reaction,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
              ),
            ),
          if (!message.unsent) ...[
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _replyTo = message.id);
              },
            ),
            if (message.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(sheetContext);
                },
              ),
            if (message.authorId == 'me')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _edit(message);
                },
              ),
            if (message.canUnsend(DateTime.now()))
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Unsend'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  appSave(
                    context,
                    () =>
                        widget.c.retract(thread.id, message.id, DateTime.now()),
                  );
                },
              ),
          ],
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete for me'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (await confirmAction(
                context,
                title: 'Delete this message for you?',
                action: 'Delete',
              )) {
                if (mounted) {
                  await appSave(
                    context,
                    () => widget.c.updateThread(
                      thread.copyWith(
                        messages: thread.messages
                            .where((m) => m.id != message.id)
                            .toList(),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
  Future<void> _info() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: StudentAvatar(name: thread.name, radius: 38)),
            const SizedBox(height: 18),
            Text(
              thread.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            for (final id in thread.members)
              ListTile(
                leading: StudentAvatar(name: widget.c.authorName(id)),
                title: Text(id == 'me' ? 'You' : widget.c.authorName(id)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(thread.muted ? 'Unmute' : 'Mute'),
              onTap: () {
                appSave(
                  this.context,
                  () => widget.c.updateThread(
                    thread.copyWith(muted: !thread.muted),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(thread.archived ? 'Unarchive' : 'Archive'),
              onTap: () {
                appSave(
                  this.context,
                  () => widget.c.updateThread(
                    thread.copyWith(archived: !thread.archived),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text(
                thread.group
                    ? (thread.left ? 'Group left' : 'Leave group')
                    : (thread.left ? 'Unblock' : 'Block contact'),
              ),
              onTap: () async {
                final leave = !thread.left;
                if (!leave ||
                    await confirmAction(
                      context,
                      title: thread.group
                          ? 'Leave this group?'
                          : 'Block this contact?',
                      action: thread.group ? 'Leave' : 'Block',
                    )) {
                  if (mounted && context.mounted) {
                    await appSave(
                      this.context,
                      () => widget.c.updateThread(thread.copyWith(left: leave)),
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) {
      final t = thread;
      final reply = t.messages.where((m) => m.id == _replyTo).firstOrNull;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: InkWell(
            onTap: _info,
            child: Row(
              children: [
                StudentAvatar(name: t.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Conversation info',
              onPressed: _info,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      itemCount: t.messages.length,
                      itemBuilder: (context, index) {
                        final m = t.messages[t.messages.length - 1 - index];
                        final own = m.authorId == 'me';
                        final quoted = t.messages
                            .where((v) => v.id == m.replyTo)
                            .firstOrNull;
                        final l10n = MaterialLocalizations.of(context);
                        return Align(
                          alignment: own
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width
                                      .clamp(0, 900) *
                                  .78,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: own
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onLongPress: () => _actions(m),
                                    onSecondaryTap: () => _actions(m),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: own
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (t.group && !own && !m.unsent)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Text(
                                                  widget.c.authorName(
                                                    m.authorId,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                              ),
                                            if (quoted != null && !m.unsent)
                                              _Quote(
                                                name: widget.c.authorName(
                                                  quoted.authorId,
                                                ),
                                                text: quoted.unsent
                                                    ? 'Message unsent'
                                                    : quoted.photo != null
                                                    ? 'Photo'
                                                    : quoted.text,
                                              ),
                                            if (m.photo != null && !m.unsent)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                      builder: (_) => Scaffold(
                                                        appBar: AppBar(),
                                                        body: InteractiveViewer(
                                                          child: Center(
                                                            child: Image.memory(
                                                              base64Decode(
                                                                m.photo!,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: Image.memory(
                                                      base64Decode(m.photo!),
                                                      width: 240,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (m.text.isNotEmpty || m.unsent)
                                              Text(
                                                m.unsent
                                                    ? 'Message unsent'
                                                    : m.text,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontStyle: m.unsent
                                                          ? FontStyle.italic
                                                          : null,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (m.reaction?.isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(m.reaction!),
                                        ),
                                      Text(
                                        '${m.edited ? 'Edited · ' : ''}${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(m.at))}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      IconButton(
                                        tooltip: 'Message actions',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                          minWidth: 26,
                                          minHeight: 26,
                                        ),
                                        padding: const EdgeInsets.only(left: 6),
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          size: 16,
                                        ),
                                        onPressed: () => _actions(m),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (t.left)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('This conversation is unavailable.'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Column(
                        children: [
                          if (reply != null)
                            Row(
                              children: [
                                Expanded(
                                  child: _Quote(
                                    name: widget.c.authorName(reply.authorId),
                                    text: reply.unsent
                                        ? 'Message unsent'
                                        : reply.photo != null
                                        ? 'Photo'
                                        : reply.text,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Cancel reply',
                                  onPressed: () =>
                                      setState(() => _replyTo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          if (_photo != null)
                            Row(
                              children: [
                                Image.memory(
                                  base64Decode(_photo!),
                                  height: 70,
                                  width: 70,
                                  fit: BoxFit.cover,
                                ),
                                IconButton(
                                  tooltip: 'Remove attachment',
                                  onPressed: () =>
                                      setState(() => _photo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Attach photo',
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        try {
                                          final photo = await choosePhoto();
                                          if (photo != null && mounted) {
                                            setState(() => _photo = photo);
                                          }
                                        } catch (e) {
                                          if (mounted && context.mounted) {
                                            showAppError(
                                              context,
                                              e is ArgumentError
                                                  ? e.message.toString()
                                                  : 'Could not read photo.',
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.add),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _text,
                                  onChanged: _draftChanged,
                                  minLines: 1,
                                  maxLines: 5,
                                  maxLength: 2000,
                                  decoration: const InputDecoration(
                                    hintText: 'Message',
                                    counterText: '',
                                  ),
                                  textInputAction: TextInputAction.newline,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Send message',
                                onPressed: _busy ? null : _send,
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Quote extends StatelessWidget {
  const _Quote({required this.name, required this.text});
  final String name, text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .55),
      border: Border(
        left: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.labelLarge),
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
