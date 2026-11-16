import 'package:flutter/widgets.dart';

import 'compass_remote.dart';

class CompassScope extends InheritedWidget {
  const CompassScope({super.key, required this.remote, required super.child});

  final CompassRemote? remote;

  static CompassRemote? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CompassScope>()?.remote;

  @override
  bool updateShouldNotify(CompassScope oldWidget) => remote != oldWidget.remote;
}
