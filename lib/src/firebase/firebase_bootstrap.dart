import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'firebase_test_env.dart';

class FirebaseBootstrap {
  static bool isReady = false;

  static Future<void> initialize() async {
    if (isFlutterTest || Firebase.apps.isNotEmpty) {
      isReady = Firebase.apps.isNotEmpty;
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isReady = true;
    } catch (error, stack) {
      debugPrint('Firebase did not start: $error\n$stack');
    }
  }
}
