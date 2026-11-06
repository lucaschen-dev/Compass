part of 'ui.dart';

class FeedPage extends StatefulWidget {
  final CampusStore store;
  const FeedPage({super.key, required this.store});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String filter = 'All', query = '';
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final visible = s.posts
        .where(
          (p) =>
              (filter == 'All' ||
                  filter == 'Saved' && s.saved.contains(p['id']) ||
                  kindLabel(text(p, 'kind')) == filter) &&
              ('${p['title']} ${p['body']}').toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final pinned = visible
        .where(
          (p) =>
              p['important'] == true ||
              ((p['requestedAnswerUntil'] as num? ?? 0) >
                  DateTime.now().millisecondsSinceEpoch / 1000),
        )
        .toList();
    final feed = visible
        .where((p) => !pinned.any((v) => v['id'] == p['id']))
        .toList();
    return PageBody(
      children: [
        const Text('Home', style: TextStyle(fontSize: 34, letterSpacing: -1)),
        if (s.admin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Administrator'),
              subtitle: Text('${s.snapshot?['openReports'] ?? 0} open reports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => go(context, AdminPage(store: s)),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('My posts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(context, MyPostsPage(store: s)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Search campus posts',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ['All', ...kinds.values, 'Saved'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: filter == f,
                    onSelected: (_) => setState(() => filter = f),
                  ),
                ),
            ],
          ),
        ),
        section('Important'),
        if (pinned.isEmpty)
          const Text(
            'No important posts right now.',
            style: TextStyle(color: Colors.grey),
          ),
        for (final p in pinned) PostTile(store: s, post: p, pinned: true),
        section(filter == 'All' ? 'Latest posts' : filter),
        if (feed.isEmpty)
          empty(
            'No posts here yet. Use + to start a conversation.',
            Icons.forum_outlined,
          ),
        for (final p in feed) PostTile(store: s, post: p),
      ],
    );
  }
}

