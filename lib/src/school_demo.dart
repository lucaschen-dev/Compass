import 'demo_activities.dart';

class DemoPerson {
  const DemoPerson({
    required this.id,
    required this.name,
    required this.grade,
    required this.bio,
    required this.interests,
  });

  final String id;
  final String name;
  final int grade;
  final String bio;
  final List<String> interests;

  String get initials => name.split(' ').map((part) => part[0]).join();
}

class DemoAnnouncement {
  const DemoAnnouncement({
    required this.title,
    required this.message,
    required this.label,
    required this.when,
    required this.author,
  });

  final String title;
  final String message;
  final String label;
  final String when;
  final String author;
}

class DemoConversation {
  const DemoConversation({required this.personId, required this.messages});

  final String personId;
  final List<DemoMessage> messages;
}

class DemoMessage {
  const DemoMessage(this.senderId, this.text, this.time);

  final String senderId;
  final String text;
  final String time;
}

class DemoSchool {
  const DemoSchool({
    required this.id,
    required this.name,
    required this.location,
    required this.initials,
    required this.student,
    required this.classmates,
    required this.announcements,
    required this.conversations,
    required this.guide,
    required this.courses,
    required this.graduationRequirements,
    this.clubs = const [],
    this.events = const [],
  });

  final String id;
  final String name;
  final String location;
  final String initials;
  final DemoPerson student;
  final List<DemoPerson> classmates;
  final List<DemoAnnouncement> announcements;
  final List<DemoConversation> conversations;
  final List<DemoGuideItem> guide;
  final List<DemoCourse> courses;
  final List<DemoCreditRequirement> graduationRequirements;
  final List<DemoActivity> clubs;
  final List<DemoActivity> events;

  DemoPerson classmate(String id) =>
      classmates.firstWhere((person) => person.id == id);
}

class DemoGuideItem {
  const DemoGuideItem(this.id, this.category, this.title, this.description);

  final String id;
  final String category;
  final String title;
  final String description;
}

class DemoCourse {
  const DemoCourse({
    required this.id,
    required this.title,
    required this.subject,
    required this.credits,
    required this.description,
    this.prerequisites = const [],
  });

  final String id;
  final String title;
  final String subject;
  final int credits;
  final String description;
  final List<String> prerequisites;
}

class DemoCreditRequirement {
  const DemoCreditRequirement(this.subject, this.credits);

  final String subject;
  final int credits;
}

const _alderlineStudent = DemoPerson(
  id: 'sam-rivera',
  name: 'Sam Rivera',
  grade: 9,
  bio: 'New to Alderline. I like sketching after school and want to try robotics.',
  interests: ['Drawing', 'Robotics', 'Badminton'],
);

const _maya = DemoPerson(
  id: 'maya-chen',
  name: 'Maya Chen',
  grade: 9,
  bio: 'I help with welcome tours and love taking photos around campus.',
  interests: ['Photography', 'Student ambassadors'],
);

const _jordan = DemoPerson(
  id: 'jordan-ellis',
  name: 'Jordan Ellis',
  grade: 10,
  bio: 'Usually working on a robot or figuring out how to fix one.',
  interests: ['Robotics', 'Design'],
);

const _alderlineClassmates = [
  _maya,
  _jordan,
  DemoPerson(
    id: 'amara-brooks',
    name: 'Amara Brooks',
    grade: 9,
    bio: 'I bring a sketchbook everywhere and like quiet afternoons in the library.',
    interests: ['Drawing', 'Reading'],
  ),
  DemoPerson(
    id: 'leo-park',
    name: 'Leo Park',
    grade: 10,
    bio: 'Come find me at badminton or at the board game table after school.',
    interests: ['Badminton', 'Board games'],
  ),
];

const _alderlineAnnouncements = [
  DemoAnnouncement(
    title: 'New student welcome tour',
    message:
        'Meet the student ambassadors at the Student Commons during '
        'Monday lunch. They’ll show you the library, main office, and club noticeboard.',
    label: 'Student life',
    when: 'Monday · Lunch',
    author: 'Student Life Office',
  ),
  DemoAnnouncement(
    title: 'Library quiet hours',
    message:
        'The back tables are for quiet study during lunch. For group '
        'work or help finding a room, check with the librarian at the front desk.',
    label: 'Campus notice',
    when: 'Every school day · Lunch',
    author: 'Alderline Library',
  ),
  DemoAnnouncement(
    title: 'Friday spirit day',
    message:
        'Wear burgundy or cream if you’d like to join in. Usual '
        'classroom and lab dress requirements apply throughout the day.',
    label: 'School event',
    when: 'Friday · All day',
    author: 'Student Council',
  ),
  DemoAnnouncement(
    title: 'Try the robotics open lab',
    message:
        'I’ll be in the makerspace on Thursday after school. Stop by '
        'to try driving our practice robot. Beginners are welcome!',
    label: 'Student post',
    when: 'Thursday · After school',
    author: 'Jordan Ellis',
  ),
];

