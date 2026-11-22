import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_ui.dart';
import 'activity_pages.dart';
import 'compass_backdrop.dart';
import 'community_feed.dart';
import 'community_models.dart';
import 'community_profile.dart';
import 'culture_page.dart';
import 'demo_chat_page.dart';
import 'live_calendar_service.dart';
import 'recommendations.dart';
import 'school_calendar_data.dart';
import 'school_demo.dart';
import 'school_arrival_brand.dart';
import 'school_chat_page.dart';
import 'school_pages.dart';
import 'school_people_directory.dart';
import 'firebase/compass_remote.dart';
import 'firebase/compass_scope.dart';

enum _Destination {
  home('Home', CupertinoIcons.house),
  guide('Guide', CupertinoIcons.book),
  chat('Chat', CupertinoIcons.chat_bubble),
  courses('Courses', CupertinoIcons.calendar);

  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class PreviewShell extends StatefulWidget {
  const PreviewShell({
    super.key,
    required this.school,
    required this.onSwitchSchool,
    required this.themeMode,
    required this.onChangeTheme,
    required this.cultureReadIds,
    required this.onToggleCultureRead,
    required this.friendIds,
    required this.onAddFriend,
    required this.preferences,
    required this.onSavePreferences,
    required this.ucInterest,
    required this.onUcInterestChanged,
    required this.completedByRequirement,
    required this.onAdjustRequirementCompleted,
    required this.calendar,
    required this.onSaveCalendar,
    required this.community,
    required this.accountEmail,
    required this.onLogout,
    required this.localPreferences,
    required this.initialSaved,
  });
  final DemoSchool school;
  final VoidCallback onSwitchSchool;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onChangeTheme;
  final Set<String> cultureReadIds, friendIds;
  final Future<void> Function(String) onToggleCultureRead, onAddFriend;
  final StudentPreferences preferences;
  final Future<void> Function(StudentPreferences) onSavePreferences;
  final bool ucInterest;
  final Future<void> Function(bool) onUcInterestChanged;
  final Map<String, int> completedByRequirement;
  final Future<void> Function(DemoCreditRequirement, int)
  onAdjustRequirementCompleted;
  final ImportedSchoolCalendar? calendar;
  final Future<void> Function(ImportedSchoolCalendar?) onSaveCalendar;
  final CommunityController community;
  final String accountEmail;
  final Future<void> Function() onLogout;
  final SharedPreferencesAsync localPreferences;
  final Map<String, Object?> initialSaved;
  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell>
    with SingleTickerProviderStateMixin {
  _Destination _selected = _Destination.home;
  late final _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _arrival.value = 1;
      } else {
        _arrival.forward();
      }
      _remote = CompassScope.maybeOf(context);
      _remote?.notice.addListener(_onSyncNotice);
      _refreshSection(_selected);
    });
  }

  @override
  void dispose() {
    _remote?.notice.removeListener(_onSyncNotice);
    _arrival.dispose();
    super.dispose();
  }

  CompassRemote? _remote;

  void _onSyncNotice() {
    final message = _remote?.notice.value;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(_Destination destination) {
    setState(() => _selected = destination);
    _refreshSection(destination);
  }

  void _refreshSection(_Destination destination) {
    final remote = _remote ?? CompassScope.maybeOf(context);
    if (destination == _Destination.home) {
      unawaited(remote?.refreshPosts());
    }
  }

  Future<void> _openFriends(BuildContext context) {
    final remote = CompassScope.maybeOf(context);
    if (remote != null) {
      return openSchoolPeopleDirectory(
        context,
        schoolName: shortSchoolName(widget.school),
        repository: remote.friends,
        onOpenChat: (context, uid, name) =>
            openSchoolConversation(
              context,
              chat: remote.chat,
              peerId: uid,
              peerName: name,
            ),
      );
    }
    return openSchoolFriendDirectory(
      context,
      school: widget.school,
      friendIds: widget.friendIds,
      onAddFriend: widget.onAddFriend,
      isBlocked: (id) => isBlockedClassmate(widget.community, id),
    );
  }

  void _profile() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CommunityProfilePage(
        c: widget.community,
        email: widget.accountEmail,
        themeMode: widget.themeMode,
        onChangeTheme: widget.onChangeTheme,
        onLogout: widget.onLogout,
        onSwitchSchool: widget.onSwitchSchool,
        cloudBacked: CompassScope.maybeOf(context) != null,
        onOpenFriends: CompassScope.maybeOf(context) == null
            ? null
            : () => _openFriends(context),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.community,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final remote = CompassScope.maybeOf(context);
      final page = switch (_selected) {
        _Destination.home => CommunityFeed(
          community: widget.community,
          preferences: widget.preferences,
          onSavePreferences: widget.onSavePreferences,
          friendIds: widget.friendIds,
          onAddFriend: remote == null ? widget.onAddFriend : null,
          onRefreshPhotos: remote == null
              ? null
              : () => remote.refreshPosts(force: true),
          publishGalleryPost: remote?.publishGalleryPost,
          newcomerSection: _FirstWeek(
            onCalendar: () => _select(_Destination.courses),
            onAdviser: () => openFacultyDirectory(
              context,
              school: widget.school,
              readIds: widget.cultureReadIds,
              onToggleRead: widget.onToggleCultureRead,
            ),
            onClubs: () => openActivityDirectory(
              context,
              school: widget.school,
              community: widget.community,
              friendIds: widget.friendIds,
              onAddFriend: remote == null ? widget.onAddFriend : null,
              clubs: true,
            ),
            onClassmates: () => _openFriends(context),
            sampleClassmates: remote == null,
          ),
        ),
        _Destination.guide => CulturePage(
          school: widget.school,
          readIds: widget.cultureReadIds,
          onToggleRead: widget.onToggleCultureRead,
        ),
        _Destination.chat => remote == null
            ? DemoChatPage(
                community: widget.community,
                school: widget.school,
                friendIds: widget.friendIds,
                onAddFriend: widget.onAddFriend,
              )
            : SchoolChatPage(
                friends: remote.friends,
                chat: remote.chat,
                onAddFriend: () => _openFriends(context),
              ),
        _Destination.courses => DemoAcademicsPage(
          school: widget.school,
          ucInterest: widget.ucInterest,
          completedByRequirement: widget.completedByRequirement,
          calendar: widget.calendar,
          onSaveCalendar: widget.onSaveCalendar,
          onAdjustCompleted: widget.onAdjustRequirementCompleted,
          onUcInterestChanged: widget.onUcInterestChanged,
          promptCalendar:
              widget.initialSaved[calendarPromptKey(
                widget.school.id,
                widget.accountEmail,
              )] !=
              true,
          onCalendarPrompted: () async {
            await widget.localPreferences.setBool(
              calendarPromptKey(widget.school.id, widget.accountEmail),
              true,
            );
            widget.initialSaved[calendarPromptKey(
                  widget.school.id,
                  widget.accountEmail,
                )] =
                true;
          },
        ),
      };
      return LayoutBuilder(
        builder: (context, size) {
          final wide = size.maxWidth >= 820;
          final scaffold = Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leadingWidth: 64,
              leading: IconButton(
                tooltip: 'Personal center',
                onPressed: _profile,
                icon: StudentAvatar(
                  name: widget.community.profile.name,
                  photo: widget.community.profile.avatar,
                  radius: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(color: colors.outlineVariant),
              ),
            ),
            body: SafeArea(
              top: false,
              child: wide
                  ? Row(
                      children: [
                        _DesktopNavigation(
                          selected: _selected,
                          width: size.maxWidth >= 1200 ? 176 : 160,
                          onSelected: _select,
                        ),
                        VerticalDivider(width: 1, color: colors.outlineVariant),
                        Expanded(child: page),
                      ],
                    )
                  : page,
            ),
            bottomNavigationBar: wide
                ? null
                : CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      textTheme: const CupertinoTextThemeData(
                        tabLabelTextStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    child: CupertinoTabBar(
                      currentIndex: _selected.index,
                      onTap: (i) => _select(_Destination.values[i]),
                      activeColor: colors.primary,
                      inactiveColor: colors.onSurfaceVariant,
                      backgroundColor: colors.surface,
                      border: Border(
                        top: BorderSide(color: colors.outlineVariant),
                      ),
                      height: 60,
                      items: [
                        for (final d in _Destination.values)
                          BottomNavigationBarItem(
                            icon: Icon(d.icon, size: 23),
                            label: d.label,
                          ),
                      ],
                    ),
                  ),
          );
          return AnimatedBuilder(
            animation: _arrival,
            child: scaffold,
            builder: (context, child) {
              final phase = MediaQuery.disableAnimationsOf(context)
                  ? 1.0
                  : _arrival.value;
              final contentOpacity = Curves.easeOutCubic.transform(
                ((phase - .70) / .26).clamp(0.0, 1.0),
              );
              // Keep the same brand elements mounted through the last frame.
              // Only the page behind them fades in; no header replacement.
              return ColoredBox(
                color: colors.surface,
                child: CompassBackdrop.school(
                  schoolColor: widget.school.brandColor,
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: phase < 1,
                        child: ExcludeSemantics(
                          excluding: phase < 1,
                          child: child!,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: colors.surface.withValues(
                              alpha: 1 - contentOpacity,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: SchoolArrivalBrand(
                            school: widget.school,
                            phase: phase,
                            toolbarCenterY:
                                MediaQuery.paddingOf(context).top +
                                kToolbarHeight / 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _FirstWeek extends StatelessWidget {
  const _FirstWeek({
    required this.onCalendar,
    required this.onAdviser,
    required this.onClubs,
    required this.onClassmates,
    required this.sampleClassmates,
  });

  final VoidCallback onCalendar, onAdviser, onClubs, onClassmates;
  final bool sampleClassmates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const PageStorageKey('first-week'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.explore_outlined),
          title: Text('First week', style: theme.textTheme.titleMedium),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final action in [
              (
                icon: Icons.event_outlined,
                label: 'Check the school calendar',
                open: onCalendar,
              ),
              (
                icon: Icons.door_front_door_outlined,
                label: 'Find an adviser or classroom',
                open: onAdviser,
              ),
              (
                icon: Icons.groups_outlined,
                label: 'Find a club',
                open: onClubs,
              ),
              (
                icon: Icons.person_add_alt_outlined,
                label: sampleClassmates
                    ? 'Meet sample classmates'
                    : 'Connect with school members',
                open: onClassmates,
              ),
            ])
              ListTile(
                leading: Icon(action.icon, size: 20),
                title: Text(action.label),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: action.open,
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selected,
    required this.width,
    required this.onSelected,
  });
  final _Destination selected;
  final double width;
  final ValueChanged<_Destination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('desktop-navigation'),
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            for (final destination in _Destination.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Semantics(
                  selected: destination == selected,
                  child: Material(
                    color: destination == selected
                        ? colors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onSelected(destination),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 52,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                destination.icon,
                                size: 22,
                                color: destination == selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  destination.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        color: destination == selected
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
