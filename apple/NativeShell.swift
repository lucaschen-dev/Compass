import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private let campusRed = Color(red: 0.69, green: 0.10, blue: 0.13)
enum CampusSection: String, CaseIterable, Identifiable {
  case home = "Home"
  case todo = "To Do"
  case chat = "Chat"
  case assignments = "Assignments"
  case saved = "Saved"
  case mine = "My Posts"
  case admin = "Administrator"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .home: "house"
    case .todo: "checklist"
    case .chat: "bubble.left.and.bubble.right"
    case .assignments: "calendar"
    case .saved: "bookmark"
    case .mine: "square.and.pencil"
    case .admin: "checkmark.shield"
    }
  }
}
struct NativeRoot: View {
  @ObservedObject var model: NativeModel
  @Environment(\.scenePhase) var phase
  @State private var selection: CampusSection? = .home
  @State private var composer = false
  @State private var profile = false
  @State private var login = false
  var body: some View {
    Group {
      if model.state.restoring {
        ProgressView("Opening Compass…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.state.snapshot == nil {
        NativeWelcome(login: $login)
      } else if !model.state.isDemo
        && (model.state.snapshot?.needsPassword == true
          || model.state.snapshot?.needsProfile == true)
      {
        NativeOnboarding()
      } else {
        signedIn
      }
    }
    .environmentObject(model)
    .tint(campusRed)
    .sheet(isPresented: $login) { NativeLogin().environmentObject(model) }
    .sheet(isPresented: $composer) { NativeComposer().environmentObject(model) }
    .sheet(isPresented: $profile) { NativeProfile().environmentObject(model) }
    .alert(item: $model.notice) { notice in
      Alert(
        title: Text(notice.title), message: Text(notice.message),
        dismissButton: .default(Text("OK")))
    }
    .onChange(of: model.state.snapshot?.me.id) { _, id in
      if id == nil {
        selection = .home
        composer = false
        profile = false
      }
      if id != nil { login = false }
    }
    .onChange(of: phase) { _, value in model.perform("active", ["value": value == .active]) }
  }
  @ViewBuilder var signedIn: some View {
    #if os(macOS)
      NavigationSplitView {
        List(selection: $selection) {
          Section("Campus") {
            sidebar(.home)
            sidebar(.todo)
            sidebar(.chat)
            sidebar(.assignments)
          }
          Section("Library") {
            sidebar(.saved)
            sidebar(.mine)
            if model.admin { sidebar(.admin) }
          }
        }
        .listStyle(.sidebar)
        .navigationTitle("Compass")
        .navigationSplitViewColumnWidth(min: 185, ideal: 215, max: 260)
        .safeAreaInset(edge: .bottom) {
          Button {
            profile = true
          } label: {
            HStack(spacing: 10) {
              NativeAvatar(person: model.me, size: 30)
              VStack(alignment: .leading, spacing: 2) {
                Text(model.me?.name ?? "Profile").font(.callout.weight(.medium))
                Text(model.state.isDemo ? "Demo account" : "Your school account").font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }.padding(12)
          }.buttonStyle(.plain).accessibilityLabel("Your profile")
        }
      } detail: {
        NavigationStack {
          destination(selection ?? .home).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            composer = true
          } label: {
            Label("New post", systemImage: "square.and.pencil")
          }.keyboardShortcut("n", modifiers: .command).help("New post")
        }
      }
      .frame(minWidth: 850, minHeight: 580)
    #else
      TabView(selection: $selection) {
        mobileTab(.home)
        mobileTab(.todo)
        mobileTab(.chat)
        mobileTab(.assignments)
      }
    #endif
  }
  #if os(macOS)
    func sidebar(_ section: CampusSection) -> some View {
      Label(section.rawValue, systemImage: section.icon).tag(section)
    }
  #else
    func mobileTab(_ section: CampusSection) -> some View {
      NavigationStack {
        destination(section)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button {
                profile = true
              } label: {
                Image(systemName: "person.crop.circle")
              }.accessibilityLabel("Your profile")
            }
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                composer = true
              } label: {
                Image(systemName: "square.and.pencil")
              }.accessibilityLabel("New post")
            }
          }
      }.tabItem { Label(section.rawValue, systemImage: section.icon) }.tag(Optional(section))
    }
  #endif
  @ViewBuilder func destination(_ section: CampusSection) -> some View {
    switch section {
    case .home: NativeFeed(mode: .home)
    case .saved: NativeFeed(mode: .saved)
    case .mine: NativeOwnPosts()
    case .todo: NativeTodos()
    case .chat: NativeChats()
    case .assignments: NativeAssignments()
    case .admin: NativeAdmin()
    }
  }
}
struct NativeAvatar: View {
  var person: Profile?
  var size: CGFloat = 34
  var body: some View {
    ZStack {
      Circle().fill(.quaternary)
      if let person {
        Text(person.initials).font(.system(size: size * 0.33, weight: .medium))
      } else {
        Image(systemName: "person.fill.questionmark").font(.system(size: size * 0.38))
          .foregroundStyle(.secondary)
      }
    }.frame(width: size, height: size).accessibilityHidden(true)
  }
}
struct NativeWelcome: View {
  @EnvironmentObject var model: NativeModel
  @Binding var login: Bool
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 40)
      Image("BuckleyMark").resizable().renderingMode(.template).scaledToFit().foregroundStyle(
        campusRed
      ).frame(width: 64, height: 64).padding(.bottom, 26)
      Text("Compass").font(.system(size: 36, weight: .semibold, design: .rounded))
      Text("The Buckley School").font(.subheadline).foregroundStyle(.secondary).padding(.top, 7)
      Text("A little more connected.").font(.title3).padding(.top, 28)
      Text("Ask a question, find your people,\nand keep your school day together.").font(.body)
        .foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4).padding(
          .top, 10)
      VStack(spacing: 12) {
        if #available(iOS 26, macOS 26, *) {
          Button("Join your school") { login = true }.buttonStyle(.glassProminent).controlSize(
            .large)
        } else {
          Button("Join your school") { login = true }.buttonStyle(.borderedProminent).controlSize(
            .large)
        }
        Button("Explore the demo") { model.perform("demo") }.accessibilityIdentifier("demo-entry")
          .buttonStyle(.plain).foregroundStyle(
            campusRed
          ).padding(8)
      }.padding(.top, 34)
      if let error = model.state.error {
        Text(error).font(.callout).foregroundStyle(.red).padding(.top, 16)
      }
      Spacer(minLength: 40)
      Text("A student-led community. Demo content is fictional.").font(.caption).foregroundStyle(
        .tertiary
      ).padding(.bottom, 28)
    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 28)
      #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
      #else
        .background(Color(uiColor: .systemGroupedBackground))
      #endif
  }
}
struct NativeLogin: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  @State private var url = ""
  @State private var email = ""
  @State private var password = ""
  @State private var code = ""
  @State private var useCode = false
  @State private var sent = false
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("School email", text: $email)
          if useCode {
            TextField("Email code", text: $code)
            Button(sent ? "Send a new code" : "Send email code") { submit(request: true) }
          } else {
            SecureField("Password", text: $password)
          }
        }
        Section {
          Toggle("Use an email code", isOn: $useCode)
        } footer: {
          Text("Use an email code to join or reset your password.")
        }
        Section("Server") { TextField("Campus server", text: $url) }
        if sent { Text("Check your school inbox.").foregroundStyle(.secondary) }
        if let error { Text(error).foregroundStyle(.red) }
        Section {
          Button(busy ? "Connecting…" : "Continue") { submit(request: false) }.disabled(
            busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Your school account")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(busy)
        }
      }
      .disabled(busy)
      .onAppear { url = model.state.serverURL }
      #if os(iOS)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
      #endif
    }
    .nativeSheetFrame(width: 480, height: 570)
    .interactiveDismissDisabled(busy)
  }
  func submit(request: Bool) {
    busy = true
    error = nil
    Task {
      do {
        _ = try await model.call(
          request ? "requestCode" : "login",
          [
            "url": url, "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "credential": useCode ? code : password, "code": useCode,
          ])
        if request { sent = true } else { dismiss() }
      } catch { self.error = error.localizedDescription }
      busy = false
    }
  }
}
struct NativeOnboarding: View {
  @EnvironmentObject var model: NativeModel
  @State private var password = ""
  @State private var repeated = ""
  @State private var name = ""
  @State private var year = "Grade 11"
  @State private var busy = false
  @State private var error: String?
  var needsPassword: Bool { model.state.snapshot?.needsPassword == true }
  var body: some View {
    NavigationStack {
      Form {
        if needsPassword {
          Section("Choose a password") {
            SecureField("New password", text: $password)
            SecureField("Confirm password", text: $repeated)
          }
        } else {
          Section("Your profile") {
            TextField("Full name", text: $name)
            Picker("Year", selection: $year) {
              ForEach(
                ["Grade 9", "Grade 10", "Grade 11", "Grade 12", "Faculty", "Staff"], id: \.self
              ) { Text($0) }
            }
          }
        }
        if let error { Text(error).foregroundStyle(.red) }
        Button("Continue") {
          busy = true
          Task {
            do {
              if needsPassword {
                guard password == repeated else {
                  throw NSError(
                    domain: "Compass", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Passwords do not match."])
                }
                _ = try await model.call("password", ["password": password])
              } else if var person = model.me {
                person.name = name
                person.year = year
                _ = try await model.call("profile", ["profile": model.dictionary(person)])
              }
            } catch { self.error = error.localizedDescription }
            busy = false
          }
        }
      }.formStyle(.grouped).disabled(busy).navigationTitle(
        needsPassword ? "Set your password" : "About you"
      )
      .toolbar { Button("Sign out") { model.perform("signOut") } }
      .onAppear { name = model.me?.name ?? "" }
    }
  }
}
extension View {
  @ViewBuilder func nativeSheetFrame(width: CGFloat, height: CGFloat) -> some View {
    #if os(macOS)
      self.frame(width: width, height: height)
    #else
      self
    #endif
  }
}
