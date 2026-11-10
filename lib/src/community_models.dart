import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_accounts.dart';
import 'school_demo.dart';

enum PostCategory {
  question('Q&A'),
  club('Clubs'),
  event('School Events'),
  lost('Lost & Found'),
  gallery('Photo Gallery'),
  other('Other');

  const PostCategory(this.label);
  final String label;
  List<String> get subtags => switch (this) {
    club => ['Badminton', 'Robotics', 'Music', 'Art', 'Volunteering'],
    event => ['Sports', 'Arts', 'Campus', 'Volunteering'],
    question => ['Classes', 'Campus', 'Student life'],
    lost => ['Found', 'Lost'],
    gallery => ['Campus', 'Sports', 'Arts'],
    other => ['Student life', 'Study', 'Resources'],
  };
}

class CommunityProfile {
  const CommunityProfile({
    required this.name,
    required this.grade,
    this.bio = '',
    this.avatar,
  });
  final String name;
  final int grade;
  final String bio;
  final String? avatar;
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((s) => s.isEmpty ? '' : s[0])
      .join()
      .toUpperCase();
  Map<String, Object?> toJson() => {
    'name': name,
    'grade': grade,
    'bio': bio,
    'avatar': avatar,
  };
  factory CommunityProfile.fromJson(Map<String, dynamic> j) => CommunityProfile(
    name: j['name'] as String,
    grade: j['grade'] as int,
    bio: j['bio'] as String? ?? '',
    avatar: j['avatar'] as String?,
  );
}

