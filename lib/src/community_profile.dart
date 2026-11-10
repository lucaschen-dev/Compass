import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'community_feed.dart';
import 'community_models.dart';
import 'school_demo.dart';

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.c,
    required this.email,
    required this.themeMode,
    required this.onChangeTheme,
    required this.onLogout,
    required this.onSwitchSchool,
  });
  final CommunityController c;
  final String email;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onChangeTheme;
  final Future<void> Function() onLogout;
  final VoidCallback onSwitchSchool;
  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  int _tab = 0;
  Future<void> _photo() async {
    try {
      final photo = await choosePhoto(avatar: true);
      if (photo != null) {
        await widget.c.change(
          () => widget.c.profile = CommunityProfile(
            name: widget.c.profile.name,
            grade: widget.c.profile.grade,
            bio: widget.c.profile.bio,
            avatar: photo,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppError(
          context,
          e is ArgumentError
              ? e.message.toString()
              : 'Could not update the photo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) {
      final p = widget.c.profile;
      final posts = widget.c.posts.where(
        (p) =>
            _tab == 0 ? p.authorId == 'me' : widget.c.savedPosts.contains(p.id),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ContentColumn(
          maxWidth: 700,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  StudentAvatar(name: p.name, photo: p.avatar, radius: 52),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Change profile photo',
                      onPressed: _photo,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              p.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Grade ${p.grade}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.bio, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => _EditProfile(c: widget.c),
                ),
                child: const Text('Edit profile'),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _tab == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              width: _tab == i ? 2 : 1,
                            ),
                          ),
                        ),
                        child: Text(
                          ['Posts', 'Saved', 'About'][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: _tab == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tab == 2) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('School'),
                subtitle: Text(widget.c.school.name),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Email'),
                subtitle: Text(widget.email),
              ),
              if (p.bio.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('About'),
                  subtitle: Text(p.bio),
                ),
            ] else if (posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  _tab == 0
                      ? 'Your posts will appear here.'
                      : 'No saved posts yet.',
                ),
              )
            else
              for (final post in posts)
                PostTile(community: widget.c, post: post),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _SettingsPage(
                    school: widget.c.school,
                    email: widget.email,
                    mode: widget.themeMode,
                    onChangeTheme: widget.onChangeTheme,
                    onLogout: widget.onLogout,
                    onSwitchSchool: widget.onSwitchSchool,
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
        ),
      );
    },
  );
}

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.c});
  final CommunityController c;
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _name = TextEditingController(text: widget.c.profile.name),
      _bio = TextEditingController(text: widget.c.profile.bio);
  late int _grade = widget.c.profile.grade;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration: const InputDecoration(labelText: 'Grade'),
            items: [
              for (var g = 9; g <= 12; g++)
                DropdownMenuItem(value: g, child: Text('Grade $g')),
            ],
            onChanged: (g) => setState(() => _grade = g!),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_name.text.trim().length < 2) {
                      showAppError(context, 'Enter your full name.');
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await widget.c.change(
                        () => widget.c.profile = CommunityProfile(
                          name: _name.text.trim(),
                          grade: _grade,
                          bio: _bio.text.trim(),
                          avatar: widget.c.profile.avatar,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (mounted && context.mounted) {
                        showAppError(context, 'Could not save your profile.');
                        setState(() => _busy = false);
                      }
                    }
                  },
            child: const Text('Save profile'),
          ),
        ],
      ),
    ),
  );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.school,
    required this.email,
    required this.mode,
    required this.onChangeTheme,
    required this.onLogout,
    required this.onSwitchSchool,
  });
  final DemoSchool school;
  final String email;
  final ThemeMode mode;
  final Future<void> Function(ThemeMode) onChangeTheme;
  final Future<void> Function() onLogout;
  final VoidCallback onSwitchSchool;
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late ThemeMode _mode = widget.mode;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ContentColumn(
      maxWidth: 600,
      children: [
        const SizedBox(height: 18),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 18),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: _busy
              ? null
              : (v) async {
                  setState(() => _busy = true);
                  try {
                    await widget.onChangeTheme(v.first);
                    if (mounted) setState(() => _mode = v.first);
                  } catch (_) {
                    if (context.mounted) {
                      showAppError(context, 'Could not save appearance.');
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
        const SizedBox(height: 36),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          leading: const Icon(Icons.school_outlined),
          title: Text(shortSchoolName(widget.school)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.popUntil(context, (r) => r.isFirst);
            widget.onSwitchSchool();
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          leading: const Icon(Icons.person_outline),
          title: const Text('Account'),
          subtitle: Text(widget.email),
        ),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          leading: const Icon(Icons.lock_outline),
          title: const Text('Privacy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Local demo'),
              content: const Text(
                'Your profile, posts, and messages are saved on this device. This demo does not verify school membership or send messages to other people.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        const SizedBox(height: 28),
        TextButton(
          onPressed: () async {
            try {
              await widget.onLogout();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            } catch (_) {
              if (context.mounted) {
                showAppError(context, 'Could not log out. Please try again.');
              }
            }
          },
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('Log out'),
          ),
        ),
      ],
    ),
  );
}
