import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;

import 'photos.dart';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'store.dart';
import 'planner.dart';
part 'feed_ui.dart';
part 'chat_ui.dart';
part 'profile_ui.dart';

void toast(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}

Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> prompt(
  BuildContext context,
  String title, {
  String initial = '',
  bool secret = false,
  int maxLines = 1,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: secret,
        maxLines: maxLines,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // The dialog's exit animation may still use its controller.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

void go(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
String stamp(dynamic seconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    ((seconds as num? ?? 0) * 1000).round(),
  ).toLocal();
  return DateFormat('MMM d · h:mm a').format(date);
}

Widget avatar(Json person, {double radius = 21}) => CircleAvatar(
  radius: radius,
  backgroundColor: const Color(0xffe8e5e0),
  foregroundColor: const Color(0xff49453f),
  child: Text(initials(person), style: TextStyle(fontSize: radius * .65)),
);
Widget empty(String title, IconData icon) => Padding(
  padding: const EdgeInsets.all(36),
  child: Column(
    children: [
      Icon(icon, size: 38, color: Colors.grey),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center),
    ],
  ),
);
Widget section(String title) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 12),
  child: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  ),
);
Widget field(
  TextEditingController controller,
  String label, {
  int lines = 1,
  int? limit,
  bool secret = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: TextField(
    controller: controller,
    obscureText: secret,
    maxLines: lines,
    maxLength: limit,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  ),
);

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double width;
  const PageBody({super.key, required this.children, this.width = 700});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: children,
      ),
    ),
  );
}

class CompassApp extends StatefulWidget {
  final CampusStore store;
  final PlannerStore planner;
  const CompassApp({super.key, required this.store, required this.planner});
  @override
  State<CompassApp> createState() => _CompassAppState();
}

class _CompassAppState extends State<CompassApp> with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        widget.store.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff6a353d),
          brightness: brightness,
        ),
        scaffoldBackgroundColor: dark
            ? const Color(0xff191919)
            : const Color(0xfff7f6f3),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: dark ? const Color(0xff242424) : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xff242424) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Compass · Buckley Community',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final s = widget.store;
          if (s.restoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (s.snapshot == null) return WelcomePage(store: s);
          if (s.onboarding) return OnboardingPage(store: s);
          return HomeShell(
            key: ValueKey(s.scope),
            store: s,
            planner: widget.planner,
          );
        },
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  final CampusStore store;
  const WelcomePage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.explore_outlined,
                size: 64,
                color: Color(0xff6a353d),
              ),
              const SizedBox(height: 36),
              const Text(
                'Compass',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -2,
                ),
              ),
              const Text(
                'BUCKLEY COMMUNITY',
                style: TextStyle(letterSpacing: 3, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const Text(
                'Find your people.\nMake campus feel like home.',
                style: TextStyle(fontSize: 25, height: 1.4),
              ),
              const SizedBox(height: 32),
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    store.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => go(context, LoginPage(store: store)),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Join your school'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => guard(context, store.enterDemo),
                child: const Text('Explore the demo'),
              ),
              const SizedBox(height: 24),
              const Text(
                'A student-led community. Demo students and conversations are fictional.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final CampusStore store;
  const LoginPage({super.key, required this.store});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final server = TextEditingController(
    text:
        widget.store.prefs.getString('serverURL') ??
        'https://api.buckley.community',
  );
  final email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool useCode = false, busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    server.dispose();
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(bool request) async {
    setState(() => busy = true);
    try {
      await widget.store.connect(server.text);
      if (request) {
        await widget.store.requestCode(email.text.trim());
        if (mounted) setState(() => sent = true);
      } else {
        await widget.store.authenticate(
          email.text.trim(),
          useCode ? code.text : password.text,
          code: useCode,
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your school account')),
    body: PageBody(
      width: 480,
      children: [
        const Text(
          'Use your existing school account, or request an email code to join or reset your password.',
        ),
        field(server, 'Campus server'),
        field(email, 'School email'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use an email code'),
          value: useCode,
          onChanged: busy ? null : (v) => setState(() => useCode = v),
        ),
        if (useCode) ...[
          OutlinedButton(
            onPressed: busy ? null : () => run(true),
            child: Text(sent ? 'Send a new code' : 'Send email code'),
          ),
          if (sent) const Text('Check your school inbox.'),
          field(code, 'Email code'),
        ] else
          field(password, 'Password', secret: true),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : () => run(false),
          child: Text(busy ? 'Connecting…' : 'Continue'),
        ),
      ],
    ),
  );
}

class OnboardingPage extends StatefulWidget {
  final CampusStore store;
  const OnboardingPage({super.key, required this.store});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final password = TextEditingController(), repeat = TextEditingController();
  late final name = TextEditingController(text: text(widget.store.me, 'name'));
  String year = 'Grade 11';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    repeat.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final needsPass = s.snapshot?['needsPassword'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(needsPass ? 'Set your password' : 'Your school profile'),
        actions: [
          TextButton(
            onPressed: busy ? null : s.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: PageBody(
        width: 480,
        children: [
          if (needsPass) ...[
            field(password, 'New password', secret: true),
            field(repeat, 'Confirm password', secret: true),
          ] else ...[
            field(name, 'Full name', limit: 80),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: year,
              items: [
                for (final y in [
                  'Grade 9',
                  'Grade 10',
                  'Grade 11',
                  'Grade 12',
                  'Faculty',
                  'Staff',
                ])
                  DropdownMenuItem(value: y, child: Text(y)),
              ],
              onChanged: (v) => setState(() => year = v!),
              decoration: const InputDecoration(labelText: 'Year'),
            ),
          ],
          if (error != null) Text(error!),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (needsPass) {
                        if (password.text != repeat.text) {
                          throw Exception('Passwords do not match.');
                        }
                        await s.setPassword(password.text);
                      } else {
                        if (name.text.trim().isEmpty) {
                          throw Exception('Enter your name.');
                        }
                        await s.profile({
                          ...s.me,
                          'name': name.text.trim(),
                          'year': year,
                        });
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = e.toString());
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Saving…' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final CampusStore store;
  final PlannerStore planner;
  const HomeShell({super.key, required this.store, required this.planner});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    widget.planner.load(widget.store.scope);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUCKLEY',
            style: TextStyle(
              letterSpacing: 3,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'COMPASS · COMMUNITY',
            style: TextStyle(letterSpacing: 2, fontSize: 9),
          ),
        ],
      ),
      actions: [
        if (widget.store.demo) const Chip(label: Text('DEMO')),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => widget.store.refresh(),
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: 'Profile',
            onPressed: () => go(
              context,
              ProfilePage(store: widget.store, planner: widget.planner),
            ),
            icon: avatar(widget.store.me, radius: 16),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.store.error != null)
          MaterialBanner(
            content: Text(widget.store.error!),
            actions: [
              TextButton(
                onPressed: widget.store.refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [
              FeedPage(store: widget.store),
              ChatsPage(store: widget.store),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => index = 0),
                  icon: Icon(index == 0 ? Icons.home : Icons.home_outlined),
                  label: const Text('Home'),
                ),
                FloatingActionButton.small(
                  heroTag: 'compose',
                  tooltip: 'Create a post',
                  onPressed: () =>
                      go(context, ComposerPage(store: widget.store)),
                  child: const Icon(Icons.add),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => index = 1),
                  icon: Icon(
                    index == 1 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  ),
                  label: const Text('Chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