const _alderlineConversations = [
  DemoConversation(
    personId: 'maya-chen',
    messages: [
      DemoMessage(
        'maya-chen',
        'Hey Sam! Are you coming to the welcome tour at lunch?',
        '8:40 AM',
      ),
      DemoMessage('sam-rivera', 'Yes! Where should I meet you?', '8:43 AM'),
      DemoMessage(
        'maya-chen',
        'The Student Commons. I’ll be by the club noticeboard.',
        '8:45 AM',
      ),
    ],
  ),
  DemoConversation(
    personId: 'jordan-ellis',
    messages: [
      DemoMessage(
        'sam-rivera',
        'Do I need any experience to come to robotics open lab?',
        '3:22 PM',
      ),
      DemoMessage(
        'jordan-ellis',
        'You can start with the practice robot. See you Thursday in the makerspace!',
        '3:28 PM',
      ),
    ],
  ),
];

const demoSchools = [
  DemoSchool(
    id: 'alderline',
    clubs: alderlineClubs,
    events: alderlineEvents,
    name: 'Alderline High School',
    location: 'North Wren Valley',
    initials: 'AH',
    student: _alderlineStudent,
    classmates: _alderlineClassmates,
    announcements: _alderlineAnnouncements,
    conversations: _alderlineConversations,
    guide: [
      DemoGuideItem(
        'alderline-welcome-tour',
        'Unwritten rules',
        'Joining the welcome tour',
        'Meet the student guides at the Student Commons during lunch on '
            'Monday. You can come on your own and they’ll introduce you.',
      ),
      DemoGuideItem(
        'alderline-library-etiquette',
        'Unwritten rules',
        'Using the library',
        'The back tables are quiet during lunch. If you’re working with '
            'a group or need help, check with the librarian at the front desk.',
      ),
      DemoGuideItem(
        'alderline-science-lab-attire',
        'Dress code',
        'Dressing for science labs',
        'Wear closed-toe shoes on lab days and tie back long hair before '
            'you start an experiment.',
      ),
      DemoGuideItem(
        'alderline-spirit-day',
        'Dress code',
        'What to wear on spirit days',
        'On Friday spirit days, burgundy or cream is optional. Follow '
            'the usual classroom and science lab dress rules.',
      ),
    ],
    courses: [
      DemoCourse(
        id: 'english-9',
        title: 'English 9',
        subject: 'English',
        credits: 1,
        description: 'Read short fiction and practice analytical writing.',
      ),
      DemoCourse(
        id: 'algebra-i',
        title: 'Algebra I',
        subject: 'Mathematics',
        credits: 1,
        description: 'Work with equations, graphs, and functions.',
      ),
      DemoCourse(
        id: 'geometry',
        title: 'Geometry',
        subject: 'Mathematics',
        credits: 1,
        prerequisites: ['Algebra I'],
        description: 'Explore shapes, measurement, and geometric proofs.',
      ),
      DemoCourse(
        id: 'biology',
        title: 'Biology',
        subject: 'Science',
        credits: 1,
        description: 'Study cells, genetics, and ecosystems through lab work.',
      ),
      DemoCourse(
        id: 'visual-design',
        title: 'Visual Design',
        subject: 'Arts',
        credits: 1,
        description: 'Build a portfolio in drawing and digital composition.',
      ),
    ],
    graduationRequirements: [
      DemoCreditRequirement('English', 4),
      DemoCreditRequirement('Mathematics', 3),
      DemoCreditRequirement('Science', 3),
      DemoCreditRequirement('Social Studies', 3),
      DemoCreditRequirement('Arts', 1),
      DemoCreditRequirement('Physical Education', 2),
      DemoCreditRequirement('Electives', 4),
    ],
  ),
  DemoSchool(
    id: 'cedarbrook',
    clubs: cedarbrookClubs,
    events: cedarbrookEvents,
    name: 'Cedarbrook High School',
    location: 'Foxwillow Bay',
    initials: 'CH',
    student: DemoPerson(
      id: 'riley-morgan',
      name: 'Riley Morgan',
      grade: 10,
      bio: 'I’m new to Cedarbrook. I like photography and want to try stage crew.',
      interests: ['Photography', 'Theater', 'Hiking'],
    ),
    classmates: [
      DemoPerson(
        id: 'noah-bennett',
        name: 'Noah Bennett',
        grade: 10,
        bio: 'I help with stage crew and like showing people around the theater.',
        interests: ['Theater', 'Music'],
      ),
      DemoPerson(
        id: 'eli-torres',
        name: 'Eli Torres',
        grade: 11,
        bio: 'I take pictures for the yearbook and help in the school garden.',
        interests: ['Photography', 'Gardening'],
      ),
      DemoPerson(
        id: 'tessa-wu',
        name: 'Tessa Wu',
        grade: 10,
        bio: 'I spend lunch outdoors and help plan the walking club routes.',
        interests: ['Hiking', 'Reading'],
      ),
    ],
    announcements: [
      DemoAnnouncement(
        title: 'Transfer student breakfast',
        message:
            'Meet peer guides in the courtyard before first period on Tuesday. '
            'Bring your class schedule if you’d like help finding your rooms.',
        label: 'Student life',
        when: 'Tuesday · Before school',
        author: 'Cedarbrook Counseling',
      ),
      DemoAnnouncement(
        title: 'Stage crew open house',
        message:
            'Try the lighting desk or tour the costume shop. Meet at the '
            'auditorium lobby after school on Wednesday.',
        label: 'School event',
        when: 'Wednesday · After school',
        author: 'Theater Club',
      ),
      DemoAnnouncement(
        title: 'Garden volunteer hour',
        message:
            'Join the garden club by the greenhouse on Friday. Gloves and '
            'tools are available to borrow.',
        label: 'Student post',
        when: 'Friday · After school',
        author: 'Eli Torres',
      ),
    ],
    conversations: [
      DemoConversation(
        personId: 'noah-bennett',
        messages: [
          DemoMessage(
            'riley-morgan',
            'Hi Noah! Where do I go for the stage crew open house?',
            '12:10 PM',
          ),
          DemoMessage(
            'noah-bennett',
            'The auditorium lobby. I’ll meet you by the ticket window.',
            '12:15 PM',
          ),
        ],
      ),
    ],
    guide: [
      DemoGuideItem(
        'cedarbrook-courtyard',
        'Unwritten rules',
        'Meeting in the courtyard',
        'The courtyard is the usual spot to meet peer guides. Wait near '
            'the painted mural if you need help finding a classroom.',
      ),
      DemoGuideItem(
        'cedarbrook-study-commons',
        'Unwritten rules',
        'Using the study commons',
        'The window seats are for quiet work. Use the long tables by the '
            'entrance for group projects.',
      ),
      DemoGuideItem(
        'cedarbrook-stage-attire',
        'Dress code',
        'Dressing for stage crew',
        'Wear closed-toe shoes backstage. Bring a dark shirt if you are '
            'working during a performance.',
      ),
    ],
    courses: [
      DemoCourse(
        id: 'writing-workshop',
        title: 'Writing Workshop',
        subject: 'English',
        credits: 1,
        description: 'Draft and revise essays, profiles, and short stories.',
      ),
      DemoCourse(
        id: 'integrated-math-i',
        title: 'Integrated Math I',
        subject: 'Mathematics',
        credits: 1,
        description: 'Connect algebra, geometry, and data analysis.',
      ),
      DemoCourse(
        id: 'integrated-math-ii',
        title: 'Integrated Math II',
        subject: 'Mathematics',
        credits: 1,
        prerequisites: ['Integrated Math I'],
        description: 'Study quadratic models, probability, and similarity.',
      ),
      DemoCourse(
        id: 'environmental-science',
        title: 'Environmental Science',
        subject: 'Science',
        credits: 1,
        description: 'Investigate watersheds, climate, and conservation.',
      ),
      DemoCourse(
        id: 'stagecraft',
        title: 'Stagecraft',
        subject: 'Arts',
        credits: 1,
        description: 'Learn the basics of stage lighting and set design.',
      ),
    ],
    graduationRequirements: [
      DemoCreditRequirement('English', 4),
      DemoCreditRequirement('Mathematics', 4),
      DemoCreditRequirement('Science', 3),
      DemoCreditRequirement('Social Studies', 3),
      DemoCreditRequirement('Arts', 2),
      DemoCreditRequirement('Physical Education', 2),
      DemoCreditRequirement('Electives', 4),
    ],
  ),
];
