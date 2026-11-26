import 'dart:convert';

import '../campus_photo_media.dart';
import '../community_models.dart';

const remoteStaleAfter = Duration(minutes: 5);

class ReplyChange {
  const ReplyChange(this.postId, this.reply);
  final String postId;
  final PostReply reply;
}

class ReplyRemoval {
  const ReplyRemoval(this.postId, this.replyId);
  final String postId;
  final String replyId;
}

class MessageChange {
  const MessageChange(this.threadId, this.message);
  final String threadId;
  final ChatMessage message;
}

class CommunityDelta {
  const CommunityDelta({
    this.profile,
    this.upsertPosts = const [],
    this.deletePostIds = const [],
    this.upsertReplies = const [],
    this.deleteReplies = const [],
    this.upsertThreads = const [],
    this.upsertMessages = const [],
    this.hiddenMessageIds = const [],
  });

  final CommunityProfile? profile;
  final List<CommunityPost> upsertPosts;
  final List<String> deletePostIds;
  final List<ReplyChange> upsertReplies;
  final List<ReplyRemoval> deleteReplies;
  final List<ChatThread> upsertThreads;
  final List<MessageChange> upsertMessages;
  final List<String> hiddenMessageIds;

  bool get isEmpty =>
      profile == null &&
      upsertPosts.isEmpty &&
      deletePostIds.isEmpty &&
      upsertReplies.isEmpty &&
      deleteReplies.isEmpty &&
      upsertThreads.isEmpty &&
      upsertMessages.isEmpty &&
      hiddenMessageIds.isEmpty;
}

bool ownsAuthor(String authorId, String uid) =>
    authorId == 'me' || authorId == uid;

String remoteAuthor(String authorId, String uid) =>
    authorId == 'me' ? uid : authorId;

String localAuthor(String authorId, String uid) =>
    authorId == uid ? 'me' : authorId;

bool cloudPhoto(String value) =>
    value.isNotEmpty && !value.startsWith('data:') && value.length <= 500;

Map<String, Object?> remotePostJson(
  CommunityPost post,
  String uid, {
  String? verifiedAuthorName,
}) => {
  'id': post.id,
  'authorId': remoteAuthor(post.authorId, uid),
  if (!post.anonymous && verifiedAuthorName != null)
    'authorName': verifiedAuthorName,
  'title': post.title,
  'body': post.body,
  'category': post.category.name,
  'subtag': post.subtag,
  'at': post.at.toIso8601String(),
  'anonymous': post.anonymous,
  'priority': post.priority,
  'askedPerson': post.askedPerson,
  if (!post.sharedGalleryMedia || post.photos.isNotEmpty)
    'photos': post.category == PostCategory.gallery && post.sharedGalleryMedia
        ? post.photos
              .where(isSharedGalleryPhoto)
              .take(galleryPhotoLimit)
              .toList()
        : post.photos.where(cloudPhoto).toList(),
  'likes': post.likes,
};

/// Keep synced metadata, drafts, and pre-existing local photos on this device.
/// Shared albums are reloaded from Firestore so they don't fill browser storage.
String compactSharedGalleryCache(String encoded) {
  if (!encoded.contains('"sharedGalleryMedia":true')) return encoded;
  final snapshot = jsonDecode(encoded) as Map<String, dynamic>;
  for (final post in (snapshot['posts'] as List).cast<Map<String, dynamic>>()) {
    if (post['sharedGalleryMedia'] == true) post['photos'] = const <String>[];
  }
  return jsonEncode(snapshot);
}

Map<String, Object?> remoteReplyJson(
  PostReply reply,
  String uid, {
  String? verifiedAuthorName,
}) => {
  'id': reply.id,
  'author': reply.author,
  'authorId': remoteAuthor(reply.author, uid),
  'authorName': ?verifiedAuthorName,
  'body': reply.body,
  'at': reply.at.toIso8601String(),
};

