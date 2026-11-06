import SwiftUI

struct NativeProfile: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  @State private var editing = false
  var body: some View {
    NavigationStack {
      List {
        if let person = model.me {
          Section {
            VStack(spacing: 10) {
              NativeAvatar(person: person, size: 64)
              Text(person.name).font(.title2.weight(.semibold))
              Text(person.year + " · " + person.role).font(.subheadline).foregroundStyle(.secondary)
              if !person.bio.isEmpty {
                Text(person.bio).font(.callout).multilineTextAlignment(.center).foregroundStyle(
                  .secondary)
              }
              if !person.instagram.isEmpty,
                let url = URL(string: "https://www.instagram.com/\(person.instagram)/")
              {
                Link("@\(person.instagram)", destination: url).font(.callout)
              }
            }.frame(maxWidth: .infinity).padding(.vertical, 18)
          }
        }
        Section("Your space") {
          Button("Edit profile", systemImage: "person.crop.circle") { editing = true }
          NavigationLink {
            NativeOwnPosts()
          } label: {
            Label("My Posts", systemImage: "square.and.pencil")
          }
          NavigationLink {
            NativeFeed(mode: .saved)
          } label: {
            Label("Saved", systemImage: "bookmark")
          }
          NavigationLink {
            NativeTodos()
          } label: {
            Label("To Do", systemImage: "checklist")
          }
          NavigationLink {
            NativeAssignments()
          } label: {
            Label("Assignments", systemImage: "calendar")
          }
          if model.admin {
            NavigationLink {
              NativeAdmin()
            } label: {
              Label("Administrator", systemImage: "checkmark.shield")
            }
          }
        }
        Section {
          Button("Sign out", role: .destructive) {
            Task {
              do {
                _ = try await model.call("signOut")
                dismiss()
              } catch { model.show(error) }
            }
          }
        } footer: {
          Text(
            model.state.isDemo
              ? "Demo content stays on this device." : "Connected to your school community.")
        }
      }.nativeListStyle().navigationTitle("Profile").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
      }.sheet(isPresented: $editing) { NativeEditProfile() }
    }.nativeSheetFrame(width: 520, height: 700)
  }
}
struct NativeEditProfile: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var year = ""
  @State private var bio = ""
  @State private var instagram = ""
  @State private var busy = false
  var body: some View {
    NavigationStack {
      Form {
        Section("About you") {
          TextField("Name", text: $name)
          TextField("Year", text: $year)
          TextField("Bio", text: $bio, axis: .vertical).lineLimit(3...8)
        }
        Section("Social link") { TextField("Instagram username", text: $instagram) }
        Text("\(bio.count)/500 bio").font(.caption).foregroundStyle(.secondary)
      }.formStyle(.grouped).disabled(busy).navigationTitle("Edit profile").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }.disabled(
            busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bio.count > 500)
        }
      }.onAppear {
        if let person = model.me {
          name = person.name
          year = person.year
          bio = person.bio
          instagram = person.instagram
        }
      }
    }.nativeSheetFrame(width: 500, height: 520)
  }
  func save() {
    guard var person = model.me else { return }
    person.name = name
    person.year = year
    person.bio = bio
    person.instagram = instagram.hasPrefix("@") ? String(instagram.dropFirst()) : instagram
    busy = true
    Task {
      do {
        _ = try await model.call("profile", ["profile": model.dictionary(person)])
        dismiss()
      } catch { model.show(error) }
      busy = false
    }
  }
}
struct NativeMember: View {
  @EnvironmentObject var model: NativeModel
  let person: Profile
  @State private var chat: Conversation?
  @State private var blocking = false
  var body: some View {
    List {
      Section {
        VStack(spacing: 12) {
          NativeAvatar(person: person, size: 70)
          Text(person.name).font(.title2.weight(.semibold))
          Text(person.year + " · " + person.role).font(.subheadline).foregroundStyle(.secondary)
          Text(person.bio).font(.body).multilineTextAlignment(.center)
          if !person.instagram.isEmpty,
            let url = URL(string: "https://www.instagram.com/\(person.instagram)/")
          {
            Link("@\(person.instagram)", destination: url)
          }
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
      }
      if person.id != model.me?.id {
        Section {
          Button("Message", systemImage: "bubble.left") {
            Task {
              do {
                chat = try model.decode(
                  try await model.call("startChat", ["person": model.dictionary(person)]),
                  as: Conversation.self)
              } catch { model.show(error) }
            }
          }
          Button("Block member", systemImage: "hand.raised", role: .destructive) { blocking = true }
        }
      }
    }.nativeListStyle().navigationTitle(person.name).nativeInlineTitle().navigationDestination(
      item: $chat
    ) { NativeConversation(id: $0.id) }.confirmationDialog(
      "Block \(person.name)?", isPresented: $blocking, titleVisibility: .visible
    ) { Button("Block member", role: .destructive) { model.perform("block", ["id": person.id]) } }
  }
}
struct NativeTodos: View {
  @EnvironmentObject var model: NativeModel
  @State private var editing: NativeTodo?
  var todos: [NativeTodo] { model.state.planner.todos }
  var body: some View {
    List {
      if todos.isEmpty {
        ContentUnavailableView(
          "A little breathing room", systemImage: "checkmark.circle",
          description: Text("Add a task, or bring one over from Assignments."))
      }
      let unfinished = todos.filter { $0.completed != true }
      if !unfinished.isEmpty { Section("To do") { ForEach(unfinished) { row($0) } } }
      let done = todos.filter { $0.completed == true }
      if !done.isEmpty { Section("Completed") { ForEach(done) { row($0) } } }
    }.nativeListStyle().navigationTitle("To Do").toolbar {
      Button("Add task", systemImage: "plus") {
        editing = NativeTodo(id: UUID().uuidString, title: "", notes: "", completed: false)
      }
    }.sheet(item: $editing) { NativeTaskEditor(todo: $0) }
  }
  func row(_ todo: NativeTodo) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        var value = todo
        value.completed = !(todo.completed ?? false)
        model.perform("todoSave", ["todo": model.dictionary(value)])
      } label: {
        Image(systemName: todo.completed == true ? "checkmark.circle.fill" : "circle").font(.title3)
          .foregroundStyle(todo.completed == true ? Color.accentColor : .secondary)
      }.buttonStyle(.plain).accessibilityLabel(
        todo.completed == true ? "Mark incomplete" : "Mark complete")
      Button {
        editing = todo
      } label: {
        VStack(alignment: .leading, spacing: 5) {
          Text(todo.title).strikethrough(todo.completed == true).foregroundStyle(.primary)
          if let due = nativeDate(todo.due) {
            Text(due, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(
              due < Date() && todo.completed != true ? .red : .secondary)
          }
          if let notes = todo.notes, !notes.isEmpty {
            Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain)
    }.padding(.vertical, 6).contextMenu {
      Button("Edit", systemImage: "pencil") { editing = todo }
      Button("Delete task", systemImage: "trash", role: .destructive) {
        model.perform("todoRemove", ["id": todo.id])
      }
    }
  }
}
struct NativeTaskEditor: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  @State var todo: NativeTodo
  @State private var date = Date()
  @State private var hasDate = false
  @State private var busy = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Task", text: $todo.title)
          TextField(
            "Notes", text: Binding(get: { todo.notes ?? "" }, set: { todo.notes = $0 }),
            axis: .vertical
          ).lineLimit(4...8)
        }
        Section {
          Toggle("Due date", isOn: $hasDate)
          if hasDate { DatePicker("Due", selection: $date, displayedComponents: .date) }
        }
      }.formStyle(.grouped).disabled(busy).navigationTitle("Task").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            busy = true
            todo.due = hasDate ? ISO8601DateFormatter().string(from: date) : nil
            Task {
              do {
                _ = try await model.call("todoSave", ["todo": model.dictionary(todo)])
                dismiss()
              } catch { model.show(error) }
              busy = false
            }
          }.disabled(
            todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || todo.title.count > 200 || busy)
        }
      }.onAppear {
        if let stored = nativeDate(todo.due) {
          date = stored
          hasDate = true
        }
      }
    }.nativeSheetFrame(width: 480, height: 460)
  }
}
struct NativeAssignments: View {
  @EnvironmentObject var model: NativeModel
  @State private var connecting = false
  @State private var disconnecting = false
  @State private var feed = ""
  @State private var query = ""
  @State private var testsOnly = false
  var planner: NativePlanner { model.state.planner }
  var items: [NativeAssignment] {
    planner.assignments.filter {
      (query.isEmpty || ($0.title + " " + $0.details).localizedCaseInsensitiveContains(query))
        && (!testsOnly || $0.isTest)
    }
  }
  var courses: [String] { Array(Set(items.map(\.course))).sorted() }
  var body: some View {
    List {
      if !planner.connected {
        Section {
          ContentUnavailableView {
            Label("Your school day, together", systemImage: "calendar")
          } description: {
            Text(
              "Connect your private My Buckley calendar to see assignments and upcoming assessments."
            )
          } actions: {
            Button("Connect My Buckley") { connecting = true }.buttonStyle(.borderedProminent)
          }
        }
      }
      if planner.syncing { ProgressView("Syncing assignments…") }
      if let error = planner.error { Text(error).foregroundStyle(.red) }
      if let last = nativeDate(planner.lastSync) {
        Text("Updated \(last.formatted(date:.abbreviated,time:.shortened))").font(.caption)
          .foregroundStyle(.secondary)
      }
      if planner.connected && items.isEmpty { ContentUnavailableView.search(text: query) }
      ForEach(courses, id: \.self) { course in
        Section(course) {
          ForEach(items.filter { $0.course == course }) { assignment in
            NavigationLink {
              detail(assignment)
            } label: {
              VStack(alignment: .leading, spacing: 5) {
                Text(assignment.displayTitle)
                HStack(spacing: 6) {
                  if assignment.isTest { Image(systemName: "pencil.and.list.clipboard") }
                  if let date = nativeDate(assignment.due ?? assignment.date) {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                  } else {
                    Text("No readable date")
                  }
                  if let points = assignment.points { Text("· \(points) points") }
                }.font(.caption).foregroundStyle(.secondary)
              }.padding(.vertical, 5)
            }
          }
        }
      }
    }
    .nativeListStyle().navigationTitle("Assignments").searchable(
      text: $query, prompt: "Search assignments"
    )
    .toolbar {
      if planner.connected {
        Button("Sync", systemImage: "arrow.clockwise") { model.perform("syncFeed") }.disabled(
          planner.syncing)
      }
      Menu {
        Toggle("Tests & quizzes only", isOn: $testsOnly)
        Divider()
        Button("Connect or replace feed", systemImage: "link") { connecting = true }
        if planner.connected {
          Button("Disconnect feed", systemImage: "link.badge.plus", role: .destructive) {
            disconnecting = true
          }
        }
      } label: {
        Label("Assignment options", systemImage: "line.3.horizontal.decrease")
      }
    }
    .sheet(isPresented: $connecting) { connectSheet }
    .confirmationDialog(
      "Disconnect and remove cached assignments?", isPresented: $disconnecting,
      titleVisibility: .visible
    ) { Button("Disconnect", role: .destructive) { model.perform("disconnectFeed") } }
  }
  func detail(_ item: NativeAssignment) -> some View {
    Form {
      Section {
        Text(item.displayTitle).font(.title2.weight(.semibold))
        Text(item.course).foregroundStyle(.secondary)
        Text(item.details).textSelection(.enabled)
      }
      Section {
        if let due = nativeDate(item.due ?? item.date) {
          LabeledContent(
            "Due",
            value: due.formatted(date: .abbreviated, time: item.allDay ? .omitted : .shortened))
        }
        if let points = item.points { LabeledContent("Points", value: points) }
        if let note = item.note, !note.isEmpty {
          Label(note, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
        }
      }
      Section {
        Button(
          model.state.planner.todos.contains(where: { $0.assignmentID == item.id })
            ? "Added to To Do" : "Add to To Do", systemImage: "plus.circle"
        ) { model.perform("assignmentTodo", ["assignment": model.dictionary(item)]) }.disabled(
          model.state.planner.todos.contains(where: { $0.assignmentID == item.id }))
        if let link = item.link, let url = URL(string: link) {
          Link("Open My Buckley", destination: url)
        }
      }
    }.formStyle(.grouped).navigationTitle("Assignment").nativeInlineTitle()
  }
  var connectSheet: some View {
    NavigationStack {
      Form {
        Section {
          Text("In My Buckley, open the calendar and copy the full iCalendar Feed URL.")
          SecureField("Private Feed URL", text: $feed)
        } footer: {
          Text(
            "Your private URL stays in your system keychain. It is never sent to the community server."
          )
        }
        if planner.syncing { ProgressView() }
        if let error = planner.error { Text(error).foregroundStyle(.red) }
      }.formStyle(.grouped).navigationTitle("Connect My Buckley").toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            connecting = false
            feed = ""
          }.disabled(planner.syncing)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Connect") {
            Task {
              do {
                _ = try await model.call("feed", ["url": feed])
                feed = ""
                connecting = false
              } catch { model.show(error) }
            }
          }.disabled(feed.isEmpty || planner.syncing)
        }
      }
    }.nativeSheetFrame(width: 500, height: 380).interactiveDismissDisabled(planner.syncing)
  }
}
