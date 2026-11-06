part of 'ui.dart';

class ProfilePage extends StatelessWidget {
  final CampusStore store;
  final PlannerStore planner;
  const ProfilePage({super.key, required this.store, required this.planner});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(
        children: [
          Center(child: avatar(store.me, radius: 40)),
          const SizedBox(height: 18),
          Center(
            child: Text(
              text(store.me, 'name'),
              style: const TextStyle(fontSize: 26),
            ),
          ),
          Center(
            child: Text(
              '${store.me['year']} · ${store.me['role']}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          Text(text(store.me, 'bio')),
          if (text(store.me, 'instagram').isNotEmpty)
            TextButton(
              onPressed: () => launchUrl(
                Uri.https('www.instagram.com', '/${store.me['instagram']}/'),
              ),
              child: Text('@${store.me['instagram']}'),
            ),
          section('Your space'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => go(context, EditProfilePage(store: store)),
                ),
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('To Do'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => go(context, TodosPage(planner: planner)),
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('My Buckley assignments'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => go(context, AssignmentsPage(planner: planner)),
                ),
                if (store.admin)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Administrator'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => go(context, AdminPage(store: store)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            store.demo
                ? 'Demo mode · Sample data stays on this device.'
                : 'Signed in to your school account.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => guard(context, () async {
              await store.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

class EditProfilePage extends StatefulWidget {
  final CampusStore store;
  const EditProfilePage({super.key, required this.store});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final name = TextEditingController(text: text(widget.store.me, 'name')),
      year = TextEditingController(text: text(widget.store.me, 'year')),
      bio = TextEditingController(text: text(widget.store.me, 'bio')),
      instagram = TextEditingController(
        text: text(widget.store.me, 'instagram'),
      );
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    year.dispose();
    bio.dispose();
    instagram.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: PageBody(
      children: [
        field(name, 'Name', limit: 80),
        field(year, 'Year', limit: 40),
        field(bio, 'Bio', lines: 4, limit: 500),
        field(instagram, 'Instagram username', limit: 30),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  await guard(context, () async {
                    if (name.text.trim().isEmpty) {
                      throw Exception('Enter your name.');
                    }
                    final handle = instagram.text.trim().replaceFirst('@', '');
                    if (handle.isNotEmpty &&
                        !RegExp(r'^[A-Za-z0-9_.]{1,30}$').hasMatch(handle)) {
                      throw Exception(
                        'Enter an Instagram username, without a link.',
                      );
                    }
                    await widget.store.profile({
                      ...widget.store.me,
                      'name': name.text.trim(),
                      'year': year.text.trim(),
                      'bio': bio.text.trim(),
                      'instagram': handle,
                    });
                    if (context.mounted) Navigator.pop(context);
                  });
                  if (mounted) setState(() => busy = false);
                },
          child: Text(busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

class MemberPage extends StatelessWidget {
  final CampusStore store;
  final Json person;
  const MemberPage({super.key, required this.store, required this.person});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('School member')),
    body: PageBody(
      children: [
        Center(child: avatar(person, radius: 40)),
        const SizedBox(height: 18),
        Text(text(person, 'name'), style: const TextStyle(fontSize: 28)),
        Text('${person['year']} · ${person['role']}'),
        const SizedBox(height: 16),
        Text(text(person, 'bio')),
        if (text(person, 'instagram').isNotEmpty)
          TextButton(
            onPressed: () => launchUrl(
              Uri.https('www.instagram.com', '/${person['instagram']}/'),
            ),
            child: Text('@${person['instagram']}'),
          ),
        if (person['id'] != store.me['id']) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => guard(context, () async {
              final c = await store.startChat(person);
              if (context.mounted) {
                go(context, ChatPage(store: store, id: text(c, 'id')));
              }
            }),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Message'),
          ),
          TextButton(
            onPressed: () => guard(context, () async {
              if (await confirm(context, 'Block this member?')) {
                await store.block(text(person, 'id'));
                if (context.mounted) Navigator.pop(context);
              }
            }),
            child: const Text('Block member'),
          ),
        ],
      ],
    ),
  );
}

class TodosPage extends StatelessWidget {
  final PlannerStore planner;
  const TodosPage({super.key, required this.planner});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('To Do'),
        actions: [
          IconButton(
            tooltip: 'Add task',
            onPressed: () => go(context, TodoEditor(planner: planner)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: PageBody(
        children: [
          if (planner.todos.isEmpty)
            empty(
              'Your personal task list is clear.',
              Icons.check_circle_outline,
            ),
          for (final t in planner.todos)
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: t['completed'] == true,
                  onChanged: (v) => guard(
                    context,
                    () => planner.saveTodo({...t, 'completed': v}),
                  ),
                ),
                title: Text(
                  text(t, 'title'),
                  style: TextStyle(
                    decoration: t['completed'] == true
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  [
                    if (t['due'] != null)
                      DateFormat('MMM d, yyyy')
                          .format(DateTime.parse(text(t, 'due')).toLocal()),
                    if (text(t, 'notes').isNotEmpty) text(t, 'notes'),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Delete task',
                  onPressed: () =>
                      guard(context, () => planner.remove(text(t, 'id'))),
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () =>
                    go(context, TodoEditor(planner: planner, initial: t)),
              ),
            ),
        ],
      ),
    ),
  );
}

class TodoEditor extends StatefulWidget {
  final PlannerStore planner;
  final Json? initial;
  const TodoEditor({super.key, required this.planner, this.initial});
  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late final title = TextEditingController(
        text: text(widget.initial ?? {}, 'title'),
      ),
      notes = TextEditingController(text: text(widget.initial ?? {}, 'notes'));
  late DateTime? due = DateTime.tryParse(text(widget.initial ?? {}, 'due'));
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Task')),
    body: PageBody(
      children: [
        field(title, 'Task', limit: 200),
        field(notes, 'Notes', lines: 5),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due date'),
          subtitle: Text(
            due == null ? 'None' : DateFormat('MMM d, yyyy').format(due!),
          ),
          trailing: IconButton(
            tooltip: 'Clear date',
            onPressed: () => setState(() => due = null),
            icon: const Icon(Icons.close),
          ),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: due ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null && mounted) setState(() => due = d);
          },
        ),
        FilledButton(
          onPressed: () => guard(context, () async {
            await widget.planner.saveTodo({
              ...?widget.initial,
              'id': widget.initial?['id'] ?? newID(),
              'title': title.text,
              'notes': notes.text,
              'due': due?.toIso8601String(),
              'completed': widget.initial?['completed'] ?? false,
            });
            if (context.mounted) Navigator.pop(context);
          }),
          child: const Text('Save task'),
        ),
      ],
    ),
  );
}

class AssignmentsPage extends StatefulWidget {
  final PlannerStore planner;
  const AssignmentsPage({super.key, required this.planner});
  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  String query = '';
  bool assessments = false;
  Future<void> connect() async {
    final value = await prompt(
      context,
      'Paste your My Buckley Feed URL',
      secret: true,
    );
    if (value != null && value.isNotEmpty && mounted) {
      await widget.planner.connect(value);
    }
  }

  String course(Json a) {
    final title = text(a, 'title');
    final m = RegExp(r'\s+[-–—]\s*|\s*[-–—]\s+').firstMatch(title);
    if (m != null) return title.substring(0, m.start).trim();
    final i = title.indexOf('-');
    return i > 0 ? title.substring(0, i).trim() : 'Other';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.planner,
    builder: (context, _) {
      final p = widget.planner;
      final items = p.assignments
          .where(
            (a) =>
                ('${a['title']} ${a['details']}').toLowerCase().contains(
                  query.toLowerCase(),
                ) &&
                (!assessments ||
                    RegExp(
                      r'\b(?:tests?|quizzes|quiz)(?:\b|(?=\d))',
                      caseSensitive: false,
                    ).hasMatch(text(a, 'title'))),
          )
          .toList();
      final courses = items.map(course).toSet().toList()..sort();
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Buckley assignments'),
          actions: [
            if (p.connected)
              IconButton(
                tooltip: 'Sync assignments',
                onPressed: p.syncing ? null : () => p.sync(),
                icon: const Icon(Icons.sync),
              ),
            PopupMenuButton<String>(
              onSelected: (v) => guard(context, () async {
                if (v == 'connect') {
                  await connect();
                  return;
                }
                if (v == 'disconnect' &&
                    await confirm(
                      context,
                      'Disconnect this school feed and remove its cached assignments?',
                    )) {
                  await p.disconnect();
                }
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'connect',
                  child: Text('Connect or replace feed'),
                ),
                if (p.connected)
                  const PopupMenuItem(
                    value: 'disconnect',
                    child: Text('Disconnect feed'),
                  ),
              ],
            ),
          ],
        ),
        body: PageBody(
          children: [
            if (!p.connected) ...[
              const Text(
                'In My Buckley, open your calendar and copy its complete iCalendar Feed URL. Your private feed stays on this device and is never sent to the community server.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: p.syncing ? null : connect,
                child: const Text('Connect My Buckley'),
              ),
            ],
            if (p.syncing) const LinearProgressIndicator(),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  p.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (p.lastSync != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Last synced ${DateFormat('MMM d · h:mm a').format(DateTime.parse(p.lastSync!).toLocal())}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Search assignments',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tests & quizzes only'),
              value: assessments,
              onChanged: (v) => setState(() => assessments = v),
            ),
            if (p.connected && items.isEmpty)
              empty('No matching assignments.', Icons.assignment_outlined),
            for (final c in courses) ...[
              section(c),
              for (final a in items.where((a) => course(a) == c))
                Card(
                  child: ExpansionTile(
                    title: Text(text(a, 'title')),
                    subtitle: Text(
                      a['date'] == null
                          ? 'No readable date'
                          : DateFormat(
                              a['allDay'] == true
                                  ? 'MMM d, yyyy'
                                  : 'MMM d · h:mm a',
                            ).format(DateTime.parse(text(a, 'date')).toLocal()),
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(text(a, 'details')),
                      if (a['points'] != null) Text('Points: ${a['points']}'),
                      if (text(a, 'note').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            text(a, 'note'),
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      if (a['link'] != null)
                        TextButton(
                          onPressed: () =>
                              launchUrl(Uri.parse(text(a, 'link'))),
                          child: const Text('Open My Buckley'),
                        ),
                      TextButton.icon(
                        onPressed:
                            p.todos.any((t) => t['assignmentID'] == a['id'])
                            ? null
                            : () => guard(context, () => p.addAssignment(a)),
                        icon: const Icon(Icons.add_task),
                        label: Text(
                          p.todos.any((t) => t['assignmentID'] == a['id'])
                              ? 'Added to To Do'
                              : 'Add to To Do',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class AdminPage extends StatefulWidget {
  final CampusStore store;
  const AdminPage({super.key, required this.store});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool reports = false, busy = false;
  String status = 'all', query = '';
  List<Json> items = [];
  int? next;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await widget.store.administrator(
        '${reports ? 'reports' : 'posts'}/list',
        body: {
          'status': status,
          'query': query,
          'offset': more ? next ?? 0 : 0,
        },
      ) as Json;
      if (mounted) {
        setState(() {
          items = [if (more) ...items, ...rows(data['items'])];
          next = data['nextOffset'] as int?;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.store.admin) {
      return Scaffold(
        appBar: AppBar(),
        body: empty('Administrator access required.', Icons.lock_outline),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PageBody(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Posts')),
              ButtonSegment(value: true, label: Text('Reports')),
            ],
            selected: {reports},
            onSelectionChanged: busy
                ? null
                : (v) {
                    setState(() {
                      reports = v.first;
                      status = 'all';
                    });
                    load();
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(reports),
            initialValue: status,
            items: [
              for (final s
                  in reports
                      ? ['all', 'open', 'resolved']
                      : ['all', 'published', 'pending', 'rejected'])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: busy
                ? null
                : (v) {
                    setState(() => status = v!);
                    load();
                  },
          ),
          if (!reports)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                onSubmitted: (v) {
                  query = v;
                  load();
                },
                decoration: const InputDecoration(
                  hintText: 'Search post, author or email',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          for (final item in items)
            Card(
              child: ListTile(
                title: Text(
                  reports
                      ? text(item, 'postTitle')
                      : text(item['post'] as Json, 'title'),
                ),
                subtitle: Text(
                  reports
                      ? '${item['reason']} · ${item['resolved'] == true ? 'resolved' : 'open'}'
                      : '${text(item['author'] as Json, 'name')} · ${item['authorEmail']} · ${(item['post'] as Json)['status']}',
                ),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => reports
                          ? AdminReportPage(store: widget.store, report: item)
                          : AdminPostPage(
                              store: widget.store,
                              id: text(item['post'] as Json, 'id'),
                            ),
                    ),
                  );
                  if (mounted) load();
                },
              ),
            ),
          if (next != null)
            TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}

class AdminPostPage extends StatefulWidget {
  final CampusStore store;
  final String id;
  const AdminPostPage({super.key, required this.store, required this.id});
  @override
  State<AdminPostPage> createState() => _AdminPostPageState();
}

class _AdminPostPageState extends State<AdminPostPage> {
  late Future<Json> data;
  bool busy = false;
  Future<Json> fetch() async =>
      await widget.store.administrator('posts/${widget.id}', method: 'GET')
          as Json;
  @override
  void initState() {
    super.initState();
    data = fetch();
  }

  Future<void> review(String? status) async {
    if (status == null &&
        !await confirm(context, 'Delete this post and its comments?')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await guard(context, () async {
      await widget.store.administrator(
        'posts/${widget.id}',
        method: status == null ? 'DELETE' : 'PATCH',
        body: status == null ? null : {'status': status},
      );
      await widget.store.refresh();
      if (mounted) {
        if (status == null) {
          Navigator.pop(context);
        } else {
          setState(() => data = fetch());
        }
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage post')),
    body: FutureBuilder<Json>(
      future: data,
      builder: (context, s) {
        if (s.hasError) return empty(s.error.toString(), Icons.error_outline);
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final a = s.data!, p = a['post'] as Json;
        return PageBody(
          children: [
            section('Author · Administrator only'),
            Text(text(a['author'] as Json, 'name')),
            SelectableText(text(a, 'authorEmail')),
            if (p['anonymous'] == true)
              const Text('Anonymous to other students'),
            section(text(p, 'title')),
            SelectableText(text(p, 'body')),
            Text('Status: ${p['status']}'),
            for (final id in p['photoIDs'] as List? ?? [])
              PhotoView(store: widget.store, id: id as String),
            section('Moderation'),
            if (p['status'] != 'published')
              FilledButton(
                onPressed: busy ? null : () => review('published'),
                child: const Text('Publish post'),
              ),
            if (p['status'] != 'rejected')
              TextButton(
                onPressed: busy ? null : () => review('rejected'),
                child: const Text('Reject post'),
              ),
            TextButton(
              onPressed: busy ? null : () => review(null),
              child: const Text('Delete post'),
            ),
            section('Comments'),
            for (final r in rows(p['replies']))
              Card(
                child: ListTile(
                  title: Text(text(r['author'] as Json, 'name')),
                  subtitle: Text(text(r, 'body')),
                  trailing: IconButton(
                    tooltip: 'Delete comment',
                    onPressed: busy
                        ? null
                        : () => guard(context, () async {
                            if (await confirm(
                              context,
                              'Delete this comment?',
                            )) {
                              await widget.store.administrator(
                                'replies/${r['id']}',
                                method: 'DELETE',
                              );
                              if (mounted) setState(() => data = fetch());
                            }
                          }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AdminReportPage extends StatefulWidget {
  final CampusStore store;
  final Json report;
  const AdminReportPage({super.key, required this.store, required this.report});
  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  final note = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> resolve(String decision) async {
    if (decision == 'deleted' &&
        !await confirm(
          context,
          'Delete the reported post and resolve its reports?',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await guard(context, () async {
      await widget.store.administrator(
        'reports/${widget.report['id']}/resolve',
        body: {'decision': decision, 'note': note.text},
      );
      await widget.store.refresh();
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: PageBody(
        children: [
          section('Report'),
          Text(text(r, 'reason')),
          Text('From ${text(r['reporter'] as Json, 'name')}'),
          Text(stamp(r['createdAt'])),
          if (r['postExists'] == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text(r, 'postTitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => go(
                context,
                AdminPostPage(store: widget.store, id: text(r, 'postID')),
              ),
            )
          else
            const Text('Post deleted or expired'),
          if (r['resolved'] == true) ...[
            section('Resolved'),
            Text(text(r, 'decision')),
            Text(text(r, 'note')),
          ] else ...[
            field(note, 'Moderator note (optional)', lines: 4, limit: 1000),
            FilledButton(
              onPressed: busy ? null : () => resolve('dismissed'),
              child: const Text('Dismiss report'),
            ),
            TextButton(
              onPressed: busy ? null : () => resolve('deleted'),
              child: const Text('Delete post & resolve'),
            ),
          ],
        ],
      ),
    );
  }
}
