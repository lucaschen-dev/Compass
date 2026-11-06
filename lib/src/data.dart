import 'dart:convert';

typedef Json = Map<String, dynamic>;
List<Json> rows(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
Json clone(Json value) => jsonDecode(jsonEncode(value)) as Json;
String text(Json value, String key, [String fallback = '']) =>
    value[key]?.toString() ?? fallback;
String newID() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
String initials(Json person) => text(
  person,
  'name',
).split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join();
const kinds = {
  'Question': 'Q&A',
  'Club Meeting': 'Clubs',
  'Events': 'School Events',
  'Lost & Found': 'Lost & Found',
  'Photo Gallery': 'Photo Gallery',
  'General': 'Other',
};
String kindLabel(String kind) =>
    kind == 'Advice' ? 'Q&A' : kinds[kind] ?? 'Other';
String authorName(Json post) => post['anonymous'] == true
    ? 'Anonymous student'
    : text(post['author'] as Json? ?? {}, 'name', 'Deleted account');
String chatName(Json chat) => chat['kind'] == 'group'
    ? text(chat, 'title')
    : text(chat['peer'] as Json? ?? {}, 'name');
String messagePreview(Json message) => message['retracted'] == true
    ? 'Message unsent'
    : text(message, 'body').isNotEmpty
    ? text(message, 'body')
    : message['mediaKind'] == 'video'
    ? 'Video'
    : 'Photo';
final demoMe = <String, dynamic>{
  'id': 'lucas',
  'name': 'Lucas Chen',
  'year': 'Grade 11',
  'bio': 'Biology, violin & finding my people. Happy to help new students settle in.',
  'instagram': '',
  'role': 'Student',
};
final demoMaya = <String, dynamic>{
  'id': 'maya',
  'name': 'Maya Taylor',
  'year': 'Grade 12',
  'bio': 'Student mentor. Ask me about clubs, classes, or your first week.',
  'instagram': '',
  'role': 'Mentor',
};
final demoAlex = <String, dynamic>{
  'id': 'alex',
  'name': 'Alex Kim',
  'year': 'Grade 11',
  'bio': 'A familiar face for your first club meeting.',
  'instagram': '',
  'role': 'Student',
};
Json demoSnapshot() {
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  Json post(
    String id,
    String title,
    String body,
    String kind,
    Json? author,
    String group,
    int age, {
    bool pinned = false,
  }) => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'author': author,
    'anonymous': author == null,
    'groupID': group,
    'groupName': group == 'mentors'
        ? 'Student mentors'
        : group == 'clubs'
        ? 'Club community'
        : 'Everyone',
    'visibility': 'school',
    'important': pinned,
    'createdAt': now - age,
    'replies': <Json>[],
  };
  final question = post(
    'question',
    'How do you join a conversation at lunch?',
    'I just moved here and everyone seems to know each other already. What helped you make your first friends?',
    'Question',
    null,
    'mentors',
    3600,
  );
  question['replies'] = [
    {
      'id': 'reply',
      'author': demoMaya,
      'body': 'Start with one familiar face from class. Asking to sit together is enough — you do not need a perfect opening line.',
    },
  ];
  return clone({
    'me': demoMe,
    'groups': [
      {'id': 'all', 'name': 'Everyone', 'isMember': true},
      {'id': 'mentors', 'name': 'Student mentors', 'isMember': false},
      {
        'id': 'international',
        'name': 'International students',
        'isMember': true,
      },
      {'id': 'freshmen', 'name': 'Freshmen', 'isMember': false},
      {'id': 'clubs', 'name': 'Club community', 'isMember': true},
    ],
    'posts': [
      post(
        'welcome',
        'Your first week, a little easier.',
        'New here? Leave a question below. Our student mentors can help you find a club, understand campus life, or meet someone before your first lunch. This is sample content, not a school announcement.',
        'Advice',
        demoMaya,
        'all',
        600,
        pinned: true,
      ),
      post(
        'club',
        'A seat at the table. Come meet the club.',
        'Sample meeting · Wednesday, 12:30 PM · Courtyard. Curious about joining? No experience needed. Ask a question below or message Alex to walk over together.',
        'Club Meeting',
        demoAlex,
        'clubs',
        1800,
      ),
      question,
      post(
        'lost',
        'Found: a blue water bottle',
        'Sample lost item · Near the library. Message me with the sticker on it so I can get it back to the right person.',
        'Lost & Found',
        demoAlex,
        'all',
        7200,
      ),
    ],
    'conversations': [
      {
        'id': 'maya-chat',
        'peer': demoMaya,
        'kind': 'direct',
        'title': '',
        'participants': [demoMe, demoMaya],
        'messages': [
          {
            'id': 'hello',
            'senderID': 'maya',
            'body': 'Welcome to Community! This is a sample conversation. Demo messages stay on your device and do not reach a real person.',
            'createdAt': now - 1800,
          },
        ],
      },
    ],
  });
}
