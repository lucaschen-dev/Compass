part of 'ui.dart';

Future<Json?> selectMember(BuildContext context, CampusStore store) async {
  final people = await store.members();
  if (!context.mounted) return null;
  return showDialog<Json>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('School members'),
      children: [
        if (people.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No members available.'),
          ),
        for (final p in people)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, p),
            child: ListTile(
              leading: avatar(p),
              title: Text(text(p, 'name')),
              subtitle: Text('${p['year']} · ${p['role']}'),
            ),
          ),
      ],
    ),
  );
}

class ChatsPage extends StatelessWidget {
  final CampusStore store;
  const ChatsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Chat',
              style: TextStyle(fontSize: 34, letterSpacing: -1),
            ),
          ),
          IconButton(
            tooltip: 'New conversation',
            onPressed: () => go(context, NewChatPage(store: store)),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (store.chats.isEmpty)
        empty(
          'Start a conversation with someone at school.',
          Icons.chat_outlined,
        ),
      for (final c in store.chats)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: avatar(
              c['kind'] == 'group' ? {'name': chatName(c)} : c['peer'] as Json,
            ),
            title: Text(chatName(c)),
            subtitle: Text(
              rows(c['messages']).isEmpty
                  ? 'No messages yet'
                  : messagePreview(rows(c['messages']).last),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(context, ChatPage(store: store, id: text(c, 'id'))),
          ),
        ),
      if (store.demo)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Demo conversations stay on this device and do not reach a real person.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
    ],
  );
}

