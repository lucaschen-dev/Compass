import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NativeChats: View {
  @EnvironmentObject var model: NativeModel
  @State private var creating = false
  @State private var selected: String?
  var body: some View {
    #if os(macOS)
      HSplitView {
        conversationList.frame(minWidth: 220, idealWidth: 270, maxWidth: 320)
        Group {
          if let selected {
            NativeConversation(id: selected)
          } else {
            ContentUnavailableView(
              "Your conversations", systemImage: "bubble.left.and.bubble.right",
              description: Text("Choose a conversation or start a new one."))
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }.navigationTitle("Chat")
        .toolbar { Button("New conversation", systemImage: "plus.bubble") { creating = true } }
        .sheet(isPresented: $creating) {
          NativeNewChat { chat in
            selected = chat.id
            creating = false
          }
        }
    #else
      conversationList.navigationTitle("Chat").toolbar {
        Button("New conversation", systemImage: "plus.bubble") { creating = true }
      }.sheet(isPresented: $creating) {
        NativeNewChat { chat in
          selected = chat.id
          creating = false
        }
      }.navigationDestination(item: $selected) { id in NativeConversation(id: id) }
    #endif
  }
  var conversationList: some View {
    List {
      if model.chats.isEmpty {
        ContentUnavailableView(
          "No conversations yet", systemImage: "bubble",
          description: Text("Say hello to someone at school."))
      }
      ForEach(model.chats) { chat in
        #if os(macOS)
          Button {
            selected = chat.id
          } label: {
            chatRow(chat).padding(.vertical, 6).contentShape(Rectangle())
          }.buttonStyle(.plain).listRowBackground(
            selected == chat.id ? Color.accentColor.opacity(0.10) : Color.clear)
        #else
          NavigationLink {
            NativeConversation(id: chat.id)
          } label: {
            chatRow(chat).padding(.vertical, 4)
          }
        #endif
      }
    }.listStyle(.plain)
  }
  func chatRow(_ chat: Conversation) -> some View {
    HStack(spacing: 11) {
      NativeAvatar(person: chat.peer, size: 38)
      VStack(alignment: .leading, spacing: 5) {
        Text(chat.displayName).font(.body.weight(.medium)).foregroundStyle(.primary)
        Text(chat.messages.last?.preview ?? "No messages yet").font(.subheadline).foregroundStyle(
          .secondary
        ).lineLimit(2)
      }
      Spacer(minLength: 0)
    }
  }
}
struct NativeConversation: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let id: String
  @State private var text = ""
  @State private var busy = false
  @State private var replying: Message?
  @State private var info = false
  @State private var retracting: String?
  @State private var photos: PhotosPickerItem?
  @State private var mediaID: String?
  @State private var mediaKind: String?
  @State private var showingVideoImporter = false
  @State private var attachment: NativeAttachmentID?
  var chat: Conversation? { model.chats.first(where: { $0.id == id }) }
  var body: some View {
    Group {
      if let chat {
        VStack(spacing: 0) {
          ScrollViewReader { reader in
            ScrollView {
              LazyVStack(spacing: 16) {
                if model.state.isDemo {
                  Text("Demo messages stay on this device.").font(.caption).foregroundStyle(
                    .secondary
                  ).padding(.vertical, 12)
                }
                ForEach(chat.messages) { message in messageRow(message, in: chat).id(message.id) }
              }.padding(20).frame(maxWidth: 850).frame(maxWidth: .infinity)
            }
            .onChange(of: chat.messages.count) { _, _ in
              if let last = chat.messages.last {
                withAnimation { reader.scrollTo(last.id, anchor: .bottom) }
              }
            }
            .onAppear {
              if let last = chat.messages.last { reader.scrollTo(last.id, anchor: .bottom) }
            }
          }
          VStack(spacing: 8) {
            if let replying {
              HStack {
                Text("Replying to \(replying.preview)").font(.caption).foregroundStyle(.secondary)
                  .lineLimit(1)
                Spacer()
                Button("Cancel reply", systemImage: "xmark") { self.replying = nil }.labelStyle(
                  .iconOnly
                ).buttonStyle(.plain)
              }
            }
            if mediaID != nil {
              HStack {
                Label(
                  mediaKind == "video" ? "Video ready" : "Photo ready",
                  systemImage: mediaKind == "video" ? "video" : "photo"
                ).font(.caption)
                Spacer()
                Button("Remove attachment", systemImage: "xmark") { mediaID = nil }.labelStyle(
                  .iconOnly
                ).buttonStyle(.plain)
              }
            }
            HStack(alignment: .bottom, spacing: 12) {
              Menu {
                PhotosPicker(selection: $photos, matching: .images) {
                  Label("Photo", systemImage: "photo")
                }
                Button("Short video", systemImage: "video") { showingVideoImporter = true }
              } label: {
                Image(systemName: "plus.circle").font(.title3)
              }.menuStyle(.borderlessButton).fixedSize().disabled(busy)
              TextField("Message", text: $text, axis: .vertical).lineLimit(1...5).textFieldStyle(
                .plain
              ).accessibilityIdentifier("message-input")
              Button {
                send()
              } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
              }.buttonStyle(.plain).foregroundStyle(.tint).disabled(
                busy
                  || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && mediaID == nil)
                  || text.count > 2000
              ).accessibilityLabel("Send message")
            }
            if busy { ProgressView().controlSize(.small) }
          }.padding(16).background(.bar)
        }
        .navigationTitle(chat.displayName).nativeInlineTitle()
        .toolbar { Button("Conversation info", systemImage: "info.circle") { info = true } }
        .sheet(isPresented: $info) {
          NativeConversationInfo(chat: chat) {
            info = false
            dismiss()
          }
        }
      } else {
        ContentUnavailableView("Conversation unavailable", systemImage: "bubble")
      }
    }
    .confirmationDialog(
      "Unsend this message?",
      isPresented: Binding(get: { retracting != nil }, set: { if !$0 { retracting = nil } }),
      titleVisibility: .visible
    ) {
      Button("Unsend", role: .destructive) {
        if let messageID = retracting { model.perform("retract", ["chatID": id, "id": messageID]) }
        retracting = nil
      }
    }
    .onChange(of: photos) { _, value in
      if let value {
        Task {
          do {
            guard let data = try await value.loadTransferable(type: Data.self) else { return }
            await upload(data, kind: "photo")
          } catch { model.show(error) }
          photos = nil
        }
      }
    }
    .fileImporter(
      isPresented: $showingVideoImporter, allowedContentTypes: [.mpeg4Movie, .quickTimeMovie],
      allowsMultipleSelection: false
    ) { result in
      do {
        guard let url = try result.get().first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        Task { await upload(data, kind: "video") }
      } catch { model.show(error) }
    }
    .sheet(item: $attachment) { NativeAttachment(id: $0.id) }
  }
  func messageRow(_ message: Message, in chat: Conversation) -> some View {
    let mine = message.senderID == model.me?.id
    return HStack(alignment: .bottom, spacing: 8) {
      if mine { Spacer(minLength: 50) }
      VStack(alignment: mine ? .trailing : .leading, spacing: 5) {
        if chat.isGroup && !mine {
          Text(chat.participants.first(where: { $0.id == message.senderID })?.name ?? "Member")
            .font(.caption).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 8) {
          if let replyID = message.replyID,
            let target = chat.messages.first(where: { $0.id == replyID })
          {
            Text(target.preview).font(.caption).foregroundStyle(.secondary).lineLimit(2).padding(
              .leading, 8
            ).overlay(alignment: .leading) {
              RoundedRectangle(cornerRadius: 1).fill(.secondary).frame(width: 2)
            }
          }
          if message.retracted == true {
            Text("Message unsent").italic().foregroundStyle(.secondary)
          } else {
            if !message.body.isEmpty { Text(message.body).textSelection(.enabled) }
            if let media = message.mediaID {
              Button {
                attachment = NativeAttachmentID(id: media)
              } label: {
                Label(
                  message.mediaKind == "video" ? "Play video" : "View photo",
                  systemImage: message.mediaKind == "video" ? "play.circle" : "photo")
              }.buttonStyle(.plain)
            }
          }
        }.padding(.horizontal, 14).padding(.vertical, 10).background(
          mine ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.09),
          in: RoundedRectangle(cornerRadius: 17))
        Text(Date(timeIntervalSince1970: message.createdAt), style: .time).font(.caption2)
          .foregroundStyle(.tertiary)
      }.contextMenu {
        if message.retracted != true {
          Button("Reply", systemImage: "arrowshape.turn.up.left") { replying = message }
          if mine {
            Button("Unsend", systemImage: "trash", role: .destructive) { retracting = message.id }
          }
        }
      }
      if !mine { Spacer(minLength: 50) }
    }
  }
  func send() {
    busy = true
    Task {
      do {
        var args: [String: Any] = ["id": id, "body": text]
        if let replying { args["replyID"] = replying.id }
        if let mediaID { args["mediaID"] = mediaID }
        _ = try await model.call("send", args)
        text = ""
        replying = nil
        mediaID = nil
      } catch { model.show(error) }
      busy = false
    }
  }
  func upload(_ data: Data, kind: String) async {
    guard !model.state.isDemo else {
      model.notice = NativeNotice(
        title: "School account needed", message: "Media messages need a school account.")
      return
    }
    guard data.count <= 15 * 1024 * 1024 else {
      model.notice = NativeNotice(
        title: "Choose a smaller file", message: "Short videos must be smaller than 15 MB.")
      return
    }
    busy = true
    do {
      mediaID =
        try await model.call(
          "uploadMedia", ["id": id, "kind": kind, "bytes": model.typedData(data)]) as? String
      mediaKind = kind
    } catch { model.show(error) }
    busy = false
  }
}
struct NativeMemberPicker: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let select: (Profile) -> Void
  @State private var people: [Profile] = []
  @State private var query = ""
  @State private var loading = true
  var body: some View {
    NavigationStack {
      List {
        if loading { ProgressView() }
        ForEach(people.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) })
        { person in
          Button {
            select(person)
          } label: {
            HStack {
              NativeAvatar(person: person)
              VStack(alignment: .leading) {
                Text(person.name).foregroundStyle(.primary)
                Text(person.year + " · " + person.role).font(.caption).foregroundStyle(.secondary)
              }
            }
          }.buttonStyle(.plain)
        }
      }.navigationTitle("School members").searchable(text: $query).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }.task {
        do { people = try model.decode(try await model.call("members"), as: [Profile].self) } catch
        { model.show(error) }
        loading = false
      }
    }.nativeSheetFrame(width: 460, height: 550)
  }
}
struct NativeNewChat: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  var created: (Conversation) -> Void
  @State private var people: [Profile] = []
  @State private var members: Set<String> = []
  @State private var group = false
  @State private var title = ""
  @State private var query = ""
  @State private var busy = false
  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Group conversation", isOn: $group)
          if group { TextField("Group name", text: $title) }
        }
        Section("Members") {
          ForEach(
            people.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
          ) { person in
            Button {
              if group {
                if members.contains(person.id) {
                  members.remove(person.id)
                } else {
                  members.insert(person.id)
                }
              } else {
                start(person)
              }
            } label: {
              HStack {
                NativeAvatar(person: person)
                VStack(alignment: .leading) {
                  Text(person.name).foregroundStyle(.primary)
                  Text(person.year).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if group {
                  Image(
                    systemName: members.contains(person.id) ? "checkmark.circle.fill" : "circle"
                  ).foregroundStyle(members.contains(person.id) ? Color.accentColor : .secondary)
                }
              }
            }.buttonStyle(.plain)
          }
        }
      }.nativeListStyle().searchable(text: $query).navigationTitle("New conversation")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            if group {
              Button("Create") { start(nil) }.disabled(members.count < 2 || title.isEmpty || busy)
            }
          }
        }
        .disabled(busy)
        .task {
          do {
            people = try model.decode(try await model.call("members"), as: [Profile].self)
          } catch { model.show(error) }
        }
    }.nativeSheetFrame(width: 480, height: 600)
  }
  func start(_ person: Profile?) {
    busy = true
    Task {
      do {
        let value: Any?
        if let person {
          value = try await model.call("startChat", ["person": model.dictionary(person)])
        } else {
          value = try await model.call(
            "createGroup",
            [
              "title": title,
              "members": people.filter { members.contains($0.id) }.map { model.dictionary($0) },
            ])
        }
        created(try model.decode(value, as: Conversation.self))
      } catch { model.show(error) }
      busy = false
    }
  }
}
struct NativeConversationInfo: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let chat: Conversation
  var left: () -> Void
  @State private var leave = false
  var body: some View {
    NavigationStack {
      List {
        Section("Members") {
          ForEach(chat.participants.isEmpty ? [chat.peer] : chat.participants) { person in
            NavigationLink {
              NativeMember(person: person)
            } label: {
              HStack {
                NativeAvatar(person: person)
                Text(person.name)
              }
            }
          }
        }
        if chat.isGroup { Section { Button("Leave group", role: .destructive) { leave = true } } }
      }.nativeListStyle().navigationTitle(chat.displayName).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
      }.confirmationDialog("Leave this group?", isPresented: $leave) {
        Button("Leave group", role: .destructive) {
          Task {
            do {
              _ = try await model.call("leave", ["id": chat.id])
              left()
            } catch { model.show(error) }
          }
        }
      }
    }.nativeSheetFrame(width: 460, height: 520)
  }
}
struct NativeAttachmentID: Identifiable { let id: String }
struct NativeAttachment: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let id: String
  @State private var data: Data?
  @State private var player: AVPlayer?
  @State private var file: URL?
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Group {
        if let player {
          VideoPlayer(player: player)
        } else if let data, let image = platformImage(data) {
          image.resizable().scaledToFit().padding()
        } else if let error {
          ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
        } else {
          ProgressView()
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).navigationTitle("Attachment").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
      }
    }.nativeSheetFrame(width: 780, height: 580).task {
      do {
        guard let result = try await model.call("media", ["id": id]) as? [String: Any],
          let encoded = result["data"] as? String, let bytes = Data(base64Encoded: encoded)
        else { return }
        if result["kind"] as? String == "video" {
          let path = FileManager.default.temporaryDirectory.appendingPathComponent(
            "compass-\(UUID().uuidString).mp4")
          try bytes.write(to: path, options: .atomic)
          try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
          file = path
          player = AVPlayer(url: path)
        } else {
          data = bytes
        }
      } catch { self.error = "Media unavailable" }
    }.onDisappear {
      player?.pause()
      player = nil
      if let file { try? FileManager.default.removeItem(at: file) }
    }
  }
}
