import SwiftUI

struct NativeAdmin: View {
  @EnvironmentObject var model: NativeModel
  @State private var reports = false
  @State private var status = "all"
  @State private var query = ""
  @State private var posts: [AdminPost] = []
  @State private var items: [AdminReport] = []
  @State private var offset: Int?
  @State private var busy = false
  var body: some View {
    List {
      Section {
        Picker("Review", selection: $reports) {
          Text("Posts").tag(false)
          Text("Reports").tag(true)
        }.pickerStyle(.segmented)
      }
      if busy { ProgressView() }
      if reports {
        ForEach(items) { report in
          NavigationLink {
            NativeAdminReport(report: report)
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(report.postTitle)
              Text(report.reason).font(.callout).foregroundStyle(.secondary)
              Text(report.resolved ? "Resolved" : "Open").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      } else {
        ForEach(posts) { item in
          NavigationLink {
            NativeAdminPost(id: item.id)
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(item.post.title)
              Text(item.author.name + " · " + item.authorEmail).font(.caption).foregroundStyle(
                .secondary)
              Text((item.post.status ?? "published").capitalized).font(.caption).foregroundStyle(
                .secondary)
            }
          }
        }
      }
      if offset != nil { Button("Load more") { Task { await load(more: true) } }.disabled(busy) }
    }.nativeListStyle().navigationTitle("Administrator").searchable(
      text: $query, prompt: "Post, author or email"
    ).onSubmit(of: .search) { Task { await load() } }.toolbar {
      Menu {
        Picker("Status", selection: $status) {
          ForEach(
            reports ? ["all", "open", "resolved"] : ["all", "published", "pending", "rejected"],
            id: \.self
          ) { Text($0.capitalized).tag($0) }
        }
      } label: {
        Label("Status", systemImage: "line.3.horizontal.decrease")
      }
      Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
    }.task { await load() }.onChange(of: reports) { _, _ in
      status = "all"
      Task { await load() }
    }.onChange(of: status) { _, _ in Task { await load() } }
  }
  func load(more: Bool = false) async {
    guard !busy else { return }
    busy = true
    do {
      let value = try await model.call(
        "admin",
        [
          "path": reports ? "reports/list" : "posts/list",
          "body": ["status": status, "query": query, "offset": more ? offset ?? 0 : 0],
        ])
      if reports {
        let page = try model.decode(value, as: AdminPage<AdminReport>.self)
        items = (more ? items : []) + page.items
        offset = page.nextOffset
      } else {
        let page = try model.decode(value, as: AdminPage<AdminPost>.self)
        posts = (more ? posts : []) + page.items
        offset = page.nextOffset
      }
    } catch { model.show(error) }
    busy = false
  }
}
struct NativeAdminPost: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let id: String
  @State private var item: AdminPost?
  @State private var deleting = false
  @State private var deletingReply: String?
  @State private var busy = false
  var body: some View {
    Form {
      if let item {
        Section("Author · Administrator only") {
          Text(item.author.name)
          Text(item.authorEmail).textSelection(.enabled)
          Text(item.author.year)
          if item.post.anonymous {
            Label("Anonymous to other students", systemImage: "person.fill.questionmark")
          }
        }
        Section {
          Text(item.post.title).font(.title2)
          Text(item.post.body).textSelection(.enabled)
          ForEach(item.post.photoIDs ?? [], id: \.self) { NativePhoto(id: $0) }
          LabeledContent("Status", value: item.post.status ?? "published")
        }
        Section("Moderation") {
          if item.post.status != "published" {
            Button("Publish post", systemImage: "checkmark") { review("published") }
          }
          if item.post.status != "rejected" {
            Button("Reject post", systemImage: "xmark") { review("rejected") }
          }
          Button("Delete post", systemImage: "trash", role: .destructive) { deleting = true }
        }
        Section("Comments") {
          ForEach(item.post.replies) { reply in
            VStack(alignment: .leading, spacing: 8) {
              Text(reply.author.name).font(.headline)
              Text(reply.body)
              Button("Delete comment", role: .destructive) { deletingReply = reply.id }
            }
          }
        }
      } else {
        ProgressView()
      }
    }.formStyle(.grouped).navigationTitle("Manage post").disabled(busy).task { await load() }
      .confirmationDialog(
        "Delete this post and its comments?", isPresented: $deleting, titleVisibility: .visible
      ) { Button("Delete post", role: .destructive) { review(nil) } }
      .confirmationDialog(
        "Delete this comment?",
        isPresented: Binding(
          get: { deletingReply != nil }, set: { if !$0 { deletingReply = nil } }),
        titleVisibility: .visible
      ) {
        Button("Delete comment", role: .destructive) {
          if let replyID = deletingReply {
            Task {
              do {
                _ = try await model.call(
                  "admin", ["path": "replies/" + replyID, "method": "DELETE"])
                await load()
              } catch { model.show(error) }
            }
          }
          deletingReply = nil
        }
      }
  }
  func load() async {
    do {
      item = try model.decode(
        try await model.call("admin", ["path": "posts/" + id, "method": "GET"]), as: AdminPost.self)
    } catch { model.show(error) }
  }
  func review(_ status: String?) {
    busy = true
    Task {
      do {
        var args: [String: Any] = [
          "path": "posts/" + id, "method": status == nil ? "DELETE" : "PATCH",
        ]
        if let status { args["body"] = ["status": status] }
        _ = try await model.call("admin", args)
        if status == nil { dismiss() } else { await load() }
      } catch { model.show(error) }
      busy = false
    }
  }
}
struct NativeAdminReport: View {
  @EnvironmentObject var model: NativeModel
  @Environment(\.dismiss) var dismiss
  let report: AdminReport
  @State private var note = ""
  @State private var deleting = false
  @State private var busy = false
  var body: some View {
    Form {
      Section("Report") {
        Text(report.reason)
        Text("From " + report.reporter.name).foregroundStyle(.secondary)
        Text(Date(timeIntervalSince1970: report.createdAt), style: .date).foregroundStyle(
          .secondary)
      }
      Section("Post") {
        if report.postExists {
          NavigationLink(report.postTitle) { NativeAdminPost(id: report.postID) }
        } else {
          Text("Post deleted or expired").foregroundStyle(.secondary)
        }
      }
      if report.resolved {
        Section("Resolved") {
          Text(report.decision.capitalized)
          Text(report.note)
        }
      } else {
        Section {
          TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(3...6)
          Button("Dismiss report") { resolve("dismissed") }
          Button("Delete post & resolve", role: .destructive) { deleting = true }
        }
      }
    }.formStyle(.grouped).navigationTitle("Report").disabled(busy).confirmationDialog(
      "Delete the post and resolve its reports?", isPresented: $deleting, titleVisibility: .visible
    ) { Button("Delete post & resolve", role: .destructive) { resolve("deleted") } }
  }
  func resolve(_ decision: String) {
    busy = true
    Task {
      do {
        _ = try await model.call(
          "admin",
          ["path": "reports/\(report.id)/resolve", "body": ["decision": decision, "note": note]])
        dismiss()
      } catch { model.show(error) }
      busy = false
    }
  }
}