class PostTile extends StatelessWidget {
  final CampusStore store;
  final Json post;
  final bool pinned;
  const PostTile({
    super.key,
    required this.store,
    required this.post,
    this.pinned = false,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => go(context, PostPage(store: store, id: text(post, 'id'))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.push_pin_outlined, size: 17),
                  ),
                Expanded(
                  child: Text(
                    kindLabel(text(post, 'kind')),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: store.saved.contains(post['id'])
                      ? 'Unsave post'
                      : 'Save post',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => store.toggleSave(text(post, 'id')),
                  icon: Icon(
                    store.saved.contains(post['id'])
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              text(post, 'title'),
              style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text(post, 'body'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if ((post['photoIDs'] as List? ?? []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PhotoView(
                  store: store,
                  id: post['photoIDs'][0] as String,
                  height: 160,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${authorName(post)} · ${text(post, 'groupName')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const Icon(Icons.chat_bubble_outline, size: 14),
                const SizedBox(width: 5),
                Text(
                  '${rows(post['replies']).length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class PhotoView extends StatefulWidget {
  final CampusStore store;
  final String id;
  final double height;
  const PhotoView({
    super.key,
    required this.store,
    required this.id,
    this.height = 240,
  });
  @override
  State<PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<PhotoView> {
  late Future<Uint8List> data;
  @override
  void initState() {
    super.initState();
    data = widget.store.photo(widget.id);
  }

  @override
  void didUpdateWidget(PhotoView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) data = widget.store.photo(widget.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: data,
    builder: (context, s) {
      if (s.hasError) {
        return SizedBox(
          height: 80,
          child: Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => data = widget.store.photo(widget.id)),
              child: const Text('Photo unavailable · Retry'),
            ),
          ),
        );
      }
      if (!s.hasData) {
        return SizedBox(
          height: widget.height,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Image.memory(s.data!, fit: BoxFit.contain),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: 'Close photo',
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            s.data!,
            height: widget.height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    },
  );
}

class PostPage extends StatefulWidget {
  final CampusStore store;
  final String id;
  final Json? initial;
  const PostPage({
    super.key,
    required this.store,
    required this.id,
    this.initial,
  });
  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final reply = TextEditingController();
  bool sending = false;
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store;
      final p =
          s.posts.where((p) => p['id'] == widget.id).firstOrNull ??
          widget.initial;
      if (p == null) {
        return Scaffold(
          appBar: AppBar(),
          body: empty('Post deleted or unavailable.', Icons.article_outlined),
        );
      }
      final own =
          p['isMine'] == true || (p['author'] as Json?)?['id'] == s.me['id'];
      return Scaffold(
        appBar: AppBar(
          title: Text(kindLabel(text(p, 'kind'))),
          actions: [
            IconButton(
              tooltip: 'Save post',
              onPressed: () => s.toggleSave(widget.id),
              icon: Icon(
                s.saved.contains(widget.id)
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => guard(context, () async {
                if (action == 'report') {
                  final reason = await prompt(context, 'Reason for report');
                  if (reason != null && reason.isNotEmpty) {
                    await s.report(widget.id, reason);
                    if (context.mounted) {
                      toast(
                        context,
                        s.demo
                            ? 'Demo report saved locally. No moderator received it.'
                            : 'Report sent for review.',
                      );
                    }
                  }
                } else if (action == 'anonymous') {
                  await s.managePost(
                    widget.id,
                    anonymous: p['anonymous'] != true,
                  );
                } else if (action == 'delete' &&
                    await confirm(
                      context,
                      'Delete this post and its replies?',
                    )) {
                  await s.managePost(widget.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report post'),
                ),
                if (own) ...[
                  const PopupMenuItem(
                    value: 'anonymous',
                    child: Text('Toggle anonymity'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete post'),
                  ),
                ],
              ],
            ),
          ],
        ),
        body: PageBody(
          children: [
            Text(
              text(p, 'title'),
              style: const TextStyle(fontSize: 30, height: 1.2),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: avatar(p['author'] as Json? ?? {'name': '?'}),
              title: Text(authorName(p)),
              subtitle: Text(stamp(p['createdAt'])),
              onTap: p['author'] == null
                  ? null
                  : () => go(
                      context,
                      MemberPage(store: s, person: p['author'] as Json),
                    ),
            ),
            Text(
              p['visibility'] == 'group'
                  ? 'Private post · ${p['groupName']}'
                  : 'Visible to school',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (p['askedPerson'] != null)
              Text('Asked @${text(p['askedPerson'] as Json, 'name')}'),
            const SizedBox(height: 20),
            SelectableText(
              text(p, 'body'),
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            for (final id in p['photoIDs'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PhotoView(store: s, id: id as String),
              ),
            section('Replies'),
            for (final r in rows(p['replies']))
              Card(
                child: ListTile(
                  title: Text(text(r['author'] as Json, 'name')),
                  subtitle: Text(text(r, 'body')),
                  isThreeLine: false,
                  trailing: (r['author'] as Json)['id'] == s.me['id']
                      ? IconButton(
                          tooltip: 'Delete reply',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => guard(context, () async {
                            if (await confirm(context, 'Delete this reply?')) {
                              await s.deleteReply(text(r, 'id'));
                            }
                          }),
                        )
                      : null,
                  onTap: () => go(
                    context,
                    MemberPage(store: s, person: r['author'] as Json),
                  ),
                ),
              ),
            field(reply, 'Write a reply', lines: 3, limit: 2000),
            FilledButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      setState(() => sending = true);
                      await guard(context, () async {
                        final message = await s.reply(
                          widget.id,
                          reply.text.trim(),
                        );
                        reply.clear();
                        if (context.mounted) toast(context, message);
                      });
                      if (mounted) setState(() => sending = false);
                    },
              icon: const Icon(Icons.send_outlined),
              label: Text(sending ? 'Sending…' : 'Send reply'),
            ),
          ],
        ),
      );
    },
  );
}

class ComposerPage extends StatefulWidget {
  final CampusStore store;
  const ComposerPage({super.key, required this.store});
  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  final title = TextEditingController(), body = TextEditingController();
  String kind = 'Question',
      group = 'all',
      visibility = 'school',
      priority = 'normal';
  String? asked, askedName;
  bool anonymous = false, busy = false;
  List<String> photos = [];
  String? error;
  Timer? timer;
  bool published = false;
  String get key => 'draft.${widget.store.scope}';
  @override
  void initState() {
    super.initState();
    try {
      final d = jsonDecode(widget.store.prefs.getString(key) ?? '{}') as Json;
      title.text = text(d, 'title');
      body.text = text(d, 'body');
      kind = text(d, 'kind', 'Question');
      group = text(d, 'groupID', 'all');
      visibility = text(d, 'visibility', 'school');
      priority = text(d, 'priority', 'normal');
      anonymous = d['anonymous'] == true;
      photos = (d['photoIDs'] as List? ?? []).cast<String>();
      asked = d['askedUserID'] as String?;
      askedName = d['askedName'] as String?;
    } catch (_) {}
    title.addListener(schedule);
    body.addListener(schedule);
  }

  Json get draft => {
    'title': title.text.trim(),
    'body': body.text.trim(),
    'kind': kind,
    'groupID': group,
    'visibility': visibility,
    'priority': kind == 'Photo Gallery' ? 'normal' : priority,
    'anonymous': anonymous,
    if (kind == 'Question' && asked != null) 'askedUserID': asked,
    if (askedName != null) 'askedName': askedName,
    if (kind == 'Photo Gallery') 'photoIDs': photos,
  };
  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 500), save);
  }

  void save() {
    if (!published) widget.store.prefs.setString(key, jsonEncode(draft));
  }

  @override
  void dispose() {
    timer?.cancel();
    save();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> pickPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty || !mounted) return;
    if (photos.length + result.length > 20) {
      if (mounted) toast(context, 'Choose up to 20 photos.');
      return;
    }
    setState(() => busy = true);
    await guard(context, () async {
      for (final file in result) {
        if ((await file.length() ?? 0) > 30 * 1024 * 1024) {
          throw Exception('Choose images smaller than 30 MB.');
        }
        final bytes = await compute(preparePhoto, await file.readAsBytes());
        final id = await widget.store.uploadPhoto(bytes);
        if (mounted) setState(() => photos.add(id));
        save();
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final result = await widget.store.publish(
                        draft..remove('askedName'),
                      );
                      published = true;
                      await widget.store.prefs.remove(key);
                      if (context.mounted) {
                        toast(context, result);
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = e.toString());
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Working…' : 'Publish'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: PageBody(
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Post type'),
              items: [
                for (final e in kinds.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                setState(() => kind = v!);
                save();
              },
            ),
            field(title, 'Title', limit: 140),
            field(
              body,
              kind == 'Photo Gallery' ? 'Caption' : 'Details',
              lines: 6,
              limit: 5000,
            ),
            if (kind == 'Photo Gallery') ...[
              OutlinedButton.icon(
                onPressed: pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Choose photos · ${photos.length}/20'),
              ),
              for (final id in photos)
                Row(
                  children: [
                    Expanded(
                      child: PhotoView(
                        store: widget.store,
                        id: id,
                        height: 100,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () {
                        setState(() => photos.remove(id));
                        save();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
            ] else ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final v in ['normal', 'important', 'urgent'])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) {
                  setState(() => priority = v!);
                  save();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'The server reviews requested priority before publication.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
            if (kind == 'Question')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alternate_email),
                title: Text(askedName ?? 'Ask a person · optional'),
                trailing: asked == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            asked = null;
                            askedName = null;
                          });
                          save();
                        },
                        icon: const Icon(Icons.close),
                      ),
                onTap: () => guard(context, () async {
                  final person = await selectMember(context, widget.store);
                  if (person != null && mounted) {
                    setState(() {
                      asked = text(person, 'id');
                      askedName = text(person, 'name');
                    });
                    save();
                  }
                }),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: group,
              decoration: const InputDecoration(labelText: 'Responder group'),
              items: [
                for (final g in widget.store.groups)
                  DropdownMenuItem(
                    value: text(g, 'id'),
                    child: Text(text(g, 'name')),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  group = v!;
                  if (visibility == 'group' &&
                      !widget.store.groups.any(
                        (g) => g['id'] == group && g['isMember'] == true,
                      )) {
                    visibility = 'school';
                  }
                });
                save();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: [
                const DropdownMenuItem(
                  value: 'school',
                  child: Text('Visible to school'),
                ),
                if (widget.store.groups.any(
                  (g) => g['id'] == group && g['isMember'] == true,
                ))
                  const DropdownMenuItem(
                    value: 'group',
                    child: Text('Group members only'),
                  ),
              ],
              onChanged: (v) {
                setState(() => visibility = v!);
                save();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Post anonymously'),
              subtitle: const Text(
                'Anonymous to students. Administrators can see your identity.',
              ),
              value: anonymous,
              onChanged: (v) {
                setState(() => anonymous = v);
                save();
              },
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Text(
              'Your draft is saved on this device.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class MyPostsPage extends StatefulWidget {
  final CampusStore store;
  const MyPostsPage({super.key, required this.store});
  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  late Future<List<Json>> data;
  @override
  void initState() {
    super.initState();
    data = widget.store.ownPosts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My posts'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => setState(() => data = widget.store.ownPosts()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Json>>(
      future: data,
      builder: (context, s) {
        if (s.hasError) return empty(s.error.toString(), Icons.error_outline);
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return PageBody(
          children: [
            if (s.data!.isEmpty)
              empty('You have no posts yet.', Icons.article_outlined),
            for (final p in s.data!)
              Card(
                child: ListTile(
                  title: Text(text(p, 'title')),
                  subtitle: Text(text(p, 'status', 'published')),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostPage(
                          store: widget.store,
                          id: text(p, 'id'),
                          initial: p,
                        ),
                      ),
                    );
                    if (mounted) setState(() => data = widget.store.ownPosts());
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}
