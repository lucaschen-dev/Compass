enum MeetupTime {
  any('Any time'),
  lunch('Lunch'),
  afterSchool('After school');

  const MeetupTime(this.label);
  final String label;
}

class DemoActivity {
  const DemoActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.interests,
    required this.meetupTime,
    required this.when,
    required this.location,
    this.leaderIds = const [],
    this.memberIds = const [],
  });

  final String id;
  final String title;
  final String description;
  final List<String> interests;
  final MeetupTime meetupTime;
  final String when;
  final String location;
  final List<String> leaderIds;
  final List<String> memberIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'interests': interests,
    'meetupTime': meetupTime.name,
    'when': when,
    'location': location,
    'leaderIds': leaderIds,
    'memberIds': memberIds,
  };

  factory DemoActivity.fromJson(Map<String, dynamic> json) => DemoActivity(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    interests: (json['interests'] as List? ?? const []).cast<String>(),
    meetupTime: MeetupTime.values.firstWhere(
      (time) => time.name == json['meetupTime'],
      orElse: () => MeetupTime.any,
    ),
    when: json['when'] as String? ?? '',
    location: json['location'] as String? ?? '',
    leaderIds: (json['leaderIds'] as List? ?? const []).cast<String>(),
    memberIds: (json['memberIds'] as List? ?? const []).cast<String>(),
  );
}

