import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'community_models.dart';
import 'for_you_page.dart';
import 'recommendations.dart';

class CommunityFeed extends StatefulWidget {
  const CommunityFeed({
    super.key,
    required this.community,
    required this.preferences,
    required this.onSavePreferences,
  });
  final CommunityController community;
  final StudentPreferences preferences;
  final Future<void> Function(StudentPreferences) onSavePreferences;
  @override
  State<CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends State<CommunityFeed> {
  PostCategory? _category;
  String? _subtag;
  String _query = '';
  bool _forYou = false;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    _expiry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  CommunityController get c => widget.community;
  Future<void> _topics() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TopicsEditor(c: c),
  );
  int _score(CommunityPost p) =>
      (c.followedTags.contains(p.category.name) ? 1 : 0) +
      (c.followedTags.contains('${p.category.name}/${p.subtag}') ? 3 : 0) +
      widget.preferences.interests
          .where(
            (i) => '${p.subtag} ${p.title} ${p.body}'.toLowerCase().contains(
              i.toLowerCase(),
            ),
          )
          .length;
  bool _matches(CommunityPost p) =>
      c.followedTags.contains(p.category.name) ||
      c.followedTags.contains('${p.category.name}/${p.subtag}') ||
      widget.preferences.interests.any(
        (i) => '${p.subtag} ${p.title} ${p.body}'.toLowerCase().contains(
          i.toLowerCase(),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final posts =
        c.posts
            .where(
              (p) =>
                  (_category == null || p.category == _category) &&
                  (_subtag == null || p.subtag == _subtag) &&
                  '${p.title} ${p.body}'.toLowerCase().contains(_query) &&
                  (!_forYou || _matches(p)),
            )
            .toList()
          ..sort(
            (a, b) => _forYou && _score(a) != _score(b)
                ? _score(b).compareTo(_score(a))
                : b.at.compareTo(a.at),
          );
    final recommendations = recommendFor(c.school, widget.preferences);
    return Stack(
      children: [
        ContentColumn(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() {
                        _category = null;
                        _subtag = null;
                      }),
                    ),
                  ),
                  for (final category in PostCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) => setState(() {
                          _category = category;
                          _subtag = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            if (_category != null) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in _category!.subtags)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: _subtag == tag,
                          onSelected: (_) => setState(
                            () => _subtag = _subtag == tag ? null : tag,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search posts',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _FeedTab(
                  'Latest',
                  !_forYou,
                  () => setState(() => _forYou = false),
                ),
                const SizedBox(width: 28),
                _FeedTab(
                  'For you',
                  _forYou,
                  () => setState(() => _forYou = true),
                ),
                const Spacer(),
                if (_forYou)
                  IconButton(
                    tooltip: 'Choose post topics',
                    onPressed: _topics,
                    icon: const Icon(Icons.tune_rounded),
                  ),
              ],
            ),
            const Divider(),
            if (_forYou) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _topics,
                    icon: const Icon(Icons.tag_rounded, size: 18),
                    label: const Text('Post topics'),
                  ),
                  TextButton.icon(
                    onPressed: () => editStudentPreferences(
                      context,
                      c.school,
                      widget.preferences,
                      widget.onSavePreferences,
                    ),
                    icon: const Icon(Icons.interests_outlined, size: 18),
                    label: const Text('Interests'),
                  ),
                ],
              ),
              if (c.followedTags.isEmpty &&
                  widget.preferences.interests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Text(
                        'Make this feed yours',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _topics,
                        child: const Text('Choose topics'),
                      ),
                    ],
                  ),
                ),
            ],
            if (posts.isEmpty &&
                (!_forYou ||
                    c.followedTags.isNotEmpty ||
                    widget.preferences.interests.isNotEmpty))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No posts match yet.'),
              ),
            if (posts.any((p) => p.important)) ...[
              const SizedBox(height: 20),
              Text('Important', style: Theme.of(context).textTheme.titleSmall),
              for (final post in posts.where((p) => p.important))
                PostTile(community: c, post: post, showPriority: false),
            ],
            for (final post in posts.where((p) => !p.important))
              PostTile(community: c, post: post),
            if (_forYou && recommendations.peers.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'People you might know',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final m in recommendations.peers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: StudentAvatar(name: m.item.name),
                  title: Text(m.item.name),
                  subtitle: Text(m.sharedInterests.join(' · ')),
                ),
            ],
            if (_forYou)
              for (final section in [
                (title: 'Clubs', items: recommendations.clubs),
                (title: 'Events', items: recommendations.events),
              ])
                if (section.items.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final m in section.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.item.title),
                      subtitle: Text(m.sharedInterests.join(' · ')),
                    ),
                ],
            const SizedBox(height: 80),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 20,
          child: FloatingActionButton(
            tooltip: 'Create a post',
            onPressed: () => openPostComposer(context, c),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: selected
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _TopicsEditor extends StatefulWidget {
  const _TopicsEditor({required this.c});
  final CommunityController c;
  @override
  State<_TopicsEditor> createState() => _TopicsEditorState();
}

class _TopicsEditorState extends State<_TopicsEditor> {
  late final Set<String> _selected = {...widget.c.followedTags};
  bool _busy = false;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your post topics',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          for (final category in PostCategory.values) ...[
            Text(
              category.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in ['All', ...category.subtags])
                  FilterChip(
                    label: Text(tag),
                    selected: _selected.contains(
                      tag == 'All' ? category.name : '${category.name}/$tag',
                    ),
                    onSelected: (v) => setState(() {
                      final key = tag == 'All'
                          ? category.name
                          : '${category.name}/$tag';
                      v ? _selected.add(key) : _selected.remove(key);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.c.change(
                        () => widget.c.followedTags = {..._selected},
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        showAppError(context, 'Could not save topics.');
                        setState(() => _busy = false);
                      }
                    }
                  },
            child: const Text('Save topics'),
          ),
        ],
      ),
    ),
  );
}

