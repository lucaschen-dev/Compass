import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'data/friend_repository.dart';
import 'data/school_chat_repository.dart';
import 'data/school_moderation.dart';
import 'school_moderation_ui.dart';

class SchoolChatPage extends StatefulWidget {
  const SchoolChatPage({
    super.key,
    required this.friends,
    required this.chat,
    required this.onAddFriend,
    this.moderation,
  });

  final FriendRepository friends;
  final SchoolChatRepository chat;
  final VoidCallback onAddFriend;
  final SchoolModeration? moderation;

  @override
  State<SchoolChatPage> createState() => _SchoolChatPageState();
}

class _SchoolChatPageState extends State<SchoolChatPage> {
  late Stream<List<SchoolFriendRequest>> _requests;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _requests = widget.friends.watchRequests();
  }

  @override
  void didUpdateWidget(SchoolChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friends != widget.friends) {
      _requests = widget.friends.watchRequests();
      _query = '';
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.moderation]),
    builder: (context, _) => _buildChat(context),
  );

  Widget _buildChat(
    BuildContext context,
  ) => StreamBuilder<List<SchoolFriendRequest>>(
    stream: _requests,
    builder: (context, snapshot) {
      final uid = widget.friends.uid;
      final requests = snapshot.connectionState == ConnectionState.waiting
          ? const <SchoolFriendRequest>[]
          : (snapshot.data ?? [])
                .where(
                  (request) =>
                      widget.moderation?.isBlocked(request.otherUid(uid)) !=
                      true,
                )
                .toList();
      final incoming = requests
          .where(
            (request) =>
                request.isIncoming(uid) &&
                request.status == FriendRequestStatus.pending,
          )
          .length;
      final accepted = [
        for (final request in requests)
          if (request.status == FriendRequestStatus.accepted)
            (
              id: request.otherUid(uid),
              name: request.otherName(uid) ?? 'School member',
            ),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final visible = accepted.where(
        (friend) => friend.name.toLowerCase().contains(_query),
      );
      return ContentColumn(
        maxWidth: 680,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chat',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              TextButton.icon(
                onPressed: widget.onAddFriend,
                icon: Badge.count(
                  count: incoming,
                  isLabelVisible: incoming > 0,
                  child: const Icon(Icons.person_add_outlined, size: 20),
                ),
                label: const Text('Add friend'),
              ),
              if (widget.moderation case final moderation?)
                IconButton(
                  tooltip: 'Blocked people',
                  icon: const Icon(Icons.block_outlined),
                  onPressed: () => openBlockedPeople(context, moderation),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (snapshot.hasError)
            _ConversationStatus(
              message: 'Could not load your friends.',
              onRetry: () =>
                  setState(() => _requests = widget.friends.watchRequests()),
            )
          else if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (accepted.isEmpty)
            const _ConversationStatus(
              message: 'Your friends appear here after accepting a request.',
            )
          else ...[
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search friends',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const _ConversationStatus(
                message: 'No friends match your search.',
              ),
            for (final friend in visible)
              ListTile(
                key: ValueKey(friend.id),
                contentPadding: EdgeInsets.zero,
                leading: StudentAvatar(name: friend.name, radius: 21),
                title: Text(friend.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSchoolConversation(
                  context,
                  chat: widget.chat,
                  peerId: friend.id,
                  peerName: friend.name,
                  moderation: widget.moderation,
                ),
              ),
          ],
        ],
      );
    },
  );
}

Future<void> openSchoolConversation(
  BuildContext context, {
  required SchoolChatRepository chat,
  required String peerId,
  required String peerName,
  SchoolModeration? moderation,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _SchoolConversationPage(
      chat: chat,
      peerId: peerId,
      peerName: peerName,
      moderation: moderation,
    ),
  ),
);

class _SchoolConversationPage extends StatefulWidget {
  const _SchoolConversationPage({
    required this.chat,
    required this.peerId,
    required this.peerName,
    this.moderation,
  });

  final SchoolChatRepository chat;
  final String peerId;
  final String peerName;
  final SchoolModeration? moderation;

  @override
  State<_SchoolConversationPage> createState() =>
      _SchoolConversationPageState();
}

