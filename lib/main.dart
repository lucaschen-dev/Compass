import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:media_kit/media_kit.dart';

import 'src/store.dart';
import 'src/planner.dart';
import 'src/ui.dart';
import 'src/native_bridge.dart';

import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final prefs = await SharedPreferences.getInstance();
  final store = CampusStore(prefs);
  final planner = PlannerStore(prefs);
  final apple =
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  if (apple && !const bool.fromEnvironment('FLUTTER_UI')) {
    runApp(const SizedBox.shrink());
    await NativeBridge(store, planner).start();
  } else {
    MediaKit.ensureInitialized();
    runApp(CompassApp(store: store, planner: planner));
    await store.restore();
  }
}