Map<String, Object?> remoteThreadJson(ChatThread thread) => {
  'id': thread.id,
  'title': thread.name,
  'participantIds': thread.members,
  'group': thread.group,
  'unread': thread.unread,
  'pinned': thread.pinned,
  'muted': thread.muted,
  'archived': thread.archived,
  'left': thread.left,
  'updatedAt': DateTime.now().toIso8601String(),
};

Map<String, Object?> remoteMessageJson(ChatMessage message, String uid) => {
  'id': message.id,
  'senderId': remoteAuthor(message.authorId, uid),
  'text': message.unsent ? '' : message.text,
  'createdAt': message.at.toIso8601String(),
  'replyTo': message.replyTo,
  'reaction': message.reaction,
  'unsent': message.unsent,
  'edited': message.edited,
  if (message.photo != null && cloudPhoto(message.photo!))
    'photo': message.photo,
};

CommunityPost localPostFromRemote(
  Map<String, dynamic> json,
  String uid, {
  List<String> keepPhotos = const [],
  List<PostReply> replies = const [],
}) {
  final category = PostCategory.values.byName(json['category'] as String);
  final incoming = (json['photos'] as List? ?? []).whereType<String>();
  final shared = category == PostCategory.gallery
      ? incoming.where(isSharedGalleryPhoto).take(galleryPhotoLimit).toList()
      : const <String>[];
  final photos = shared.isNotEmpty
      ? shared
      : incoming.where(cloudPhoto).toList();
  return CommunityPost(
    id: json['id'] as String,
    authorId: localAuthor(json['authorId'] as String? ?? '', uid),
    authorName: json['anonymous'] == true ? null : savedAuthorName(json),
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: category,
    subtag: json['subtag'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
    anonymous: json['anonymous'] == true,
    priority: json['priority'] as String? ?? 'Normal',
    askedPerson: json['askedPerson'] as String?,
    photos: photos.isEmpty ? keepPhotos : photos,
    sharedGalleryMedia: shared.isNotEmpty,
    replies: replies,
    likes: (json['likes'] as num?)?.toInt() ?? 0,
  );
}

PostReply localReplyFromRemote(Map<String, dynamic> json, String uid) {
  final authorId = json['authorId'] as String?;
  final legacyAuthor = json['author'] as String?;
  return PostReply(
    id: json['id'] as String,
    author: authorId == null
        ? (legacyAuthor == 'me' ? '' : legacyAuthor ?? '')
        : localAuthor(authorId, uid),
    authorName: savedAuthorName(json),
    body: json['body'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
  );
}

String? savedAuthorName(Map<String, dynamic> data) {
  final value = data['authorName'];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

ChatMessage localMessageFromRemote(
  Map<String, dynamic> json,
  String uid, {
  String? keepPhoto,
}) {
  final sender =
      json['senderId'] as String? ?? json['authorId'] as String? ?? '';
  final created = json['createdAt'] ?? json['at'];
  return ChatMessage(
    id: json['id'] as String,
    authorId: localAuthor(sender, uid),
    text: json['text'] as String? ?? '',
    at: DateTime.parse(created as String),
    replyTo: json['replyTo'] as String?,
    photo: json['photo'] as String? ?? keepPhoto,
    unsent: json['unsent'] == true,
    edited: json['edited'] == true,
    reaction: json['reaction'] as String?,
  );
}

ChatThread localThreadFromRemote(
  Map<String, dynamic> json, {
  List<ChatMessage> messages = const [],
  String draft = '',
}) => ChatThread(
  id: json['id'] as String,
  name: json['title'] as String? ?? json['name'] as String? ?? 'Chat',
  members: List<String>.from(
    json['participantIds'] as List? ?? json['members'] as List? ?? const [],
  ),
  messages: messages,
  group: json['group'] == true,
  unread: (json['unread'] as num?)?.toInt() ?? 0,
  archived: json['archived'] == true,
  muted: json['muted'] == true,
  pinned: json['pinned'] == true,
  left: json['left'] == true,
  draft: draft,
);

List<CommunityPost> mergePosts({
  required List<CommunityPost> local,
  required List<CommunityPost> remote,
  required String uid,
}) {
  final byId = {for (final post in local) post.id: post};
  for (final incoming in remote) {
    final existing = byId[incoming.id];
    byId[incoming.id] = CommunityPost(
      id: incoming.id,
      authorId: localAuthor(incoming.authorId, uid),
      authorName: incoming.anonymous ? null : incoming.authorName,
      title: incoming.title,
      body: incoming.body,
      category: incoming.category,
      subtag: incoming.subtag,
      at: incoming.at,
      anonymous: incoming.anonymous,
      priority: incoming.priority,
      askedPerson: incoming.askedPerson,
      photos: incoming.photos.isEmpty
          ? (existing?.photos ?? const [])
          : incoming.photos,
      sharedGalleryMedia: incoming.photos.isNotEmpty
          ? incoming.sharedGalleryMedia
          : existing?.sharedGalleryMedia ?? incoming.sharedGalleryMedia,
      replies: mergeReplies(
        local: existing?.replies ?? const [],
        remote: incoming.replies,
        uid: uid,
      ),
      likes: incoming.likes,
    );
  }
  final merged = byId.values.toList()..sort((a, b) => b.at.compareTo(a.at));
  return merged;
}

List<PostReply> mergeReplies({
  required List<PostReply> local,
  required List<PostReply> remote,
  required String uid,
}) {
  final byId = {for (final reply in local) reply.id: reply};
  for (final reply in remote) {
    byId[reply.id] = PostReply(
      id: reply.id,
      author: localAuthor(reply.author, uid),
      authorName: reply.authorName,
      body: reply.body,
      at: reply.at,
    );
  }
  final merged = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  return merged;
}

List<ChatMessage> mergeMessages({
  required List<ChatMessage> local,
  required List<ChatMessage> remote,
  required String uid,
  Set<String> hidden = const {},
}) {
  final byId = {for (final message in local) message.id: message};
  for (final message in remote) {
    if (hidden.contains(message.id)) continue;
    final existing = byId[message.id];
    byId[message.id] = ChatMessage(
      id: message.id,
      authorId: localAuthor(message.authorId, uid),
      text: message.text,
      at: message.at,
      replyTo: message.replyTo,
      photo: message.photo ?? existing?.photo,
      unsent: message.unsent,
      edited: message.edited,
      reaction: message.reaction,
    );
  }
  byId.removeWhere((id, _) => hidden.contains(id));
  final merged = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  return merged;
}

List<ChatThread> mergeThreads({
  required List<ChatThread> local,
  required List<ChatThread> remote,
  required String uid,
  Set<String> hidden = const {},
}) {
  final byId = {for (final thread in local) thread.id: thread};
  for (final incoming in remote) {
    final existing = byId[incoming.id];
    final messages = incoming.messages.isEmpty
        ? (existing?.messages ?? const <ChatMessage>[])
        : mergeMessages(
            local: existing?.messages ?? const [],
            remote: incoming.messages,
            uid: uid,
            hidden: hidden,
          );
    byId[incoming.id] = incoming.copyWith(
      messages: messages
          .where((message) => !hidden.contains(message.id))
          .toList(),
      draft: existing?.draft ?? incoming.draft,
    );
  }
  return byId.values.toList();
}

Map<String, dynamic>? _decode(String? encoded) {
  if (encoded == null) return null;
  final value = jsonDecode(encoded);
  return value is Map<String, dynamic> ? value : null;
}

List<CommunityPost> _posts(Map<String, dynamic>? json) =>
    (json?['posts'] as List? ?? const [])
        .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
        .toList();

List<ChatThread> _threads(Map<String, dynamic>? json) =>
    (json?['threads'] as List? ?? const [])
        .map((item) => ChatThread.fromJson(item as Map<String, dynamic>))
        .toList();

String _threadMeta(ChatThread thread) => jsonEncode({
  'id': thread.id,
  'name': thread.name,
  'members': thread.members,
  'group': thread.group,
  'unread': thread.unread,
  'archived': thread.archived,
  'muted': thread.muted,
  'pinned': thread.pinned,
  'left': thread.left,
});

String _messageMeta(ChatMessage message) => jsonEncode({
  ...message.toJson(),
  'photo': message.photo != null && cloudPhoto(message.photo!)
      ? message.photo
      : null,
});

CommunityDelta diffEncoded({
  required String? previousEncoded,
  required String nextEncoded,
  required String uid,
}) {
  final previous = _decode(previousEncoded);
  final next = _decode(nextEncoded);
  if (next == null) return const CommunityDelta();
  final beforePosts = {for (final post in _posts(previous)) post.id: post};
  final afterPosts = {for (final post in _posts(next)) post.id: post};
  final upsertPosts = <CommunityPost>[];
  final deletePostIds = <String>[];
  final upsertReplies = <ReplyChange>[];
  final deleteReplies = <ReplyRemoval>[];

  for (final post in afterPosts.values) {
    final before = beforePosts[post.id];
    if (ownsAuthor(post.authorId, uid)) {
      final payload = jsonEncode(remotePostJson(post, uid));
      if (before == null ||
          jsonEncode(remotePostJson(before, uid)) != payload) {
        upsertPosts.add(post);
      }
    }
    final beforeReplies = {
      for (final reply in before?.replies ?? const []) reply.id: reply,
    };
    final afterReplies = {for (final reply in post.replies) reply.id: reply};
    for (final reply in afterReplies.values) {
      if (!ownsAuthor(reply.author, uid)) continue;
      final prior = beforeReplies[reply.id];
      if (prior == null ||
          jsonEncode(remoteReplyJson(prior, uid)) !=
              jsonEncode(remoteReplyJson(reply, uid))) {
        upsertReplies.add(ReplyChange(post.id, reply));
      }
    }
    for (final reply in beforeReplies.values) {
      if (ownsAuthor(reply.author, uid) &&
          !afterReplies.containsKey(reply.id)) {
        deleteReplies.add(ReplyRemoval(post.id, reply.id));
      }
    }
  }
  for (final post in beforePosts.values) {
    if (ownsAuthor(post.authorId, uid) && !afterPosts.containsKey(post.id)) {
      deletePostIds.add(post.id);
    }
  }

  final beforeThreads = {
    for (final thread in _threads(previous)) thread.id: thread,
  };
  final afterThreads = {for (final thread in _threads(next)) thread.id: thread};
  final upsertThreads = <ChatThread>[];
  final upsertMessages = <MessageChange>[];
  final hiddenMessageIds = <String>[];
  for (final thread in afterThreads.values) {
    final before = beforeThreads[thread.id];
    if (before == null || _threadMeta(before) != _threadMeta(thread)) {
      upsertThreads.add(thread);
    }
    final beforeMessages = {
      for (final message in before?.messages ?? const []) message.id: message,
    };
    final afterMessages = {
      for (final message in thread.messages) message.id: message,
    };
    for (final message in afterMessages.values) {
      if (!ownsAuthor(message.authorId, uid)) continue;
      final prior = beforeMessages[message.id];
      if (prior == null || _messageMeta(prior) != _messageMeta(message)) {
        upsertMessages.add(MessageChange(thread.id, message));
      }
    }
    for (final message in beforeMessages.values) {
      if (!afterMessages.containsKey(message.id)) {
        hiddenMessageIds.add(message.id);
      }
    }
  }

  CommunityProfile? profile;
  final nextProfile = next['profile'];
  final previousProfile = previous?['profile'];
  if (nextProfile is Map &&
      jsonEncode(nextProfile) != jsonEncode(previousProfile)) {
    profile = CommunityProfile.fromJson(Map<String, dynamic>.from(nextProfile));
  }

  return CommunityDelta(
    profile: profile,
    upsertPosts: upsertPosts,
    deletePostIds: deletePostIds,
    upsertReplies: upsertReplies,
    deleteReplies: deleteReplies,
    upsertThreads: upsertThreads,
    upsertMessages: upsertMessages,
    hiddenMessageIds: hiddenMessageIds,
  );
}