// Fictional opportunities belonging only to their respective demo school.
const alderlineClubs = [
  DemoActivity(
    id: 'robotics-lab',
    title: 'Robotics Lab',
    description: 'Build a practice robot with a team. Beginners are welcome.',
    interests: ['Robotics', 'Design'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Wednesdays · 3:30 PM',
    location: 'Makerspace',
    leaderIds: ['jordan-ellis'],
    memberIds: ['jordan-ellis', 'leo-park', 'maya-chen'],
  ),
  DemoActivity(
    id: 'sketchbook-circle',
    title: 'Sketchbook Circle',
    description: 'Bring a sketchbook and try a new drawing prompt each week.',
    interests: ['Drawing', 'Design'],
    meetupTime: MeetupTime.lunch,
    when: 'Tuesdays · Lunch',
    location: 'Art studio',
    leaderIds: ['amara-brooks'],
    memberIds: ['amara-brooks', 'maya-chen'],
  ),
  DemoActivity(
    id: 'library-lounge',
    title: 'Library Lounge',
    description: 'Swap book recommendations or join a tabletop game.',
    interests: ['Reading', 'Board games'],
    meetupTime: MeetupTime.lunch,
    when: 'Wednesdays · Lunch',
    location: 'Library commons',
    leaderIds: ['amara-brooks'],
    memberIds: ['amara-brooks', 'leo-park'],
  ),
  DemoActivity(
    id: 'badminton-club',
    title: 'Badminton Club',
    description: 'Practice serves and play friendly doubles matches.',
    interests: ['Badminton'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Tuesdays · 3:30 PM',
    location: 'Gym',
    leaderIds: ['leo-park'],
    memberIds: ['leo-park', 'jordan-ellis'],
  ),
  DemoActivity(
    id: 'campus-lens',
    title: 'Campus Lens',
    description: 'Photograph campus life and help welcome new students.',
    interests: ['Photography', 'Student ambassadors'],
    meetupTime: MeetupTime.lunch,
    when: 'Mondays · Lunch',
    location: 'Student Commons',
    leaderIds: ['maya-chen'],
    memberIds: ['maya-chen', 'amara-brooks'],
  ),
];

const alderlineEvents = [
  DemoActivity(
    id: 'robotics-open-lab',
    title: 'Robotics open lab',
    description: 'Meet Jordan and try driving the team’s practice robot.',
    interests: ['Robotics', 'Design'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Thursday · 3:30 PM',
    location: 'Makerspace',
  ),
  DemoActivity(
    id: 'sketch-and-read',
    title: 'Sketch and read',
    description: 'Draw a scene from a favorite book with the sketchbook group.',
    interests: ['Drawing', 'Reading'],
    meetupTime: MeetupTime.lunch,
    when: 'Friday · Lunch',
    location: 'Library courtyard',
  ),
  DemoActivity(
    id: 'board-game-lunch',
    title: 'Board game lunch',
    description:
        'Join a short game. The table has a place for first-time players.',
    interests: ['Board games'],
    meetupTime: MeetupTime.lunch,
    when: 'Thursday · Lunch',
    location: 'Library commons',
  ),
  DemoActivity(
    id: 'badminton-taster',
    title: 'Beginner badminton',
    description: 'Borrow a racket and learn a few basics with Leo.',
    interests: ['Badminton'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Friday · 3:30 PM',
    location: 'Gym',
  ),
  DemoActivity(
    id: 'campus-photo-walk',
    title: 'Campus photo walk',
    description: 'Find a new angle on campus with Maya and the welcome team.',
    interests: ['Photography', 'Student ambassadors'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Wednesday · 3:20 PM',
    location: 'Student Commons',
  ),
];

const cedarbrookClubs = [
  DemoActivity(
    id: 'stage-crew',
    title: 'Stage Crew',
    description:
        'Help bring a performance to life with sound, lighting, and sets.',
    interests: ['Theater', 'Music'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Wednesdays · 3:30 PM',
    location: 'Auditorium',
    leaderIds: ['noah-bennett'],
    memberIds: ['noah-bennett', 'eli-torres'],
  ),
  DemoActivity(
    id: 'yearbook-lab',
    title: 'Yearbook Lab',
    description: 'Tell the story of the school year through photographs.',
    interests: ['Photography'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Thursdays · 3:30 PM',
    location: 'Media studio',
    leaderIds: ['eli-torres'],
    memberIds: ['eli-torres', 'tessa-wu'],
  ),
  DemoActivity(
    id: 'garden-club',
    title: 'Garden Club',
    description: 'Grow seedlings and look after the school garden together.',
    interests: ['Gardening'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Fridays · 3:30 PM',
    location: 'Greenhouse',
    leaderIds: ['eli-torres'],
    memberIds: ['eli-torres', 'tessa-wu', 'noah-bennett'],
  ),
  DemoActivity(
    id: 'walking-club',
    title: 'Walking Club',
    description: 'Explore a short campus route during the lunch break.',
    interests: ['Hiking'],
    meetupTime: MeetupTime.lunch,
    when: 'Thursdays · Lunch',
    location: 'Courtyard',
    leaderIds: ['tessa-wu'],
    memberIds: ['tessa-wu', 'eli-torres'],
  ),
  DemoActivity(
    id: 'reading-circle',
    title: 'Reading Circle',
    description: 'Share what you are reading in a relaxed small group.',
    interests: ['Reading'],
    meetupTime: MeetupTime.lunch,
    when: 'Tuesdays · Lunch',
    location: 'Study commons',
    leaderIds: ['tessa-wu'],
    memberIds: ['tessa-wu', 'noah-bennett'],
  ),
];

const cedarbrookEvents = [
  DemoActivity(
    id: 'stage-open-house',
    title: 'Stage crew open house',
    description: 'Meet Noah, try the lighting desk, and tour the costume shop.',
    interests: ['Theater', 'Music'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Wednesday · 3:30 PM',
    location: 'Auditorium lobby',
  ),
  DemoActivity(
    id: 'golden-hour-walk',
    title: 'Golden-hour photo walk',
    description: 'Bring a camera or phone for a short outdoor walk with Eli.',
    interests: ['Photography', 'Hiking'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Friday · 3:30 PM',
    location: 'Courtyard',
  ),
  DemoActivity(
    id: 'garden-volunteer',
    title: 'Garden volunteer hour',
    description:
        'Help pot seedlings. Gloves and tools are available to borrow.',
    interests: ['Gardening'],
    meetupTime: MeetupTime.afterSchool,
    when: 'Friday · 3:30 PM',
    location: 'Greenhouse',
  ),
  DemoActivity(
    id: 'book-swap',
    title: 'Courtyard book swap',
    description:
        'Bring a book to trade or pick up a recommendation from Tessa.',
    interests: ['Reading'],
    meetupTime: MeetupTime.lunch,
    when: 'Wednesday · Lunch',
    location: 'Courtyard',
  ),
  DemoActivity(
    id: 'campus-trail-walk',
    title: 'Campus trail walk',
    description: 'Take a gentle loop past the garden with the walking club.',
    interests: ['Hiking'],
    meetupTime: MeetupTime.lunch,
    when: 'Friday · Lunch',
    location: 'Courtyard',
  ),
];
