// App entry.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught: $error\n$stack');
    }
    return true;
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return const ColoredBox(
      color: Color(0xFFF4F5F7),
      child: Center(
        child: Icon(Icons.warning_amber_rounded, size: 40, color: Color(0xFF8B919A)),
      ),
    );
  };

  await runZonedGuarded(() async {
    try {
      await bootstrap();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Bootstrap failed: $e\n$st');
      }
    }
    runApp(const AccountantApp());
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('Zone error: $error\n$stack');
    }
  });
}
