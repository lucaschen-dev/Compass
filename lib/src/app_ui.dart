import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'school_demo.dart';

String shortSchoolName(DemoSchool school) =>
    school.name.replaceAll(' High School', '');

class CompassMark extends StatelessWidget {
  const CompassMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Compass logo',
    child: CustomPaint(
      size: Size.square(size),
      painter: _CompassPainter(Theme.of(context).colorScheme.onSurface),
    ),
  );
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .042
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(unit * .5, unit * .5), unit * .42, paint);
    canvas.drawPath(
      Path()
        ..moveTo(unit * .69, unit * .28)
        ..lineTo(unit * .56, unit * .56)
        ..lineTo(unit * .31, unit * .72)
        ..lineTo(unit * .44, unit * .44)
        ..close(),
      paint,
    );
    canvas.drawLine(
      Offset(unit * .44, unit * .44),
      Offset(unit * .56, unit * .56),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) => oldDelegate.color != color;
}

class CompassWordmark extends StatelessWidget {
  const CompassWordmark({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CompassMark(size: size * 1.25),
      SizedBox(width: size * .20),
      Text(
        'Compass',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w400,
          fontVariations: const [FontVariation('wght', 350)],
          letterSpacing: -size * .035,
        ),
      ),
    ],
  );
}

class SchoolMark extends StatelessWidget {
  const SchoolMark({super.key, required this.school, this.size = 30});
  final DemoSchool school;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${school.name} logo',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(
        school.id == 'alderline' ? Icons.forest_outlined : Icons.water_outlined,
        size: size * .68,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class SchoolBrand extends StatelessWidget {
  const SchoolBrand({super.key, required this.school, this.fontSize = 17});
  final DemoSchool school;
  final double fontSize;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompassWordmark(size: fontSize),
        const SizedBox(width: 8),
        Text(
          '×',
          style: TextStyle(
            fontSize: fontSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        SchoolMark(school: school, size: fontSize * 1.4),
        const SizedBox(width: 6),
        Text(
          shortSchoolName(school),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            letterSpacing: -.6,
          ),
        ),
      ],
    ),
  );
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.photo,
    this.radius = 22,
  });
  final String name;
  final String? photo;
  final double radius;
  @override
  Widget build(BuildContext context) {
    Uint8List? data;
    try {
      if (photo != null) data = base64Decode(photo!);
    } catch (_) {}
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      foregroundImage: data == null ? null : MemoryImage(data),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          fontVariations: const [FontVariation('wght', 350)],
          fontSize: radius * .7,
        ),
      ),
    );
  }
}

class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.children,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 32),
  });
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

void showAppError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error is String ? error : 'Could not save. Please try again.',
      ),
    ),
  );
}

Future<void> appSave(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      showAppError(
        context,
        error is ArgumentError
            ? error.message.toString()
            : 'Could not save. Please try again.',
      );
    }
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> choosePhoto({bool avatar = false}) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Image',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 8 * 1024 * 1024) {
    throw ArgumentError('Choose an image smaller than 8 MB.');
  }
  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: avatar ? 320 : 960,
    allowUpscaling: false,
  );
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (bytes == null || bytes.lengthInBytes > (avatar ? 700000 : 1400000)) {
    throw ArgumentError('Choose a smaller image.');
  }
  return base64Encode(bytes.buffer.asUint8List());
}

String relativeTime(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'Now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} hr';
  return '${at.month}/${at.day}';
}