class PostReply {
  const PostReply({
    required this.id,
    required this.author,
    required this.body,
    required this.at,
  });
  final String id;
  final String author;
  final String body;
  final DateTime at;
  Map<String, Object> toJson() => {
    'id': id,
    'author': author,
    'body': body,
    'at': at.toIso8601String(),
  };
  factory PostReply.fromJson(Map<String, dynamic> j) => PostReply(
    id: j['id'] as String,
    author: j['author'] as String,
    body: j['body'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.category,
    required this.subtag,
    required this.at,
    this.anonymous = false,
    this.priority = 'Normal',
    this.askedPerson,
    this.photos = const [],
    this.replies = const [],
    this.likes = 0,
  });
  final String id, authorId, title, body, subtag, priority;
  final PostCategory category;
  final DateTime at;
  final bool anonymous;
  final String? askedPerson;
  final List<String> photos;
  final List<PostReply> replies;
  final int likes;
  bool get important =>
      priority != 'Normal' &&
      !DateTime.now().isBefore(at) &&
      DateTime.now().difference(at) < const Duration(hours: 24);
  CommunityPost copyWith({bool? anonymous, List<PostReply>? replies}) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        title: title,
        body: body,
        category: category,
        subtag: subtag,
        at: at,
        anonymous: anonymous ?? this.anonymous,
        priority: priority,
        askedPerson: askedPerson,
        photos: photos,
        replies: replies ?? this.replies,
        likes: likes,
      );
  Map<String, Object?> toJson() => {
    'id': id,
    'authorId': authorId,
    'title': title,
    'body': body,
    'category': category.name,
    'subtag': subtag,
    'at': at.toIso8601String(),
    'anonymous': anonymous,
    'priority': priority,
    'askedPerson': askedPerson,
    'photos': photos,
    'replies': replies.map((r) => r.toJson()).toList(),
    'likes': likes,
  };
  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
    id: j['id'] as String,
    authorId: j['authorId'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    category: PostCategory.values.byName(j['category'] as String),
    subtag: j['subtag'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
    anonymous: j['anonymous'] == true,
    priority: j['priority'] as String? ?? 'Normal',
    askedPerson: j['askedPerson'] as String?,
    photos: List<String>.from(j['photos'] as List? ?? []),
    replies: (j['replies'] as List? ?? [])
        .map((r) => PostReply.fromJson(r as Map<String, dynamic>))
        .toList(),
    likes: j['likes'] as int? ?? 0,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.authorId,
    required this.text,
    required this.at,
    this.replyTo,
    this.photo,
    this.unsent = false,
    this.edited = false,
    this.reaction,
  });
  final String id, authorId, text;
  final DateTime at;
  final String? replyTo, photo, reaction;
  final bool unsent, edited;
  bool canUnsend(DateTime now) =>
      authorId == 'me' &&
      !unsent &&
      now.difference(at) <= const Duration(minutes: 2);
  ChatMessage copyWith({
    String? text,
    bool? unsent,
    bool? edited,
    String? reaction,
  }) => ChatMessage(
    id: id,
    authorId: authorId,
    text: text ?? this.text,
    at: at,
    replyTo: (unsent ?? this.unsent) ? null : replyTo,
    photo: (unsent ?? this.unsent) ? null : photo,
    unsent: unsent ?? this.unsent,
    edited: edited ?? this.edited,
    reaction: reaction ?? this.reaction,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'authorId': authorId,
    'text': text,
    'at': at.toIso8601String(),
    'replyTo': replyTo,
    'photo': photo,
    'unsent': unsent,
    'edited': edited,
    'reaction': reaction,
  };
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    authorId: j['authorId'] as String,
    text: j['text'] as String,
    at: DateTime.parse(j['at'] as String),
    replyTo: j['replyTo'] as String?,
    photo: j['photo'] as String?,
    unsent: j['unsent'] == true,
    edited: j['edited'] == true,
    reaction: j['reaction'] as String?,
  );
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.name,
    required this.members,
    required this.messages,
    this.group = false,
    this.unread = 0,
    this.archived = false,
    this.muted = false,
    this.pinned = false,
    this.left = false,
    this.draft = '',
  });
  final String id, name, draft;
  final List<String> members;
  final List<ChatMessage> messages;
  final bool group, archived, muted, pinned, left;
  final int unread;
  ChatThread copyWith({
    List<ChatMessage>? messages,
    int? unread,
    bool? archived,
    bool? muted,
    bool? pinned,
    bool? left,
    String? draft,
  }) => ChatThread(
    id: id,
    name: name,
    members: members,
    messages: messages ?? this.messages,
    group: group,
    unread: unread ?? this.unread,
    archived: archived ?? this.archived,
    muted: muted ?? this.muted,
    pinned: pinned ?? this.pinned,
    left: left ?? this.left,
    draft: draft ?? this.draft,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'members': members,
    'messages': messages.map((m) => m.toJson()).toList(),
    'group': group,
    'unread': unread,
    'archived': archived,
    'muted': muted,
    'pinned': pinned,
    'left': left,
    'draft': draft,
  };
  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
    id: j['id'] as String,
    name: j['name'] as String,
    members: List<String>.from(j['members'] as List),
    messages: (j['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    group: j['group'] == true,
    unread: j['unread'] as int? ?? 0,
    archived: j['archived'] == true,
    muted: j['muted'] == true,
    pinned: j['pinned'] == true,
    left: j['left'] == true,
    draft: j['draft'] as String? ?? '',
  );
}

String communityStoreKey(DemoSchool school, LocalAccount account) =>
    'compass.preview.${school.id}.community.${Uri.encodeComponent(account.email)}';