class PostTile extends StatelessWidget {
  const PostTile({
    super.key,
    required this.community,
    required this.post,
    this.open = true,
    this.showPriority = true,
  });
  final CommunityController community;
  final CommunityPost post;
  final bool open;
  final bool showPriority;
  @override
  Widget build(BuildContext context) {
    final c = community;
    final name = post.anonymous
        ? 'Anonymous student'
        : c.authorName(post.authorId);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentAvatar(
                name: name,
                photo: post.authorId == 'me' && !post.anonymous
                    ? c.profile.avatar
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        post.category.label,
                        if (post.subtag.isNotEmpty) post.subtag,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                relativeTime(post.at),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              PopupMenuButton<String>(
                tooltip: 'Post actions',
                onSelected: (v) async {
                  if (v == 'anonymous') {
                    await appSave(
                      context,
                      () => c.change(
                        () => c.posts = [
                          for (final p in c.posts)
                            if (p.id == post.id)
                              p.copyWith(anonymous: !p.anonymous)
                            else
                              p,
                        ],
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  if (v == 'delete' &&
                      await confirmAction(
                        context,
                        title: 'Delete this post and its comments?',
                        action: 'Delete',
                      )) {
                    if (context.mounted) {
                      await appSave(
                        context,
                        () => c.change(
                          () => c.posts = c.posts
                              .where((p) => p.id != post.id)
                              .toList(),
                        ),
                      );
                    }
                  }
                  if (v == 'report' && context.mounted) {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Report post'),
                        content: const Text(
                          'Reports need a connected school service. This preview does not send reports.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (post.authorId == 'me') ...[
                    PopupMenuItem(
                      value: 'anonymous',
                      child: Text(
                        post.anonymous ? 'Show my name' : 'Post anonymously',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete post'),
                    ),
                  ] else
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: open
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PostDetail(community: c, postId: post.id),
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.important &&
                    (showPriority || post.priority == 'Urgent'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.push_pin_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.priority,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(post.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  post.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: open ? 5 : null,
                  overflow: open ? TextOverflow.ellipsis : null,
                ),
                if (post.photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: PageView(
                      children: [
                        for (final photo in post.photos)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(photo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (post.askedPerson != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Asked ${c.authorName(post.askedPerson!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetail(community: c, postId: post.id),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                label: Text('${post.replies.length}'),
              ),
              const Spacer(),
              IconButton(
                tooltip: c.savedPosts.contains(post.id)
                    ? 'Unsave post'
                    : 'Save post',
                onPressed: () => appSave(context, () => c.toggleSaved(post.id)),
                icon: Icon(
                  c.savedPosts.contains(post.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => appSave(context, () => c.toggleLiked(post.id)),
                icon: Icon(
                  c.likedPosts.contains(post.id)
                      ? Icons.favorite
                      : Icons.favorite_outline,
                  size: 22,
                ),
                label: Text(
                  '${post.likes + (c.likedPosts.contains(post.id) ? 1 : 0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }
}

class PostDetail extends StatefulWidget {
  const PostDetail({super.key, required this.community, required this.postId});
  final CommunityController community;
  final String postId;
  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  final _reply = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.community,
    builder: (context, _) {
      final c = widget.community;
      final p = c.posts.where((p) => p.id == widget.postId).firstOrNull;
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: p == null
            ? const Center(child: Text('This post was deleted.'))
            : ContentColumn(
                children: [
                  PostTile(community: c, post: p, open: false),
                  const SizedBox(height: 24),
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final r in p.replies)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.authorName(r.author)),
                      subtitle: Text(r.body),
                      trailing: r.author == 'me'
                          ? IconButton(
                              tooltip: 'Delete my comment',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                if (await confirmAction(
                                  context,
                                  title: 'Delete your comment?',
                                  action: 'Delete',
                                )) {
                                  if (context.mounted) {
                                    await appSave(
                                      context,
                                      () => c.change(
                                        () => c.posts = [
                                          for (final entry in c.posts)
                                            if (entry.id == p.id)
                                              entry.copyWith(
                                                replies: entry.replies
                                                    .where((v) => v.id != r.id)
                                                    .toList(),
                                              )
                                            else
                                              entry,
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                            )
                          : null,
                    ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final text = _reply.text.trim();
                            if (text.isEmpty) return;
                            setState(() => _busy = true);
                            try {
                              await c.change(
                                () => c.posts = [
                                  for (final entry in c.posts)
                                    if (entry.id == p.id)
                                      entry.copyWith(
                                        replies: [
                                          ...entry.replies,
                                          PostReply(
                                            id: c.newId(),
                                            author: 'me',
                                            body: text,
                                            at: DateTime.now(),
                                          ),
                                        ],
                                      )
                                    else
                                      entry,
                                ],
                              );
                              _reply.clear();
                            } catch (_) {
                              if (context.mounted) {
                                showAppError(
                                  context,
                                  'Could not save your comment.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Comment'),
                  ),
                ],
              ),
      );
    },
  );
}

Future<void> openPostComposer(BuildContext context, CommunityController c) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => _PostComposer(c: c),
    );

class _PostComposer extends StatefulWidget {
  const _PostComposer({required this.c});
  final CommunityController c;
  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  late final _title = TextEditingController(
        text: widget.c.composerDraft['title'] as String? ?? '',
      ),
      _body = TextEditingController(
        text: widget.c.composerDraft['body'] as String? ?? '',
      );
  late PostCategory _category =
      PostCategory.values
          .where((c) => c.name == widget.c.composerDraft['category'])
          .firstOrNull ??
      PostCategory.question;
  late String _subtag =
      widget.c.composerDraft['subtag'] as String? ?? _category.subtags.first;
  late String _priority =
      widget.c.composerDraft['priority'] as String? ?? 'Normal';
  late String? _asked = widget.c.composerDraft['asked'] as String?;
  late bool _anonymous = widget.c.composerDraft['anonymous'] == true;
  bool _busy = false, _posted = false;
  late List<String> _photos = List<String>.from(
    widget.c.composerDraft['photos'] as List? ?? [],
  );
  Timer? _draft;
  @override
  void initState() {
    super.initState();
    _title.addListener(_scheduleDraft);
    _body.addListener(_scheduleDraft);
  }

  void _scheduleDraft() {
    _draft?.cancel();
    _draft = Timer(const Duration(milliseconds: 500), () {
      _saveDraft().catchError((_) {
        if (mounted) showAppError(context, 'Could not save the draft.');
      });
    });
  }

  Future<void> _saveDraft() {
    final draft = <String, dynamic>{
      'title': _title.text,
      'body': _body.text,
      'category': _category.name,
      'subtag': _subtag,
      'priority': _priority,
      'asked': _asked,
      'anonymous': _anonymous,
      'photos': List<String>.of(_photos),
    };
    return widget.c.change(() => widget.c.composerDraft = draft);
  }

  @override
  void dispose() {
    _draft?.cancel();
    if (!_posted) _saveDraft().catchError((_) {});
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _title.text.trim(), body = _body.text.trim();
    if (_category == PostCategory.gallery
        ? _photos.isEmpty
        : (title.isEmpty || body.isEmpty)) {
      showAppError(
        context,
        _category == PostCategory.gallery
            ? 'Add at least one photo.'
            : 'Enter a title and a message.',
      );
      return;
    }
    setState(() => _busy = true);
    _draft?.cancel();
    try {
      await widget.c.change(() {
        widget.c.posts = [
          CommunityPost(
            id: widget.c.newId(),
            authorId: 'me',
            title: title.isEmpty ? 'Photo Gallery' : title,
            body: body,
            category: _category,
            subtag: _subtag,
            at: DateTime.now(),
            anonymous: _anonymous,
            priority: _category == PostCategory.gallery ? 'Normal' : _priority,
            askedPerson: _asked,
            photos: List.of(_photos),
          ),
          ...widget.c.posts,
        ];
        widget.c.composerDraft = {};
      });
      _posted = true;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showAppError(
          context,
          'Could not save the post. Try fewer or smaller photos.',
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New post', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            DropdownButtonFormField<PostCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in PostCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _category = v!;
                      _subtag = v.subtags.first;
                      if (v != PostCategory.gallery) _photos = [];
                      _scheduleDraft();
                    }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _subtag,
              decoration: const InputDecoration(labelText: 'Subtag'),
              items: [
                for (final tag in _category.subtags)
                  DropdownMenuItem(value: tag, child: Text(tag)),
              ],
              onChanged: (v) => setState(() => _subtag = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 10,
              maxLength: 5000,
              decoration: InputDecoration(
                labelText: _category == PostCategory.gallery
                    ? 'Caption'
                    : 'Message',
              ),
            ),
            if (_category == PostCategory.gallery) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Stack(
                      children: [
                        Image.memory(
                          base64Decode(_photos[i]),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Remove photo',
                            onPressed: () =>
                                setState(() => _photos.removeAt(i)),
                            icon: const Icon(Icons.cancel),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _photos.length >= 20 || _busy
                    ? null
                    : () async {
                        try {
                          final photo = await choosePhoto();
                          if (photo != null && mounted) {
                            setState(() => _photos.add(photo));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showAppError(
                              context,
                              e is ArgumentError
                                  ? e.message.toString()
                                  : 'Could not read the photo.',
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Add photos (${_photos.length}/20)'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final p in ['Normal', 'Important', 'Urgent'])
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
            ],
            if (_category == PostCategory.question) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _asked,
                decoration: const InputDecoration(
                  labelText: 'Ask a person (optional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Everyone')),
                  for (final p in widget.c.school.classmates)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _asked = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Post anonymously'),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _post,
              child: Text(_busy ? 'Saving…' : 'Post'),
            ),
          ],
        ),
      ),
    ),
  );
}