class NewChatPage extends StatefulWidget {
  final CampusStore store;
  const NewChatPage({super.key, required this.store});
  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  late Future<List<Json>> data;
  bool group = false, busy = false;
  final title = TextEditingController();
  final selected = <String>{};
  @override
  void initState() {
    super.initState();
    data = widget.store.members();
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> start(Json? person, List<Json> people) async {
    if (busy) return;
    if (!mounted) return;
    setState(() => busy = true);
    await guard(context, () async {
      final chat = person == null
          ? await widget.store.createGroup(
              title.text,
              people.where((p) => selected.contains(p['id'])).toList(),
            )
          : await widget.store.startChat(person);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ChatPage(store: widget.store, id: text(chat, 'id')),
          ),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New conversation')),
    body: FutureBuilder<List<Json>>(
      future: data,
      builder: (context, s) {
        if (s.hasError) {
          return PageBody(
            children: [
              Text(s.error.toString()),
              TextButton(
                onPressed: () => setState(() => data = widget.store.members()),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return PageBody(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create a group'),
              value: group,
              onChanged: busy ? null : (v) => setState(() => group = v),
            ),
            if (group) field(title, 'Group name', limit: 60),
            for (final p in s.data!)
              group
                  ? CheckboxListTile(
                      value: selected.contains(p['id']),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                selected.add(text(p, 'id'));
                              } else {
                                selected.remove(p['id']);
                              }
                            }),
                      title: Text(text(p, 'name')),
                      subtitle: Text(text(p, 'year')),
                    )
                  : ListTile(
                      leading: avatar(p),
                      title: Text(text(p, 'name')),
                      subtitle: Text('${p['year']} · ${p['role']}'),
                      onTap: busy ? null : () => start(p, s.data!),
                    ),
            if (group)
              FilledButton(
                onPressed: busy ? null : () => start(null, s.data!),
                child: Text(busy ? 'Creating…' : 'Create group'),
              ),
          ],
        );
      },
    ),
  );
}

class ChatPage extends StatefulWidget {
  final CampusStore store;
  final String id;
  const ChatPage({super.key, required this.store, required this.id});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final message = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;
  Json? replying;
  String? mediaID, mediaKind;
  @override
  void dispose() {
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> attach() async {
    if (widget.store.demo) {
      toast(context, 'Media messages need a school account.');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov'],
    );
    if (result.isEmpty || !mounted) return;
    final file = result.first;
    if ((await file.length() ?? 0) > 15 * 1024 * 1024) {
      if (mounted) {
        toast(context, 'Choose a photo or short video smaller than 15 MB.');
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await guard(context, () async {
      final video = ['mp4', 'mov'].contains(file.extension?.toLowerCase());
      var bytes = await file.readAsBytes();
      if (!video) bytes = await compute(preparePhoto, bytes);
      final id = await widget.store.uploadMedia(
        widget.id,
        bytes,
        video ? 'video' : 'photo',
      );
      if (mounted) {
        setState(() {
          mediaID = id;
          mediaKind = video ? 'video' : 'photo';
        });
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> send() async {
    if (!mounted) return;
    setState(() => busy = true);
    await guard(context, () async {
      await widget.store.send(
        widget.id,
        message.text.trim(),
        replyID: replying?['id'] as String?,
        mediaID: mediaID,
        mediaKind: mediaKind,
      );
      message.clear();
      if (mounted) {
        setState(() {
          replying = null;
          mediaID = null;
          mediaKind = null;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final c = widget.store.chats
          .where((c) => c['id'] == widget.id)
          .firstOrNull;
      if (c == null) {
        return Scaffold(
          appBar: AppBar(),
          body: empty('Conversation unavailable.', Icons.chat_outlined),
        );
      }
      final messages = rows(c['messages']);
      return Scaffold(
        appBar: AppBar(
          title: Text(chatName(c)),
          actions: [
            IconButton(
              tooltip: 'Conversation info',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(chatName(c)),
                  content: SizedBox(
                    width: 360,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p
                            in rows(c['participants']).isEmpty
                                ? [c['peer'] as Json]
                                : rows(c['participants']))
                          ListTile(
                            leading: avatar(p),
                            title: Text(text(p, 'name')),
                            onTap: () => go(
                              context,
                              MemberPage(store: widget.store, person: p),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Close'),
                    ),
                    if (c['kind'] == 'group')
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => guard(context, () async {
                                if (await confirm(
                                  context,
                                  'Leave this group?',
                                )) {
                                  await widget.store.leave(widget.id);
                                  if (d.mounted) Navigator.pop(d);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              }),
                        child: const Text('Leave group'),
                      ),
                  ],
                ),
              ),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(18),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i],
                          mine = m['senderID'] == widget.store.me['id'];
                      final ref = messages
                          .where((other) => other['id'] == m['replyID'])
                          .firstOrNull;
                      final sender = rows(c['participants'])
                          .where((p) => p['id'] == m['senderID'])
                          .firstOrNull;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Card(
                            color: mine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        mine
                                            ? 'You'
                                            : sender == null
                                            ? chatName(c)
                                            : text(sender, 'name'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Message actions',
                                        onSelected: (v) {
                                          if (v == 'reply') {
                                            setState(() => replying = m);
                                          }
                                          if (v == 'unsend') {
                                            guard(context, () async {
                                              if (await confirm(
                                                context,
                                                'Unsend this message?',
                                              )) {
                                                await widget.store.retract(
                                                  widget.id,
                                                  text(m, 'id'),
                                                );
                                              }
                                            });
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (m['retracted'] != true)
                                            const PopupMenuItem(
                                              value: 'reply',
                                              child: Text('Reply'),
                                            ),
                                          if (mine && m['retracted'] != true)
                                            const PopupMenuItem(
                                              value: 'unsend',
                                              child: Text('Unsend'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (ref != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        messagePreview(ref),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  if (m['retracted'] == true)
                                    const Text(
                                      'Message unsent',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else ...[
                                    if (text(m, 'body').isNotEmpty)
                                      SelectableText(text(m, 'body')),
                                    if (m['mediaID'] != null)
                                      TextButton.icon(
                                        onPressed: () => go(
                                          context,
                                          MediaPage(
                                            store: widget.store,
                                            id: text(m, 'mediaID'),
                                          ),
                                        ),
                                        icon: Icon(
                                          m['mediaKind'] == 'video'
                                              ? Icons.play_circle_outline
                                              : Icons.photo_outlined,
                                        ),
                                        label: Text(
                                          m['mediaKind'] == 'video'
                                              ? 'Play video'
                                              : 'View photo',
                                        ),
                                      ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    stamp(m['createdAt']),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (replying != null)
                  ListTile(
                    dense: true,
                    title: Text(
                      'Replying to: ${messagePreview(replying!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      onPressed: () => setState(() => replying = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                if (mediaID != null)
                  ListTile(
                    dense: true,
                    title: Text('$mediaKind ready'),
                    trailing: IconButton(
                      onPressed: () => setState(() => mediaID = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Attach photo or video',
                          onPressed: busy ? null : attach,
                          icon: const Icon(Icons.attach_file),
                        ),
                        Expanded(
                          child: TextField(
                            controller: message,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              counterText: '',
                            ),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Send message',
                          onPressed: busy ? null : send,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class MediaPage extends StatefulWidget {
  final CampusStore store;
  final String id;
  const MediaPage({super.key, required this.store, required this.id});
  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  late Future<Json> data;
  Player? player;
  VideoController? video;
  String? videoError;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Json> load() async {
    final result = await widget.store.media(widget.id);
    if (result['kind'] == 'video') {
      player = Player();
      video = VideoController(player!);
      try {
        await player!.open(
          await Media.memory(base64Decode(text(result, 'data'))),
        );
      } catch (_) {
        videoError = 'This video could not be played.';
      }
    }
    return result;
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Attachment')),
    body: FutureBuilder<Json>(
      future: data,
      builder: (context, s) {
        if (s.hasError) {
          return empty('Media unavailable.', Icons.broken_image_outlined);
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (videoError != null) return empty(videoError!, Icons.error_outline);
        if (video != null) return Video(controller: video!);
        return Center(
          child: InteractiveViewer(
            child: Image.memory(base64Decode(text(s.data!, 'data'))),
          ),
        );
      },
    ),
  );
}