class CommunityController extends ChangeNotifier {
  CommunityController({
    required this.school,
    required LocalAccount account,
    required this.write,
    Object? saved,
  }) : profile = CommunityProfile(name: account.name, grade: account.grade) {
    posts = samplePosts(school);
    threads = sampleThreads(school, currentName: account.name);
    if (saved is String) {
      try {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        profile = CommunityProfile.fromJson(
          j['profile'] as Map<String, dynamic>,
        );
        posts = (j['posts'] as List)
            .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
            .toList();
        threads = (j['threads'] as List)
            .map((t) => ChatThread.fromJson(t as Map<String, dynamic>))
            .toList();
        savedPosts = Set<String>.from(j['saved'] as List? ?? []);
        likedPosts = Set<String>.from(j['liked'] as List? ?? []);
        followedTags = Set<String>.from(j['tags'] as List? ?? []);
        composerDraft = Map<String, dynamic>.from(
          j['composerDraft'] as Map? ?? {},
        );
      } catch (_) {
        posts = samplePosts(school);
        threads = sampleThreads(school, currentName: account.name);
      }
    }
  }
  final DemoSchool school;
  final Future<void> Function(String) write;
  late CommunityProfile profile;
  late List<CommunityPost> posts;
  late List<ChatThread> threads;
  Set<String> savedPosts = {}, likedPosts = {}, followedTags = {};
  Map<String, dynamic> composerDraft = {};
  Future<void> _tail = Future.value();
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int _nonce = 0;
  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_nonce++}';
  String authorName(String id) => id == 'me'
      ? profile.name
      : id.startsWith('staff:')
      ? id.substring(6)
      : school.classmates.where((p) => p.id == id).firstOrNull?.name ??
            'Student life';
  String encode() => jsonEncode({
    'version': 1,
    'profile': profile.toJson(),
    'posts': posts.map((p) => p.toJson()).toList(),
    'threads': threads.map((t) => t.toJson()).toList(),
    'saved': savedPosts.toList(),
    'liked': likedPosts.toList(),
    'tags': followedTags.toList(),
    'composerDraft': composerDraft,
  });
  Future<void> change(VoidCallback apply) {
    final next = _tail.catchError((_) {}).then((_) async {
      final previous = encode();
      apply();
      try {
        await write(encode());
        if (!_disposed) notifyListeners();
      } catch (_) {
        final j = jsonDecode(previous) as Map<String, dynamic>;
        profile = CommunityProfile.fromJson(
          j['profile'] as Map<String, dynamic>,
        );
        posts = (j['posts'] as List)
            .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
            .toList();
        threads = (j['threads'] as List)
            .map((t) => ChatThread.fromJson(t as Map<String, dynamic>))
            .toList();
        savedPosts = Set<String>.from(j['saved'] as List);
        likedPosts = Set<String>.from(j['liked'] as List);
        followedTags = Set<String>.from(j['tags'] as List);
        composerDraft = Map<String, dynamic>.from(j['composerDraft'] as Map);
        rethrow;
      }
    });
    _tail = next;
    return next;
  }

  Future<void> toggleSaved(String id) => change(
    () => savedPosts.contains(id) ? savedPosts.remove(id) : savedPosts.add(id),
  );
  Future<void> toggleLiked(String id) => change(
    () => likedPosts.contains(id) ? likedPosts.remove(id) : likedPosts.add(id),
  );
  Future<void> updateThread(ChatThread thread) => change(
    () => threads = [
      for (final t in threads)
        if (t.id == thread.id) thread else t,
    ],
  );
  Future<void> patchThread(String id, {String? draft, int? unread}) =>
      change(() {
        threads = [
          for (final t in threads)
            if (t.id == id) t.copyWith(draft: draft, unread: unread) else t,
        ];
      });
  Future<void> send(
    String threadId, {
    required String text,
    String? replyTo,
    String? photo,
  }) => change(() {
    final thread = threads.where((t) => t.id == threadId).firstOrNull;
    if (thread == null || thread.left) {
      throw StateError('This conversation is unavailable.');
    }
    if (replyTo != null && !thread.messages.any((m) => m.id == replyTo)) {
      throw ArgumentError('Reply to a message in this conversation.');
    }
    if (text.trim().isEmpty && photo == null) {
      throw ArgumentError('Enter a message.');
    }
    if (text.trim().length > 2000) {
      throw ArgumentError('Use at most 2,000 characters.');
    }
    threads = [
      for (final t in threads)
        if (t.id != threadId)
          t
        else if (t.left)
          throw StateError('You left this group.')
        else
          t.copyWith(
            messages: [
              ...t.messages,
              ChatMessage(
                id: newId(),
                authorId: 'me',
                text: text.trim(),
                at: DateTime.now(),
                replyTo: replyTo,
                photo: photo,
              ),
            ],
            draft: '',
            unread: 0,
          ),
    ];
  });
  Future<void> retract(String threadId, String messageId, DateTime now) =>
      change(() {
        threads = [
          for (final t in threads)
            if (t.id != threadId)
              t
            else
              t.copyWith(
                messages: [
                  for (final m in t.messages)
                    if (m.id != messageId)
                      m
                    else if (!m.canUnsend(now))
                      throw StateError(
                        'Messages can be unsent for two minutes.',
                      )
                    else
                      m.copyWith(text: '', unsent: true, reaction: ''),
                ],
              ),
        ];
      });
}

