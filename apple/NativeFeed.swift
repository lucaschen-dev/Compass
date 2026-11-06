import PhotosUI
import SwiftUI

struct NativeFeed: View {
  @EnvironmentObject var model: NativeModel
  var mode: CampusSection
  @State private var query = ""
  @State private var category = "All"
  var visible: [Post] {
    model.posts.filter { post in
      (mode != .saved || model.state.saved.contains(post.id))
        && (category == "All" || category == post.kind.label)
        && (query.isEmpty || (post.title + " " + post.body).localizedCaseInsensitiveContains(query))
    }
  }
  var pinned: [Post] {
    visible.filter { $0.important || ($0.requestedAnswerUntil ?? 0) > Date().timeIntervalSince1970 }
  }
  var latest: [Post] { visible.filter { post in !pinned.contains(where: { $0.id == post.id }) } }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        HStack {
          Image("BuckleyWordmark").resizable().renderingMode(.template).scaledToFit().frame(
            width: 150, height: 30)
          Spacer()
          if model.state.isDemo {
            Text("DEMO").font(.caption2.weight(.medium)).foregroundStyle(.secondary).tracking(1)
              .padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule())
          }
        }.padding(.bottom, 28)
        if !pinned.isEmpty {
          Label("Important", systemImage: "pin").font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary).padding(.bottom, 12)
          ForEach(pinned) { post in NativePostRow(post: post, pinned: true).padding(.bottom, 12) }
          Color.clear.frame(height: 22)
        }
        HStack {
          Text(mode == .saved ? "Saved posts" : category == "All" ? "Latest posts" : category).font(
            .headline)
          Spacer()
          Text("\(visible.count)").font(.subheadline).foregroundStyle(.tertiary)
        }.padding(.bottom, 12)
        if latest.isEmpty && pinned.isEmpty { ContentUnavailableView.search(text: query) }
        ForEach(latest) { post in NativePostRow(post: post).padding(.bottom, 12) }
      }.padding(24).frame(maxWidth: 780).frame(maxWidth: .infinity)
    }
    .nativeContentBackground()
    .navigationTitle(mode.rawValue)
    .searchable(text: $query, prompt: "Search campus posts")
    .refreshable { _ = try? await model.call("refresh") }
    .toolbar {
      ToolbarItem(placement: .secondaryAction) {
        Menu {
          Picker("Category", selection: $category) {
            Text("All").tag("All")
            ForEach(PostKind.composerCases) { Text($0.label).tag($0.label) }
          }
        } label: {
          Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
      }
    }
  }
}
struct NativePostRow: View {
  @EnvironmentObject var model: NativeModel
  let post: Post
  var pinned = false
  var body: some View {
    NavigationLink {
      NativePostDetail(id: post.id, initial: post)
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 6) {
          if pinned { Image(systemName: "pin.fill").foregroundStyle(campusTint).font(.caption) }
          Text(post.kind.label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
          Spacer()
          if model.state.saved.contains(post.id) {
            Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(.secondary)
          }
        }
        Text(post.title).font(.title3.weight(.medium)).foregroundStyle(.primary).fixedSize(
          horizontal: false, vertical: true)
        Text(post.body).font(.callout).foregroundStyle(.secondary).lineLimit(3).lineSpacing(3)
        if let photo = post.photoIDs?.first {
          NativePhoto(id: photo).frame(height: 175).clipped().clipShape(
            RoundedRectangle(cornerRadius: 10))
        }
        HStack(spacing: 8) {
          NativeAvatar(person: post.author, size: 23)
          Text(post.authorName).font(.caption).foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "bubble.right")
          Text("\(post.replies.count)")
        }.font(.caption).foregroundStyle(.tertiary)
      }
      .padding(18)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.055), lineWidth: 0.5))
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .contextMenu {
        Button(
          model.state.saved.contains(post.id) ? "Unsave post" : "Save post", systemImage: "bookmark"
        ) { model.perform("save", ["id": post.id]) }
      }
  }
  var campusTint: Color { Color(red: 0.69, green: 0.10, blue: 0.13) }
}
struct NativePostDetail: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let id: String
  var initial: Post?
  @State private var reply = ""
  @State private var busy = false
  @State private var reporting = false
  @State private var reason = ""
  @State private var deleting = false
  var post: Post? { model.posts.first(where: { $0.id == id }) ?? initial }
  var body: some View {
    Group {
      if let post {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text(post.kind.label).font(.subheadline).foregroundStyle(.secondary)
            Text(post.title).font(.largeTitle.weight(.semibold)).fixedSize(
              horizontal: false, vertical: true)
            HStack(spacing: 10) {
              NativeAvatar(person: post.author)
              if let author = post.author {
                NavigationLink {
                  NativeMember(person: author)
                } label: {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(author.name).font(.subheadline.weight(.medium))
                    Text(post.date, style: .date).font(.caption).foregroundStyle(.secondary)
                  }
                }.buttonStyle(.plain)
              } else {
                Text("Anonymous student").font(.subheadline).foregroundStyle(.secondary)
              }
              Spacer()
            }
            Label(
              post.visibility == "group" ? "Group members only" : "Visible to school",
              systemImage: post.visibility == "group" ? "lock" : "person.2"
            ).font(.caption).foregroundStyle(.secondary)
            if let asked = post.askedPerson {
              Text("Asked @\(asked.name)").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(post.body).font(.body).lineSpacing(5).textSelection(.enabled)
            ForEach(post.photoIDs ?? [], id: \.self) {
              NativePhoto(id: $0).frame(maxHeight: 420).clipShape(
                RoundedRectangle(cornerRadius: 12))
            }
            Divider().padding(.vertical, 8)
            Text("Replies").font(.headline)
            if post.replies.isEmpty { Text("Start the conversation.").foregroundStyle(.secondary) }
            ForEach(post.replies) { item in
              HStack(alignment: .top, spacing: 12) {
                NativeAvatar(person: item.author, size: 28)
                VStack(alignment: .leading, spacing: 6) {
                  NavigationLink(item.author.name) { NativeMember(person: item.author) }.font(
                    .subheadline.weight(.medium)
                  ).buttonStyle(.plain)
                  Text(item.body).font(.body).textSelection(.enabled)
                }
                Spacer()
              }
              .padding(.vertical, 8)
              .contextMenu {
                if item.author.id == model.me?.id {
                  Button("Delete reply", role: .destructive) {
                    model.perform("deleteReply", ["id": item.id])
                  }
                }
              }
            }
          }.padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
          HStack(alignment: .bottom, spacing: 12) {
            TextField("Write a reply", text: $reply, axis: .vertical).lineLimit(1...5)
              .textFieldStyle(.plain)
            Button {
              send()
            } label: {
              Image(systemName: "arrow.up.circle.fill").font(.title2)
            }.buttonStyle(.plain).foregroundStyle(.tint).disabled(
              busy || reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || reply.count > 2000
            ).accessibilityLabel("Send reply")
          }.padding(16).background(.bar)
        }
        .toolbar {
          Button {
            model.perform("save", ["id": id])
          } label: {
            Image(systemName: model.state.saved.contains(id) ? "bookmark.fill" : "bookmark")
          }.help("Save post")
          Menu {
            Button("Report post", systemImage: "flag") { reporting = true }
            if post.isMine == true || post.author?.id == model.me?.id {
              Button(
                post.anonymous ? "Show my name" : "Make anonymous",
                systemImage: "person.fill.questionmark"
              ) { model.perform("managePost", ["id": id, "anonymous": !post.anonymous]) }
              Button("Delete post", systemImage: "trash", role: .destructive) { deleting = true }
            }
          } label: {
            Image(systemName: "ellipsis")
          }
        }
      } else {
        ContentUnavailableView(
          "Post unavailable", systemImage: "doc",
          description: Text("It may have been removed or expired."))
      }
    }
    .navigationTitle("Post")
    .nativeInlineTitle()
    .alert("Report post", isPresented: $reporting) {
      TextField("Reason", text: $reason)
      Button("Cancel", role: .cancel) {}
      Button("Submit") {
        model.perform(
          "report", ["id": id, "reason": reason],
          success: model.state.isDemo
            ? "Saved locally in demo. No moderator received this report."
            : "Report sent for review.")
      }
    } message: {
      Text("Tell the moderators what needs attention.")
    }
    .confirmationDialog(
      "Delete this post and its replies?", isPresented: $deleting, titleVisibility: .visible
    ) {
      Button("Delete post", role: .destructive) {
        Task {
          do {
            _ = try await model.call("managePost", ["id": id])
            dismiss()
          } catch { model.show(error) }
        }
      }
    }
  }
  func send() {
    busy = true
    Task {
      do {
        let message = try await model.call("reply", ["id": id, "body": reply])
        reply = ""
        if let message = message as? String, message.contains("review") {
          model.notice = NativeNotice(title: "Reply", message: message)
        }
      } catch { model.show(error) }
      busy = false
    }
  }
}
struct NativePhoto: View {
  @EnvironmentObject var model: NativeModel
  let id: String
  @State private var data: Data?
  @State private var failed = false
  @State private var enlarged = false
  var body: some View {
    Group {
      if let data, let image = platformImage(data) {
        image.resizable().scaledToFit().onTapGesture { enlarged = true }.sheet(
          isPresented: $enlarged
        ) {
          NavigationStack {
            image.resizable().scaledToFit().padding().toolbar {
              ToolbarItem(placement: .cancellationAction) { Button("Done") { enlarged = false } }
            }
          }.nativeSheetFrame(width: 800, height: 600)
        }
      } else if failed {
        Label("Photo unavailable", systemImage: "photo").foregroundStyle(.secondary).frame(
          maxWidth: .infinity, minHeight: 80)
      } else {
        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
      }
    }.task(id: id) {
      do {
        let value = try await model.call("photo", ["id": id])
        data = model.data(value)
      } catch { failed = true }
    }
  }
}
func platformImage(_ data: Data) -> Image? {
  #if os(macOS)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
  #else
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
  #endif
}
struct NativeComposer: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  @State private var draft = PostDraft()
  @State private var busy = false
  @State private var error: String?
  @State private var pickingPerson = false
  @State private var askedName = ""
  @State private var photos: [PhotosPickerItem] = []
  @State private var published = false
  var valid: Bool {
    !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.title.count <= 140
      && draft.body.count <= 5000
      && (draft.kind == .gallery
        ? !(draft.photoIDs ?? []).isEmpty
        : !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Post type", selection: $draft.kind) {
            ForEach(PostKind.composerCases) { Label($0.label, systemImage: $0.icon).tag($0) }
          }
          TextField("Title", text: $draft.title, axis: .vertical).lineLimit(1...3)
            .accessibilityIdentifier("post-title")
          TextField(
            draft.kind == .gallery ? "Caption" : "Details", text: $draft.body, axis: .vertical
          ).lineLimit(5...12).accessibilityIdentifier("post-body")
        } footer: {
          Text("\(draft.title.count)/140 title · \(draft.body.count)/5000 details")
        }
        if draft.kind == .gallery {
          Section("Photos") {
            PhotosPicker(
              selection: $photos, maxSelectionCount: 20 - (draft.photoIDs?.count ?? 0),
              matching: .images
            ) { Label("Add photos", systemImage: "photo.badge.plus") }.disabled(
              (draft.photoIDs?.count ?? 0) >= 20)
            ForEach(draft.photoIDs ?? [], id: \.self) { id in
              HStack {
                NativePhoto(id: id).frame(height: 90)
                Button("Remove", systemImage: "xmark.circle") {
                  draft.photoIDs?.removeAll(where: { $0 == id })
                }.labelStyle(.iconOnly)
              }
            }
          }
        }
        if draft.kind == .question {
          Section {
            Button {
              pickingPerson = true
            } label: {
              LabeledContent("Ask a person", value: askedName.isEmpty ? "Optional" : askedName)
            }
            if draft.askedUserID != nil {
              Button("Remove person", role: .destructive) {
                draft.askedUserID = nil
                askedName = ""
              }
            }
          }
        }
        Section {
          Picker("Responder group", selection: $draft.groupID) {
            ForEach(model.state.snapshot?.groups ?? []) { Text($0.name).tag($0.id) }
          }
          Picker("Visibility", selection: $draft.visibility) {
            Text("Visible to school").tag("school")
            if model.state.snapshot?.groups.contains(where: {
              $0.id == draft.groupID && $0.isMember
            }) == true {
              Text("Group members only").tag("group")
            }
          }
          Toggle("Post anonymously", isOn: $draft.anonymous)
        } header: {
          Text("Audience")
        } footer: {
          Text("Anonymous to students. Administrators can see your identity.")
        }
        if draft.kind != .gallery {
          Section {
            Picker(
              "Requested priority",
              selection: Binding(get: { draft.priority ?? "normal" }, set: { draft.priority = $0 })
            ) {
              Text("Normal").tag("normal")
              Text("Important").tag("important")
              Text("Urgent").tag("urgent")
            }
          } footer: {
            Text("Priority is reviewed by the server before publication.")
          }
        }
        if let error { Text(error).foregroundStyle(.red) }
        if busy { ProgressView("Preparing your post…") }
      }
      .formStyle(.grouped)
      .navigationTitle("New post")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            save()
            dismiss()
          }.disabled(busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Post") { publish() }.accessibilityIdentifier("publish-post").disabled(
            busy || !valid)
        }
      }
      .disabled(busy)
      .onAppear { if let saved = model.state.draft { draft = saved } }
      .onChange(of: draft) { _, _ in save() }
      .onChange(of: draft.kind) { _, value in
        if value != .question {
          draft.askedUserID = nil
          askedName = ""
        }
        if value == .gallery { draft.priority = "normal" }
      }
      .onChange(of: draft.groupID) { _, _ in
        if model.state.snapshot?.groups.contains(where: { $0.id == draft.groupID && $0.isMember })
          != true
        {
          draft.visibility = "school"
        }
      }
      .onChange(of: photos) { _, values in upload(values) }
      .sheet(isPresented: $pickingPerson) {
        NativeMemberPicker { person in
          draft.askedUserID = person.id
          askedName = person.name
          pickingPerson = false
        }
      }
    }.nativeSheetFrame(width: 600, height: 740).interactiveDismissDisabled(busy)
  }
  func save() {
    guard !published else { return }
    model.perform("draft", ["draft": model.dictionary(draft)])
  }
  func publish() {
    busy = true
    Task {
      do {
        let result = try await model.call("publish", ["draft": model.dictionary(draft)])
        published = true
        dismiss()
        if let message = result as? String {
          model.notice = NativeNotice(title: "Post", message: message)
        }
      } catch { self.error = error.localizedDescription }
      busy = false
    }
  }
  func upload(_ items: [PhotosPickerItem]) {
    guard !items.isEmpty else { return }
    busy = true
    Task {
      do {
        for item in items {
          guard let data = try await item.loadTransferable(type: Data.self),
            data.count <= 30 * 1024 * 1024
          else {
            throw NSError(
              domain: "Compass", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Choose an image smaller than 30 MB."])
          }
          guard
            let id = try await model.call("uploadPhoto", ["bytes": model.typedData(data)])
              as? String
          else { continue }
          draft.photoIDs = (draft.photoIDs ?? []) + [id]
        }
        photos = []
      } catch { self.error = error.localizedDescription }
      busy = false
    }
  }
}
struct NativeOwnPosts: View {
  @EnvironmentObject var model: NativeModel
  @State private var posts: [Post] = []
  @State private var loading = true
  var body: some View {
    List {
      if loading { ProgressView() }
      ForEach(posts) { post in
        NavigationLink {
          NativePostDetail(id: post.id, initial: post)
        } label: {
          VStack(alignment: .leading, spacing: 5) {
            Text(post.title)
            Text((post.status ?? "published").capitalized).font(.caption).foregroundStyle(
              .secondary)
          }
        }
      }
    }.navigationTitle("My Posts").task { await load() }.refreshable { await load() }.toolbar {
      Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
    }.nativeListStyle()
  }
  func load() async {
    do { posts = try model.decode(try await model.call("ownPosts"), as: [Post].self) } catch {
      model.show(error)
    }
    loading = false
  }
}
extension View {
  @ViewBuilder func nativeContentBackground() -> some View {
    #if os(iOS)
      self.background(Color(uiColor: .systemGroupedBackground))
    #else
      self.background(Color(nsColor: .textBackgroundColor))
    #endif
  }
  @ViewBuilder func nativeInlineTitle() -> some View {
    #if os(iOS)
      self.navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
  @ViewBuilder func nativeListStyle() -> some View {
    #if os(iOS)
      self.listStyle(.insetGrouped)
    #else
      self.listStyle(.inset)
    #endif
  }
}