class _SchoolConversationPageState extends State<_SchoolConversationPage> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _history = <String, SchoolChatMessage>{};
  late Stream<List<SchoolChatMessage>> _messages;
  ({String id, String text})? _lastAttempt;
  bool _sending = false;
  bool _loadingEarlier = false;
  bool _hasEarlier = true;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _messages = widget.chat.watchMessages(widget.peerId).map((messages) {
      if (_history.isNotEmpty) {
        _history.addEntries(
          messages.map((message) => MapEntry(message.id, message)),
        );
      }
      return messages;
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _composing =>
      _draft.value.isComposingRangeValid && !_draft.value.composing.isCollapsed;

  bool get _blocked => widget.moderation?.isBlocked(widget.peerId) ?? false;

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (_blocked || _sending || _composing || text.isEmpty) return;
    if (widget.moderation != null && !communityTextAllowed(text)) {
      showAppError(context, communityTextWarning);
      return;
    }
    if (text.length > schoolChatMessageLimit) {
      showAppError(context, 'Please shorten this message before sending.');
      return;
    }
    setState(() => _sending = true);
    try {
      final lastAttempt = _lastAttempt;
      final attempt = lastAttempt?.text == text
          ? lastAttempt!
          : (id: widget.chat.createMessageId(), text: text);
      _lastAttempt = attempt;
      await widget.chat.sendMessage(
        widget.peerId,
        messageId: attempt.id,
        text: text,
      );
      if (!mounted) return;
      _lastAttempt = null;
      if (_draft.text.trim() == text) _draft.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on SchoolChatActionException catch (error) {
      if (mounted) showAppError(context, error.message);
    } catch (_) {
      if (mounted) {
        showAppError(context, 'Could not send. Your draft is still here.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  KeyEventResult _enter(FocusNode _, KeyEvent event) {
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || _composing) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      _insertLineBreak();
    } else {
      unawaited(_send());
    }
    return KeyEventResult.handled;
  }

  void _insertLineBreak() {
    final value = _draft.value;
    final selection = value.selection;
    final end = selection.isValid ? selection.end : value.text.length;
    final start = selection.isValid ? selection.start : end;
    final text = value.text.replaceRange(start, end, '\n');
    if (text.length <= schoolChatMessageLimit) {
      _draft.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start + 1),
      );
    }
  }

  Future<void> _loadEarlier(List<SchoolChatMessage> visible) async {
    if (_loadingEarlier) return;
    setState(() => _loadingEarlier = true);
    try {
      final earlier = await widget.chat.loadOlderMessages(
        widget.peerId,
        visible.first,
      );
      if (!mounted) return;
      setState(() {
        _history.addEntries(
          [
            ...earlier,
            ...visible,
          ].map((message) => MapEntry(message.id, message)),
        );
        _hasEarlier = earlier.length >= schoolChatMessagePageSize;
      });
    } catch (_) {
      if (mounted) showAppError(context, 'Could not load earlier messages.');
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.moderation]),
    builder: (context, _) => _conversation(context),
  );

  Widget _conversation(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.peerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (widget.moderation case final moderation?)
          PopupMenuButton<String>(
            tooltip: 'Conversation actions',
            onSelected: (value) {
              if (value == 'manage') {
                openBlockedPeople(context, moderation);
              } else {
                confirmSchoolBlock(
                  context,
                  moderation,
                  widget.peerId,
                  widget.peerName,
                );
              }
            },
            itemBuilder: (_) => [
              if (_blocked)
                const PopupMenuItem(
                  value: 'manage',
                  child: Text('Manage blocked people'),
                )
              else
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block person'),
                ),
            ],
          ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: StreamBuilder<List<SchoolChatMessage>>(
            stream: _messages,
            builder: (context, snapshot) {
              final latest = snapshot.data;
              if (snapshot.hasError) {
                return _ConversationStatus(
                  message: 'Could not load this conversation.',
                  onRetry: () => setState(_listen),
                );
              }
              if (latest == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = _history.isEmpty
                  ? latest
                  : ({
                      ..._history,
                      for (final message in latest) message.id: message,
                    }.values.toList()..sort(_compareMessages));
              final canLoadEarlier =
                  _hasEarlier && latest.length >= schoolChatMessagePageSize;
              return Column(
                children: [
                  Expanded(
                    child: messages.isEmpty
                        ? const _ConversationStatus(message: 'No messages yet.')
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount:
                                messages.length + (canLoadEarlier ? 1 : 0),
                            findChildIndexCallback: (key) {
                              final index = messages.indexWhere(
                                (message) => key == ValueKey(message.id),
                              );
                              return index < 0
                                  ? null
                                  : messages.length - 1 - index;
                            },
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return Center(
                                  child: TextButton(
                                    onPressed: _loadingEarlier
                                        ? null
                                        : () => _loadEarlier(messages),
                                    child: Text(
                                      _loadingEarlier
                                          ? 'Loading earlier messages…'
                                          : 'Load earlier messages',
                                    ),
                                  ),
                                );
                              }
                              final message =
                                  messages[messages.length - 1 - index];
                              return _MessageBubble(
                                key: ValueKey(message.id),
                                message: message,
                                own: message.senderId == widget.chat.uid,
                                actions:
                                    message.senderId != widget.chat.uid &&
                                        widget.moderation != null
                                    ? SchoolContentActions(
                                        moderation: widget.moderation!,
                                        target: SchoolReportTarget.message(
                                          widget.chat.uid,
                                          widget.peerId,
                                          message.id,
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                  if (_blocked)
                    const _ConversationStatus(
                      message: 'Unblock this person to send messages.',
                    )
                  else
                    _composer(),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _enter,
            child: TextField(
              controller: _draft,
              maxLength: schoolChatMessageLimit,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onEditingComplete: () {},
              onSubmitted: (_) => unawaited(_send()),
              decoration: const InputDecoration(
                hintText: 'Message',
                counterText: '',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder(
          valueListenable: _draft,
          builder: (context, value, _) => IconButton.filled(
            tooltip: 'Send message',
            onPressed: _sending || value.text.trim().isEmpty ? null : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ),
      ],
    ),
  );
}

int _compareMessages(SchoolChatMessage a, SchoolChatMessage b) {
  final time = a.createdAt.compareTo(b.createdAt);
  return time == 0 ? a.id.compareTo(b.id) : time;
}

class _ConversationStatus extends StatelessWidget {
  const _ConversationStatus({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry case final retry?)
            TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.own,
    this.actions,
  });

  final SchoolChatMessage message;
  final bool own;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final date = message.createdAt.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: own
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: .85,
        alignment: own
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: own ? colors.primaryContainer : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.text),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    ?actions,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
