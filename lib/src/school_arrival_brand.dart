import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'school_demo.dart';

/// One persistent set of marks moves from the introduction into the toolbar.
/// Child sizes, rather than guessed text offsets, determine their final positions.
class SchoolArrivalBrand extends StatelessWidget {
  const SchoolArrivalBrand({
    super.key,
    required this.school,
    required this.phase,
    required this.toolbarCenterY,
  });

  final DemoSchool school;
  final double phase;
  final double toolbarCenterY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = Curves.easeInOutCubic.transform(
      ((phase - .36) / .58).clamp(0.0, 1.0),
    );
    final compassOpacity = Curves.easeOut.transform(
      (phase / .18).clamp(0.0, 1.0),
    );
    final schoolOpacity = Curves.easeOut.transform(
      ((phase - .16) / .18).clamp(0.0, 1.0),
    );
    final schoolFontSize = lerpDouble(20, 15, move)!;
    return Semantics(
      header: true,
      container: true,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.3,
        ),
        child: CustomMultiChildLayout(
          delegate: _BrandLayout(move: move, toolbarCenterY: toolbarCenterY),
          children: [
            LayoutId(
              id: _BrandPart.compass,
              child: Opacity(
                opacity: compassOpacity,
                child: CompassWordmark(size: lerpDouble(26, 15, move)!),
              ),
            ),
            LayoutId(
              id: _BrandPart.separator,
              child: Opacity(
                opacity: ((move - .70) / .30).clamp(0.0, 1.0),
                child: Text(
                  '×',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _BrandPart.school,
              child: Opacity(
                opacity: schoolOpacity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SchoolMark(school: school, size: lerpDouble(32, 21, move)!),
                    const SizedBox(width: 6),
                    Text(
                      shortSchoolName(school),
                      style: TextStyle(
                        fontSize: schoolFontSize,
                        fontWeight: FontWeight.w400,
                        fontVariations: const [FontVariation('wght', 350)],
                        letterSpacing: -.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BrandPart { compass, separator, school }

class _BrandLayout extends MultiChildLayoutDelegate {
  _BrandLayout({required this.move, required this.toolbarCenterY});
  final double move;
  final double toolbarCenterY;

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(size);
    final compass = layoutChild(_BrandPart.compass, constraints);
    final separator = layoutChild(_BrandPart.separator, constraints);
    final school = layoutChild(_BrandPart.school, constraints);
    const gap = 8.0;
    final rowWidth = compass.width + school.width + separator.width + gap * 2;
    final rowLeft = (size.width - rowWidth) / 2;
    final introCenterY = size.height * .37;
    positionChild(
      _BrandPart.compass,
      Offset(
        lerpDouble((size.width - compass.width) / 2, rowLeft, move)!,
        lerpDouble(introCenterY, toolbarCenterY, move)! - compass.height / 2,
      ),
    );
    positionChild(
      _BrandPart.separator,
      Offset(
        lerpDouble(
          (size.width - separator.width) / 2,
          rowLeft + compass.width + gap,
          move,
        )!,
        lerpDouble(introCenterY + 36, toolbarCenterY, move)! -
            separator.height / 2,
      ),
    );
    positionChild(
      _BrandPart.school,
      Offset(
        lerpDouble(
          (size.width - school.width) / 2,
          rowLeft + compass.width + separator.width + gap * 2,
          move,
        )!,
        lerpDouble(introCenterY + 72, toolbarCenterY, move)! -
            school.height / 2,
      ),
    );
  }

  @override
  bool shouldRelayout(_BrandLayout oldDelegate) =>
      move != oldDelegate.move || toolbarCenterY != oldDelegate.toolbarCenterY;
}
