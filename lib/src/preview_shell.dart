import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_ui.dart';
import 'community_feed.dart';
import 'community_models.dart';
import 'community_profile.dart';
import 'culture_page.dart';
import 'demo_chat_page.dart';
import 'live_calendar_service.dart';
import 'recommendations.dart';
import 'school_calendar_data.dart';
import 'school_demo.dart';
import 'school_pages.dart';

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
    });
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
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
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.community,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final page = switch (_selected) {
        _Destination.home => CommunityFeed(
          community: widget.community,
          preferences: widget.preferences,
          onSavePreferences: widget.onSavePreferences,
        ),
        _Destination.guide => CulturePage(
          school: widget.school,
          readIds: widget.cultureReadIds,
          onToggleRead: widget.onToggleCultureRead,
        ),
        _Destination.chat => DemoChatPage(
          community: widget.community,
          school: widget.school,
          friendIds: widget.friendIds,
          onAddFriend: widget.onAddFriend,
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
            appBar: AppBar(
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
              centerTitle: true,
              title: SizedBox(
                width: wide ? 320 : 270,
                child: SchoolBrand(school: widget.school, fontSize: 15),
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
                        NavigationRail(
                          backgroundColor: colors.surface,
                          minWidth: 96,
                          minExtendedWidth: 160,
                          extended: size.maxWidth >= 1200,
                          selectedIndex: _selected.index,
                          onDestinationSelected: (i) => setState(
                            () => _selected = _Destination.values[i],
                          ),
                          destinations: [
                            for (final d in _Destination.values)
                              NavigationRailDestination(
                                icon: Icon(d.icon, size: 22),
                                label: Text(d.label),
                              ),
                          ],
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
                      onTap: (i) =>
                          setState(() => _selected = _Destination.values[i]),
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
              final phase = _arrival.value;
              if (phase >= 1) return child!;
              final move = Curves.easeInOutCubic.transform(
                ((phase - .40) / .53).clamp(0.0, 1.0),
              );
              final fade = Curves.easeOut.transform(
                ((phase - .77) / .23).clamp(0.0, 1.0),
              );
              final compassOpacity = (phase / .24).clamp(0.0, 1.0);
              final schoolOpacity = ((phase - .20) / .24).clamp(0.0, 1.0);
              return Stack(
                children: [
                  child!,
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: colors.surface.withValues(alpha: 1 - fade),
                        child: Stack(
                          children: [
                            Positioned(
                              left: lerpDouble(
                                size.maxWidth / 2 - 78,
                                size.maxWidth / 2 - 125,
                                move,
                              ),
                              top: lerpDouble(size.maxHeight * .37, 16, move),
                              child: Opacity(
                                opacity: compassOpacity * (1 - fade),
                                child: CompassWordmark(
                                  size: lerpDouble(26, 15, move)!,
                                ),
                              ),
                            ),
                            Positioned(
                              left: lerpDouble(
                                size.maxWidth / 2 - 64,
                                size.maxWidth / 2 + 4,
                                move,
                              ),
                              top: lerpDouble(
                                size.maxHeight * .37 + 72,
                                18,
                                move,
                              ),
                              child: Opacity(
                                opacity: schoolOpacity * (1 - fade),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SchoolMark(
                                      school: widget.school,
                                      size: lerpDouble(38, 21, move)!,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shortSchoolName(widget.school),
                                      style: TextStyle(
                                        fontSize: lerpDouble(20, 15, move),
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
