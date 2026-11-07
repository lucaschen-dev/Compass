import 'dart:math' as math;

import 'package:flutter/material.dart';

class CompassWelcome extends StatelessWidget {
  const CompassWelcome({
    super.key,
    required this.onFindSchool,
    required this.appearanceAction,
  });

  final VoidCallback onFindSchool;
  final Widget appearanceAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _WelcomePalette(theme.brightness);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          surface: palette.background,
          onSurface: palette.ink,
          primary: palette.accent,
          onPrimary: palette.buttonInk,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: palette.ink,
            minimumSize: const Size(48, 48),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: palette.background,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.6, -0.1),
              radius: 1.4,
              colors: [palette.highlight, palette.background],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final wide = viewport.maxWidth >= 1000;
                final gutter = wide
                    ? math.max(56.0, (viewport.maxWidth - 1335) / 2)
                    : viewport.maxWidth >= 600
                    ? 48.0
                    : 24.0;
                final contentWidth = viewport.maxWidth - gutter * 2;
                final headerHeight = wide ? 144.0 : 88.0;
                final headingSize = wide
                    ? (contentWidth * 0.066).clamp(54.0, 88.0)
                    : (contentWidth * 0.115).clamp(34.0, 56.0);
                final copy = _WelcomeCopy(
                  palette: palette,
                  wide: wide,
                  headingSize: headingSize,
                  onFindSchool: onFindSchool,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WelcomeHeader(
                            palette: palette,
                            wide: wide,
                            height: headerHeight,
                            appearanceAction: appearanceAction,
                          ),
                          if (wide)
                            SizedBox(
                              height: math.max(
                                620.0,
                                viewport.maxHeight - headerHeight,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    right: -gutter * 0.9,
                                    top: 20,
                                    bottom: 20,
                                    width: contentWidth * 0.64,
                                    child: const _CampusArtwork(),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 40,
                                      ),
                                      child: SizedBox(
                                        width: contentWidth * 0.49,
                                        child: copy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 36,
                                bottom: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  copy,
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: (contentWidth * 0.7).clamp(
                                      210.0,
                                      380.0,
                                    ),
                                    child: const _CampusArtwork(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePalette {
  _WelcomePalette(Brightness brightness) : dark = brightness == Brightness.dark;

  final bool dark;
  Color get background =>
      dark ? const Color(0xff0d1625) : const Color(0xfff5f7fb);
  Color get highlight => dark ? const Color(0xff111d31) : Colors.white;
  Color get ink => dark ? const Color(0xfff6f2e9) : const Color(0xff14223a);
  Color get rule => dark ? const Color(0xff3a4659) : const Color(0xffd9e0e9);
  Color get accent => const Color(0xfffa946f);
  Color get buttonInk => const Color(0xff14223a);
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.palette,
    required this.wide,
    required this.height,
    required this.appearanceAction,
  });

  final _WelcomePalette palette;
  final bool wide;
  final double height;
  final Widget appearanceAction;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: palette.rule)),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(wide ? 15 : 10),
          child: Image.asset(
            'assets/branding/compass-icon.png',
            width: wide ? 64 : 36,
            height: wide ? 64 : 36,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(width: wide ? 18 : 12),
        Text(
          'Compass',
          style: TextStyle(
            color: palette.ink,
            fontSize: wide ? 42 : 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const Spacer(),
        appearanceAction,
      ],
    ),
  );
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({
    required this.palette,
    required this.wide,
    required this.headingSize,
    required this.onFindSchool,
  });

  final _WelcomePalette palette;
  final bool wide;
  final double headingSize;
  final VoidCallback onFindSchool;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Find your people.\nFind your place.',
          style: TextStyle(
            color: palette.ink,
            fontSize: headingSize,
            fontWeight: FontWeight.w700,
            letterSpacing: wide ? -2.8 : -1.6,
            height: 1.16,
          ),
        ),
      ),
      SizedBox(height: wide ? 40 : 28),
      SizedBox(
        width: wide ? 386 : double.infinity,
        height: wide ? 80 : 58,
        child: FilledButton(
          onPressed: onFindSchool,
          style: FilledButton.styleFrom(
            backgroundColor: palette.accent,
            foregroundColor: palette.buttonInk,
            padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(wide ? 18 : 16),
            ),
            textStyle: TextStyle(
              fontSize: wide ? 26 : 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Find your school'),
              Icon(Icons.arrow_forward_rounded, size: wide ? 32 : 23),
            ],
          ),
        ),
      ),
    ],
  );
}

class _CampusArtwork extends StatelessWidget {
  const _CampusArtwork();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/campus-welcome.png',
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );
}
