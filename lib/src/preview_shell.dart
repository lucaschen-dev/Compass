import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'culture_page.dart';
import 'demo_chat_page.dart';
import 'school_demo.dart';
import 'school_pages.dart';

enum _Destination {
  home('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
  culture('Guide', CupertinoIcons.list_bullet, CupertinoIcons.list_bullet),
  chat(
    'Chat',
    CupertinoIcons.bubble_left_bubble_right,
    CupertinoIcons.bubble_left_bubble_right_fill,
  ),
  academics('Courses', CupertinoIcons.calendar, CupertinoIcons.calendar);

  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
    required this.ucInterest,
    required this.onUcInterestChanged,
    required this.completedByRequirement,
    required this.onAdjustRequirementCompleted,
  });

  final DemoSchool school;
  final VoidCallback onSwitchSchool;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeTheme;
  final Set<String> cultureReadIds;
  final Future<void> Function(String) onToggleCultureRead;
  final Set<String> friendIds;
  final Future<void> Function(String) onAddFriend;
  final bool ucInterest;
  final Future<void> Function(bool value) onUcInterestChanged;
  final Map<String, int> completedByRequirement;
  final Future<void> Function(DemoCreditRequirement requirement, int next)
  onAdjustRequirementCompleted;

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  var _selected = _Destination.home;

  void _select(_Destination destination) {
    setState(() => _selected = destination);
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            top: false,
            child: DemoProfilePage(
              school: widget.school,
              ucInterest: widget.ucInterest,
              onUcInterestChanged: (value) => _save(
                () => widget.onUcInterestChanged(value),
                'Could not save UC interest. Try again.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final school = widget.school;
    final page = switch (_selected) {
      _Destination.home => DemoHomePage(school: school),
      _Destination.academics => DemoAcademicsPage(
        school: school,
        ucInterest: widget.ucInterest,
        completedByRequirement: widget.completedByRequirement,
        onAdjustCompleted: (requirement, next) => _save(
          () => widget.onAdjustRequirementCompleted(requirement, next),
          'Could not save requirement progress. Try again.',
        ),
      ),
      _Destination.culture => CulturePage(
        school: school,
        readIds: widget.cultureReadIds,
        onToggleRead: (id) => _save(
          () => widget.onToggleCultureRead(id),
          'Could not save reading progress. Try again.',
        ),
      ),
      _Destination.chat => DemoChatPage(
        school: school,
        friendIds: widget.friendIds,
        onAddFriend: (id) => _save(
          () => widget.onAddFriend(id),
          'Could not add this friend. Try again.',
        ),
      ),
    };

    // https://docs.flutter.dev/ui/adaptive-responsive/general#step-3-branch
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final extended = constraints.maxWidth >= 900;
        final floatOverFeed = !wide && _selected == _Destination.home;
        return Scaffold(
          // Home adds the dock inset to its scrollable content padding.
          // https://api.flutter.dev/flutter/material/Scaffold/extendBody.html
          extendBody: floatOverFeed,
          appBar: AppBar(
            toolbarHeight: 52,
            leadingWidth: 65,
            leading: Center(
              child: IconButton(
                tooltip: 'Profile',
                onPressed: _openProfile,
                icon: const Icon(CupertinoIcons.person_crop_circle, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface.withValues(alpha: .78),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .55),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 15),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.surface.withValues(alpha: .78),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .55),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Switch school',
                        onPressed: widget.onSwitchSchool,
                        icon: const Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          size: 20,
                        ),
                      ),
                      PopupMenuButton<ThemeMode>(
                        tooltip: 'Appearance',
                        icon: const Icon(CupertinoIcons.ellipsis, size: 20),
                        onSelected: widget.onChangeTheme,
                        itemBuilder: (_) => [
                          for (final mode in ThemeMode.values)
                            CheckedPopupMenuItem(
                              value: mode,
                              checked: widget.themeMode == mode,
                              child: Text(switch (mode) {
                                ThemeMode.system => 'System appearance',
                                ThemeMode.light => 'Light mode',
                                ThemeMode.dark => 'Dark mode',
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: !floatOverFeed,
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        minExtendedWidth: 192,
                        extended: extended,
                        labelType: extended
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        backgroundColor: colors.surface,
                        leading: const SizedBox(height: 12),
                        scrollable: true,
                        selectedIndex: _selected.index,
                        onDestinationSelected: (index) =>
                            _select(_Destination.values[index]),
                        destinations: [
                          for (final destination in _Destination.values)
                            NavigationRailDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: Text(destination.label),
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
              : _PreviewDock(selected: _selected, onSelected: _select),
        );
      },
    );
  }
}

class _PreviewDock extends StatelessWidget {
  const _PreviewDock({required this.selected, required this.onSelected});

  final _Destination selected;
  final ValueChanged<_Destination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(32);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(19, 4, 19, 12),
      child: ClipRRect(
        borderRadius: radius,
        // Keep the blur clipped to the dock's shape.
        // https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.outlineVariant),
            ),
            color: colors.surface.withValues(alpha: .82),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Semantics(
                role: SemanticsRole.tabBar,
                child: Row(
                  children: [
                    for (final destination in _Destination.values)
                      Expanded(
                        child: Semantics(
                          role: SemanticsRole.tab,
                          selected: destination == selected,
                          child: Ink(
                            decoration: ShapeDecoration(
                              color: destination == selected
                                  ? colors.onSurface.withValues(alpha: .1)
                                  : Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => onSelected(destination),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      destination == selected
                                          ? destination.selectedIcon
                                          : destination.icon,
                                      size: 23,
                                      color: colors.onSurface,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      destination.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: destination == selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
    );
  }
}
