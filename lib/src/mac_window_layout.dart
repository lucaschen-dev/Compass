import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

final _titleBarInset = const EventChannel('compass/macos_title_bar_inset')
    .receiveBroadcastStream()
    .map((value) => (value as num).toDouble())
    .distinct();

Widget macWindowLayout(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  return StreamBuilder<double>(
    stream: _titleBarInset,
    initialData: 34,
    builder: (context, snapshot) {
      final top = snapshot.data ?? 34;
      return MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(
            top: math.max(media.padding.top, top),
          ),
          viewPadding: media.viewPadding.copyWith(
            top: math.max(media.viewPadding.top, top),
          ),
        ),
        child: child!,
      );
    },
  );
}
