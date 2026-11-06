import Combine
import SwiftUI

#if os(macOS)
  import FlutterMacOS
#else
  import Flutter
#endif

struct NativeTodo: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var notes: String?
  var due: String?
  var completed: Bool?
  var assignmentID: String?
}
struct NativeAssignment: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var details: String
  var date: String?
  var due: String?
  var allDay: Bool
  var points: String?
  var link: String?
  var note: String?
  var course: String { AssignmentTitle.parts(title).course }
  var displayTitle: String { AssignmentTitle.parts(title).assignment }
  var isTest: Bool {
    title.range(
      of: #"\b(?:tests?|quizzes|quiz)(?:\b|(?=\d))"#,
      options: [.regularExpression, .caseInsensitive]) != nil
  }
}
struct NativePlanner: Codable {
  var todos: [NativeTodo] = []
  var assignments: [NativeAssignment] = []
  var connected = false
  var syncing = false
  var error: String?
  var lastSync: String?
}
struct NativeState: Codable {
  var snapshot: Snapshot?
  var isDemo = false
  var restoring = true
  var error: String?
  var saved: [String] = []
  var serverURL = "https://api.buckley.community"
  var draft: PostDraft?
  var planner = NativePlanner()
}
struct NativeNotice: Identifiable {
  let id = UUID()
  var title: String
  var message: String
}
@MainActor final class NativeModel: ObservableObject {
  @Published var state = NativeState()
  @Published var notice: NativeNotice?
  let channel: FlutterMethodChannel
  var didBecomeReady: (() -> Void)?
  var ready = false
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "community.buckley.compass/native", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else { return }
        if call.method == "ready" {
          self.ready = true
          self.didBecomeReady?()
          result(nil)
        } else if call.method == "state", let value = call.arguments as? String {
          do {
            self.state = try JSONDecoder().decode(NativeState.self, from: Data(value.utf8))
            result(nil)
          } catch {
            result(
              FlutterError(
                code: "decode",
                message: "Could not read campus data: \(error.localizedDescription)", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
  var me: Profile? { state.snapshot?.me }
  var posts: [Post] { state.snapshot?.posts ?? [] }
  var chats: [Conversation] { state.snapshot?.conversations ?? [] }
  var admin: Bool { !state.isDemo && me?.role == "Administrator" }
  func call(_ method: String, _ args: [String: Any] = [:]) async throws -> Any? {
    try await withCheckedThrowingContinuation { continuation in
      channel.invokeMethod(method, arguments: args) { result in
        if let error = result as? FlutterError {
          continuation.resume(
            throwing: NSError(
              domain: "Compass", code: 1,
              userInfo: [NSLocalizedDescriptionKey: error.message ?? "Please try again."]))
        } else {
          continuation.resume(returning: result)
        }
      }
    }
  }
  func perform(_ method: String, _ args: [String: Any] = [:], success: String? = nil) {
    Task {
      do {
        _ = try await call(method, args)
        if let success { notice = NativeNotice(title: "Compass", message: success) }
      } catch { show(error) }
    }
  }
  func show(_ error: Error) {
    notice = NativeNotice(title: "Couldn’t complete that", message: error.localizedDescription)
  }
  func decode<T: Decodable>(_ value: Any?, as: T.Type) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: value ?? NSNull())
    return try JSONDecoder().decode(T.self, from: data)
  }
  func dictionary<T: Encodable>(_ value: T) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(value))) as? [String: Any] ?? [:]
  }
}
func nativeDate(_ raw: String?) -> Date? {
  guard let raw else { return nil }
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let value = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
    return value
  }
  for format in [
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss",
  ] {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.locale = Locale(identifier: "en_US_POSIX")
    if let date = formatter.date(from: raw) { return date }
  }
  return nil
}
extension NativeModel {
  func typedData(_ data: Data) -> FlutterStandardTypedData { FlutterStandardTypedData(bytes: data) }
  func data(_ value: Any?) -> Data? { (value as? FlutterStandardTypedData)?.data }
}
