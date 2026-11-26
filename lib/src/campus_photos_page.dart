import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'community_models.dart';
import 'data/school_moderation.dart';
import 'school_moderation_ui.dart';

String galleryPostAttribution(
  CommunityController community,
  CommunityPost post,
) {
  final author = community.postAuthorName(post);
  return author == 'Student life' ? 'School member' : author;
}

class CampusPhotosPage extends StatefulWidget {
  const CampusPhotosPage({
    super.key,
    required this.community,
    required this.onCompose,
    this.onRefresh,
    this.submissions,
  });

  final CommunityController community;
  final Future<void> Function(BuildContext) onCompose;
  final Future<void> Function()? onRefresh;
  final Stream<List<GallerySubmission>>? submissions;

  @override
  State<CampusPhotosPage> createState() => _CampusPhotosPageState();
}

class _CampusPhotosPageState extends State<CampusPhotosPage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing || widget.onRefresh == null) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh!();
    } catch (_) {
      if (mounted) showAppError(context, 'Could not refresh campus photos.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Campus photos'),
      actions: [
        if (widget.onRefresh != null)
          IconButton(
            tooltip: 'Refresh photos',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
    body: ListenableBuilder(
      listenable: widget.community,
      builder: (context, _) {
        final posts =
            widget.community.visiblePosts
                .where(
                  (post) =>
                      post.category == PostCategory.gallery &&
                      post.photos.isNotEmpty,
                )
                .toList()
              ..sort((a, b) => b.at.compareTo(a.at));
        final hasCachedAlbums = widget.community.visiblePosts.any(
          (post) => post.sharedGalleryMedia && post.photos.isEmpty,
        );
        final today = DateUtils.dateOnly(DateTime.now());
        final yesterday = DateTime(today.year, today.month, today.day - 1);
        final days = <DateTime, List<CommunityPost>>{};
        for (final post in posts) {
          days
              .putIfAbsent(DateUtils.dateOnly(post.at.toLocal()), () => [])
              .add(post);
        }
        final entries = <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => widget.onCompose(context),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Post photos'),
            ),
          ),
          if (widget.submissions case final submissions?)
            _GallerySubmissions(submissions: submissions),
          if (_refreshing) const LinearProgressIndicator(),
          if (posts.isEmpty || hasCachedAlbums)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                hasCachedAlbums
                    ? 'Connect to Compass and refresh to load shared photos.'
                    : 'No photos have been posted at your school yet.',
              ),
            ),
          for (final entry in days.entries) ...[
            _PhotoSectionTitle(switch (entry.key) {
              final date when date == today => 'Today',
              final date when date == yesterday => 'Yesterday',
              final date => MaterialLocalizations.of(
                context,
              ).formatFullDate(date),
            }),
            for (final post in entry.value)
              _PhotoAlbumCard(
                title: post.title,
                attribution: galleryPostAttribution(widget.community, post),
                caption: post.body,
                actions: widget.community.canModeratePost(post)
                    ? SchoolContentActions(
                        moderation: widget.community.moderation!,
                        target: SchoolReportTarget.post(post.id),
                        authorId: post.authorId,
                        authorName: post.anonymous
                            ? 'Anonymous student'
                            : galleryPostAttribution(widget.community, post),
                      )
                    : null,
                photos: [
                  for (final photo in post.photos) _AlbumPhoto.encoded(photo),
                ],
              ),
          ],
          if (!widget.community.school.isRegistered) ...[
            const _PhotoSectionTitle('Example albums'),
            const _PhotoAlbumCard(
              title: 'A morning on campus',
              attribution: 'Student Council · Example',
              caption: 'The courtyard before the first bell.',
              photos: [_AlbumPhoto.asset('assets/campus_photos/courtyard.jpg')],
            ),
            const _PhotoAlbumCard(
              title: 'From the photo walk',
              attribution: 'Photography Club · Example',
              caption: 'Back in the studio to pick our favorite shots.',
              photos: [_AlbumPhoto.asset('assets/campus_photos/studio.jpg')],
            ),
          ],
        ];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              itemCount: entries.length,
              itemBuilder: (context, index) => entries[index],
            ),
          ),
        );
      },
    ),
  );
}

class _GallerySubmissions extends StatelessWidget {
  const _GallerySubmissions({required this.submissions});
  final Stream<List<GallerySubmission>> submissions;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<GallerySubmission>>(
    stream: submissions,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Could not load your photo submissions.'),
        );
      }
      final entries = snapshot.data ?? const [];
      if (entries.isEmpty) return const SizedBox.shrink();
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Your submissions'),
        children: [
          for (final entry in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.title),
              subtitle: Text(entry.status.label),
            ),
        ],
      );
    },
  );
}

class _PhotoSectionTitle extends StatelessWidget {
  const _PhotoSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _PhotoAlbumCard extends StatelessWidget {
  const _PhotoAlbumCard({
    required this.title,
    required this.attribution,
    required this.caption,
    required this.photos,
    this.actions,
  });

  final Widget? actions;
  final String title;
  final String attribution;
  final String caption;
  final List<_AlbumPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoStrip(title: title, photos: photos, actions: actions),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(attribution, style: theme.textTheme.bodySmall),
          if (caption.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(caption, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class GalleryPostPhotos extends StatelessWidget {
  const GalleryPostPhotos({
    super.key,
    required this.title,
    required this.photos,
  });

  final String title;
  final List<String> photos;

  @override
  Widget build(BuildContext context) => _PhotoStrip(
    title: title,
    photos: [for (final photo in photos) _AlbumPhoto.encoded(photo)],
  );
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.title, required this.photos, this.actions});

  final String title;
  final List<_AlbumPhoto> photos;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => _PhotoViewer(title: title, photos: photos),
            ),
          ),
          child: Semantics(
            button: true,
            label: 'Open $title photos',
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _PhotoImage(photo: photos.first, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
      if (actions case final menu?)
        PositionedDirectional(
          top: 8,
          end: 8,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
            child: menu,
          ),
        ),
      if (photos.length > 1)
        Positioned(
          bottom: 12,
          right: 12,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  '${photos.length} photos',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.title, required this.photos});
  final String title;
  final List<_AlbumPhoto> photos;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int by) {
    final target = _index + by;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (value) => setState(() => _index = value),
            itemCount: widget.photos.length,
            itemBuilder: (context, i) => InteractiveViewer(
              child: SizedBox.expand(
                child: _PhotoImage(
                  photo: widget.photos[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous photo',
                  onPressed: _index > 0 ? () => _move(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_index + 1} / ${widget.photos.length}'),
                IconButton(
                  tooltip: 'Next photo',
                  onPressed: _index < widget.photos.length - 1
                      ? () => _move(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _AlbumPhoto {
  const _AlbumPhoto.asset(this.value) : bundled = true;
  const _AlbumPhoto.encoded(this.value) : bundled = false;
  final String value;
  final bool bundled;
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.photo, required this.fit});
  final _AlbumPhoto photo;
  final BoxFit fit;

  static Widget _fallback() =>
      const Center(child: Icon(Icons.broken_image_outlined));

  @override
  Widget build(BuildContext context) {
    if (photo.bundled) {
      return Image.asset(
        photo.value,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(photo.value);
    } on FormatException {
      return _fallback();
    }
    return Image.memory(
      bytes,
      fit: fit,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}
