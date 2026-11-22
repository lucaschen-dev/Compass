import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'activity_pages.dart';
import 'app_ui.dart';
import 'campus_photo_media.dart';
import 'campus_photos_page.dart';
import 'community_models.dart';
import 'for_you_page.dart';
import 'recommendations.dart';

class CommunityFeed extends StatefulWidget {
  const CommunityFeed({
    super.key,
    required this.community,
    required this.preferences,
    required this.onSavePreferences,
    required this.friendIds,
    required this.onAddFriend,
    this.newcomerSection,
    this.onRefreshPhotos,
    this.publishGalleryPost,
  });
  final CommunityController community;
  final StudentPreferences preferences;
  final Future<void> Function(StudentPreferences) onSavePreferences;
  final Set<String> friendIds;
  final Future<void> Function(String)? onAddFriend;
  final Widget? newcomerSection;
  final Future<void> Function()? onRefreshPhotos;
  final Future<void> Function(CommunityPost)? publishGalleryPost;
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
  Future<void> _openCampusPhotos() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => CampusPhotosPage(
        community: c,
        onRefresh: widget.onRefreshPhotos,
        onCompose: (context) => openPostComposer(
          context,
          c,
          photoOnly: true,
          publishGalleryPost: widget.publishGalleryPost,
        ),
      ),
    ),
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
            if (!_forYou &&
                _category == null &&
                _query.isEmpty &&
                widget.newcomerSection != null) ...[
              widget.newcomerSection!,
              const SizedBox(height: 16),
            ],
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
            if (!_forYou) ...[
              const SizedBox(height: 16),
              if (c.school.clubs.isNotEmpty)
                ActivitySpotlightCard(
                  title: 'Clubs',
                  activity: spotlightActivity(c.school.clubs, c.school.id),
                  allLabel: 'All clubs',
                  onOpenAll: () => openActivityDirectory(
                    context,
                    school: c.school,
                    community: c,
                    friendIds: widget.friendIds,
                    onAddFriend: widget.onAddFriend,
                    clubs: true,
                  ),
                  onOpenActivity: () => openActivityDetail(
                    context,
                    school: c.school,
                    community: c,
                    activity: spotlightActivity(c.school.clubs, c.school.id),
                    friendIds: widget.friendIds,
                    onAddFriend: widget.onAddFriend,
                    club: true,
                  ),
                ),
              if (c.school.events.isNotEmpty) ...[
                const SizedBox(height: 20),
                ActivitySpotlightCard(
                  title: 'Events',
                  activity: spotlightActivity(c.school.events, c.school.id),
                  allLabel: 'All events',
                  onOpenAll: () => openActivityDirectory(
                    context,
                    school: c.school,
                    community: c,
                    friendIds: widget.friendIds,
                    onAddFriend: widget.onAddFriend,
                    clubs: false,
                  ),
                  onOpenActivity: () => openActivityDetail(
                    context,
                    school: c.school,
                    community: c,
                    activity: spotlightActivity(c.school.events, c.school.id),
                    friendIds: widget.friendIds,
                    onAddFriend: widget.onAddFriend,
                    club: false,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            if ((!_forYou && _category == null && _query.isEmpty) ||
                _category == PostCategory.gallery) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Campus photos'),
                subtitle: const Text('Browse photo posts by day'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openCampusPhotos,
              ),
              const SizedBox(height: 8),
            ],
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
            if (_forYou) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clubs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('for-you-all-clubs'),
                    onPressed: () => openActivityDirectory(
                      context,
                      school: c.school,
                      community: c,
                      friendIds: widget.friendIds,
                      onAddFriend: widget.onAddFriend,
                      clubs: true,
                    ),
                    child: const Text('All clubs'),
                  ),
                ],
              ),
              if (recommendations.clubs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No clubs match. Try another interest or meetup time.',
                  ),
                )
              else
                for (final m in recommendations.clubs)
                  ListTile(
                    key: ValueKey('for-you-club-${m.item.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.item.title),
                    subtitle: Text(m.sharedInterests.join(' · ')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openActivityDetail(
                      context,
                      school: c.school,
                      community: c,
                      activity: m.item,
                      friendIds: widget.friendIds,
                      onAddFriend: widget.onAddFriend,
                      club: true,
                    ),
                  ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('for-you-all-events'),
                    onPressed: () => openActivityDirectory(
                      context,
                      school: c.school,
                      community: c,
                      friendIds: widget.friendIds,
                      onAddFriend: widget.onAddFriend,
                      clubs: false,
                    ),
                    child: const Text('All events'),
                  ),
                ],
              ),
              if (recommendations.events.isEmpty)
                const Text(
                  'No events match. Try another interest or meetup time.',
                )
              else
                for (final m in recommendations.events)
                  ListTile(
                    key: ValueKey('for-you-event-${m.item.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.item.title),
                    subtitle: Text(m.sharedInterests.join(' · ')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openActivityDetail(
                      context,
                      school: c.school,
                      community: c,
                      activity: m.item,
                      friendIds: widget.friendIds,
                      onAddFriend: widget.onAddFriend,
                      club: false,
                    ),
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
            onPressed: () => openPostComposer(
              context,
              c,
              publishGalleryPost: widget.publishGalleryPost,
            ),
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
    final name = post.category == PostCategory.gallery
        ? galleryPostAttribution(c, post)
        : post.anonymous
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
                  GalleryPostPhotos(title: post.title, photos: post.photos),
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

Future<void> openPostComposer(
  BuildContext context,
  CommunityController c, {
  bool photoOnly = false,
  Future<void> Function(CommunityPost)? publishGalleryPost,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 680),
  builder: (_) => _PostComposer(
    c: c,
    photoOnly: photoOnly,
    publishGalleryPost: publishGalleryPost,
  ),
);

class _PostComposer extends StatefulWidget {
  const _PostComposer({
    required this.c,
    required this.photoOnly,
    required this.publishGalleryPost,
  });
  final CommunityController c;
  final bool photoOnly;
  final Future<void> Function(CommunityPost)? publishGalleryPost;
  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  static const _photoDraftKey = 'photoDraft';
  late final Map<String, dynamic> _initialDraft = widget.photoOnly
      ? Map<String, dynamic>.from(
          widget.c.composerDraft[_photoDraftKey] as Map? ?? {},
        )
      : widget.c.composerDraft;
  late final _title = TextEditingController(
    text: _initialDraft['title'] as String? ?? '',
  );
  late final _body = TextEditingController(
    text: _initialDraft['body'] as String? ?? '',
  );
  late PostCategory _category = widget.photoOnly
      ? PostCategory.gallery
      : PostCategory.values
                .where((category) => category.name == _initialDraft['category'])
                .firstOrNull ??
            PostCategory.question;
  late String _subtag = _category.subtags.contains(_initialDraft['subtag'])
      ? _initialDraft['subtag'] as String
      : _category.subtags.first;
  late String _priority = _initialDraft['priority'] as String? ?? 'Normal';
  late String? _asked = _initialDraft['asked'] as String?;
  late String? _postId = _initialDraft['postId'] as String?;
  late bool _anonymous = _initialDraft['anonymous'] == true;
  bool _busy = false, _posted = false, _picking = false;
  late List<String> _photos = List<String>.from(
    _initialDraft['photos'] as List? ?? [],
  );

  void _replaceDraft(Map<String, dynamic> next) {
    final current = widget.c.composerDraft;
    widget.c.composerDraft = widget.photoOnly
        ? {...current, if (next.isNotEmpty) _photoDraftKey: next}
        : {
            ...next,
            if (current.containsKey(_photoDraftKey))
              _photoDraftKey: current[_photoDraftKey],
          };
    if (widget.photoOnly && next.isEmpty) {
      widget.c.composerDraft.remove(_photoDraftKey);
    }
  }

  Future<void> _pickPhotos() async {
    setState(() => _picking = true);
    try {
      final picked = await chooseGalleryPhotos(
        galleryPhotoLimit - _photos.length,
      );
      if (mounted && _category == PostCategory.gallery && picked.isNotEmpty) {
        setState(() => _photos.addAll(picked));
        _scheduleDraft();
      }
    } catch (error) {
      if (mounted) {
        showAppError(
          context,
          error is ArgumentError
              ? error.message.toString()
              : 'Could not read the photos.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

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
      if (_postId != null) 'postId': _postId,
    };
    return widget.c.change(() => _replaceDraft(draft));
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
    final publish = _category == PostCategory.gallery
        ? widget.publishGalleryPost
        : null;
    if (publish != null &&
        (_photos.length > galleryPhotoLimit ||
            !_photos.every(isSharedGalleryPhoto))) {
      showAppError(
        context,
        'Reselect photos from this older draft to share up to $galleryPhotoLimit photos.',
      );
      return;
    }
    setState(() => _busy = true);
    _draft?.cancel();
    final post = CommunityPost(
      id: _postId ??= widget.c.newId(),
      authorId: 'me',
      title: title.isEmpty ? 'Photo Gallery' : title,
      body: body,
      category: _category,
      subtag: _subtag,
      at: DateTime.now(),
      anonymous: _anonymous,
      priority: _category == PostCategory.gallery ? 'Normal' : _priority,
      askedPerson: _category == PostCategory.question ? _asked : null,
      photos: List.of(_photos),
      sharedGalleryMedia: publish != null,
    );
    if (publish != null) {
      try {
        await _saveDraft();
        await publish(post);
      } catch (_) {
        if (mounted) {
          showAppError(
            context,
            'Could not confirm publication. Your draft is still here. Try again.',
          );
          setState(() => _busy = false);
        }
        return;
      }
    }
    try {
      await widget.c.change(() {
        widget.c.posts = [
          post,
          ...widget.c.posts.where((previous) => previous.id != post.id),
        ];
        _replaceDraft({});
      });
      _posted = true;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showAppError(
          context,
          publish == null
              ? 'Could not save the post. Try fewer or smaller photos.'
              : 'Photos were shared, but this device could not update its copy.',
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
            Text(
              widget.photoOnly ? 'Post photos' : 'New post',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            if (!widget.photoOnly)
              DropdownButtonFormField<PostCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in PostCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: _busy || _picking
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
              onChanged: _busy ? null : (v) => setState(() => _subtag = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 140,
              readOnly: _busy,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 10,
              maxLength: 5000,
              readOnly: _busy,
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
                            onPressed: _busy || _picking
                                ? null
                                : () {
                                    setState(() => _photos.removeAt(i));
                                    _scheduleDraft();
                                  },
                            icon: const Icon(Icons.cancel),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              OutlinedButton.icon(
                onPressed:
                    _photos.length >= galleryPhotoLimit || _busy || _picking
                    ? null
                    : _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _picking
                      ? 'Preparing photos…'
                      : 'Add photos (${_photos.length}/$galleryPhotoLimit)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.publishGalleryPost == null
                    ? 'Photos are saved on this device.'
                    : 'Signed-in members of ${shortSchoolName(widget.c.school)} can see these photos. Only share photos you have permission to post.',
                style: Theme.of(context).textTheme.bodySmall,
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
              onChanged: _busy ? null : (v) => setState(() => _anonymous = v),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy || _picking ? null : _post,
              child: Text(_busy ? 'Saving…' : 'Post'),
            ),
          ],
        ),
      ),
    ),
  );
}