List<CommunityPost> samplePosts(DemoSchool school) {
  final now = DateTime.now();
  final people = school.classmates;
  final first = people.first.id;
  final second = people.length > 1 ? people[1].id : first;
  return [
    CommunityPost(
      id: '${school.id}-badminton',
      authorId: first,
      title: 'Anyone up for a match?',
      body: 'Open gym after school. Bring a racket or borrow one of ours. All levels welcome.',
      category: PostCategory.club,
      subtag: 'Badminton',
      at: now.subtract(const Duration(minutes: 12)),
      likes: 8,
    ),
    CommunityPost(
      id: '${school.id}-question',
      authorId: second,
      title: school.id == 'alderline'
          ? 'Where is the art studio?'
          : 'Where does stage crew meet?',
      body: 'First week here. Which building should I head to?',
      category: PostCategory.question,
      subtag: 'Campus',
      at: now.subtract(const Duration(minutes: 38)),
      likes: 3,
    ),
    for (var i = 0; i < school.announcements.length; i++)
      CommunityPost(
        id: '${school.id}-notice-$i',
        authorId: 'staff:${school.announcements[i].author}',
        title: school.announcements[i].title,
        body: school.announcements[i].message,
        category: school.announcements[i].title.toLowerCase().contains('robot')
            ? PostCategory.club
            : PostCategory.event,
        subtag: school.announcements[i].title.toLowerCase().contains('robot')
            ? 'Robotics'
            : 'Campus',
        at: now.subtract(Duration(hours: i + 2)),
        priority: i == 0 ? 'Important' : 'Normal',
      ),
  ];
}

List<ChatThread> sampleThreads(DemoSchool school, {String? currentName}) {
  final now = DateTime.now();
  return [
    for (final c in school.conversations)
      ChatThread(
        id: 'direct-${c.personId}',
        name: school.classmate(c.personId).name,
        members: [c.personId, 'me'],
        unread: 1,
        messages: [
          for (var i = 0; i < c.messages.length; i++)
            ChatMessage(
              id: '${c.personId}-$i',
              authorId: c.messages[i].senderId == school.student.id
                  ? 'me'
                  : c.messages[i].senderId,
              text: c.messages[i].text.replaceAll(
                RegExp(
                  r'\b' +
                      RegExp.escape(school.student.name.split(' ').first) +
                      r'\b',
                ),
                (currentName ?? school.student.name).split(' ').first,
              ),
              at: now.subtract(Duration(minutes: 20 - i)),
            ),
        ],
      ),
    ChatThread(
      id: '${school.id}-badminton-group',
      name: 'Badminton Club',
      members: ['me', ...school.classmates.take(3).map((p) => p.id)],
      group: true,
      messages: [
        ChatMessage(
          id: 'club-welcome',
          authorId: school.classmates.first.id,
          text: 'Training is at 4 today. Meet at the gym!',
          at: now.subtract(const Duration(hours: 1)),
        ),
      ],
    ),
  ];
}
