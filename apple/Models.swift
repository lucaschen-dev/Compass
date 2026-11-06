import Foundation

struct Profile: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var name: String
  var year: String
  var bio: String
  var instagram: String
  var role: String
  var initials: String {
    name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
  }
}
struct CampusGroup: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var name: String
  var isMember: Bool
}
enum PostKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case question = "Question"
  case advice = "Advice"
  case event = "Club Meeting"
  case lost = "Lost & Found"
  case gallery = "Photo Gallery"
  case activity = "Events"
  case study = "Study"
  case resources = "Resources"
  case marketplace = "Buy & Sell"
  case volunteer = "Volunteering"
  case general = "General"
  static var composerCases: [PostKind] {
    [.question, .event, .activity, .lost, .gallery, .general]
  }
  var composerKind: PostKind {
    switch self {
    case .advice: return .question
    case .study, .resources, .marketplace, .volunteer: return .general
    default: return self
    }
  }
  var label: String {
    switch composerKind {
    case .question: return "Q&A"
    case .event: return "Clubs"
    case .activity: return "School Events"
    case .lost: return "Lost & Found"
    case .gallery: return "Photo Gallery"
    default: return "Other"
    }
  }
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .gallery: "photo.on.rectangle.angled"
    case .question: "bubble.left.and.bubble.right"
    case .advice: "sparkles"
    case .event: "calendar"
    case .lost: "magnifyingglass"
    case .activity: "calendar.badge.clock"
    case .study: "book"
    case .resources: "folder"
    case .marketplace: "tag"
    case .volunteer: "hands.sparkles"
    case .general: "bubble.left"
    }
  }
}
struct Reply: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var author: Profile
  var body: String
  var status: String? = nil
}
struct Post: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var title: String
  var body: String
  var kind: PostKind
  var author: Profile?
  var anonymous: Bool
  var groupID: String
  var groupName: String
  var visibility: String
  var important: Bool
  var createdAt: Double
  var replies: [Reply]
  var priority: String? = nil
  var askedPerson: Profile? = nil
  var requestedAnswerUntil: Double? = nil
  var photoIDs: [String]? = nil
  var isMine: Bool? = nil
  var status: String? = nil
  var authorName: String { anonymous ? "Anonymous student" : (author?.name ?? "Deleted account") }
  var date: Date { Date(timeIntervalSince1970: createdAt) }
}
struct Message: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var senderID: String
  var body: String
  var createdAt: Double
  var replyID: String? = nil
  var retracted: Bool? = nil
  var mediaID: String? = nil
  var mediaKind: String? = nil
  var preview: String {
    retracted == true
      ? "Message unsent" : (!body.isEmpty ? body : (mediaKind == "video" ? "Video" : "Photo"))
  }
}
struct MediaPayload: Codable {
  var kind: String
  var data: String
}
struct MessageResult: Codable {
  var ok: Bool
  var message: Message?
}
struct Conversation: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var peer: Profile
  var messages: [Message]
  var kind: String
  var title: String
  var participants: [Profile]
  var isGroup: Bool { kind == "group" }
  var displayName: String { isGroup ? title : peer.name }
  init(
    id: String, peer: Profile, messages: [Message], kind: String = "direct", title: String = "",
    participants: [Profile] = []
  ) {
    self.id = id
    self.peer = peer
    self.messages = messages
    self.kind = kind
    self.title = title
    self.participants = participants
  }
  enum CodingKeys: String, CodingKey { case id, peer, messages, kind, title, participants }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    peer = try c.decode(Profile.self, forKey: .peer)
    messages = try c.decode([Message].self, forKey: .messages)
    kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "direct"
    title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    participants = try c.decodeIfPresent([Profile].self, forKey: .participants) ?? []
  }
}
struct Snapshot: Codable, Equatable, Sendable {
  var me: Profile
  var groups: [CampusGroup]
  var posts: [Post]
  var conversations: [Conversation]
  var needsPassword: Bool? = nil
  var needsProfile: Bool? = nil
  var openReports: Int? = nil
}
struct PostDraft: Codable, Equatable {
  var title = ""
  var body = ""
  var kind: PostKind = .question
  var anonymous = false
  var groupID = "all"
  var visibility = "school"
  var priority: String? = "normal"
  var askedUserID: String? = nil
  var photoIDs: [String]? = nil
}
struct PhotoResult: Codable, Sendable { var id: String }
struct PhotoPayload: Codable, Sendable { var jpeg: String }
struct PostResult: Codable {
  var status: String
  var priority: String?
}
struct AuthResult: Codable { var token: String }
struct EmptyResult: Codable { var ok: Bool }
struct APIErrorBody: Codable { var error: String }

// MARK: - Private planner data (stored on this device, scoped to the account)
struct TodoItem: Codable, Identifiable, Equatable, Sendable {
  var id = UUID().uuidString
  var title: String
  var notes = ""
  var due: Date?
  var completed = false
  var assignmentID: String?
}
struct SchoolAssignment: Codable, Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var details: String
  var date: Date
  var allDay: Bool
  var link: URL?
  var dueDate: Date? = nil
  var dueAllDay: Bool? = nil
  var points: String? = nil
  var importNote: String? = nil
  var courseName: String { AssignmentTitle.parts(title).course }
  var displayTitle: String { AssignmentTitle.parts(title).assignment }
  var calendarDate: Date? { date == .distantFuture ? nil : date }
  private static let assessmentPattern = try! NSRegularExpression(
    pattern: #"(?i)\b(?:tests?|quizzes|quiz)(?:\b|(?=\d))"#)
  var isAssessment: Bool {
    Self.assessmentPattern.firstMatch(in: title, range: NSRange(title.startIndex..., in: title))
      != nil
  }
}
struct AssignmentCache: Codable, Sendable {
  var items: [SchoolAssignment] = []
  var syncedAt: Date?
  var warning: String?
}
struct CalendarImport: Sendable {
  var items: [SchoolAssignment]
  var skipped: Int
}

// Presentation only: preserve original imported titles and stable calendar UIDs.
enum AssignmentTitle {
  private static let whitespace = try! NSRegularExpression(pattern: #"\s+"#)
  private static let beforePunctuation = try! NSRegularExpression(pattern: #"\s+([,;:!?])"#)
  private static let afterPunctuation = try! NSRegularExpression(pattern: #"([,;:!?])(?=[A-Za-z])"#)
  private static let separator = try! NSRegularExpression(pattern: #"\s+[-–—]\s*|\s*[-–—]\s+"#)
  static func clean(_ text: String) -> String {
    var value = text.replacingOccurrences(of: "\u{00a0}", with: " ")
    for (pattern, replacement) in [
      (whitespace, " "), (beforePunctuation, "$1"), (afterPunctuation, "$1 "),
    ] {
      value = pattern.stringByReplacingMatches(
        in: value, range: NSRange(value.startIndex..., in: value), withTemplate: replacement)
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  static func parts(_ raw: String) -> (course: String, assignment: String) {
    let title = clean(raw)
    // Prefer a separated dash so a course like Pre-Calculus remains intact.
    let match = separator.firstMatch(in: title, range: NSRange(title.startIndex..., in: title))
    let range = match.flatMap { Range($0.range, in: title) } ?? title.range(of: "-")
    guard let range else { return ("Other", title) }
    let course = clean(String(title[..<range.lowerBound]))
    let assignment = clean(String(title[range.upperBound...]))
    guard !course.isEmpty, !assignment.isEmpty else { return ("Other", title) }
    return (course, assignment)
  }
}
struct AssignmentSection: Identifiable {
  let name: String
  let items: [SchoolAssignment]
  var id: String { name }
}

enum GalleryLimits { static let maxPhotos = 20 }

struct AdminPost: Codable, Identifiable {
  var post: Post
  var author: Profile
  var authorEmail: String
  var id: String { post.id }
}
struct AdminReport: Codable, Identifiable {
  var id: String
  var postID: String
  var postTitle: String
  var postExists: Bool
  var reporter: Profile
  var reason: String
  var createdAt: Double
  var resolved: Bool
  var decision: String
  var note: String
  var resolvedAt: Double?
  var resolvedBy: Profile?
}
struct AdminPage<Item: Decodable>: Decodable {
  var items: [Item]
  var nextOffset: Int?
  var openReports: Int
}
