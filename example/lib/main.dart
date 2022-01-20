import 'dart:io';

import 'package:automated_testing_framework/automated_testing_framework.dart';
import 'package:automated_testing_framework_example/automated_testing_framework_example.dart';
import 'package:automated_testing_framework_plugin_github/automated_testing_framework_plugin_github.dart';
import 'package:automated_testing_framework_plugin_images/automated_testing_framework_plugin_images.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('${record.stackTrace}');
    }
  });

  WidgetsFlutterBinding.ensureInitialized();

  TestImagesHelper.registerTestSteps();

  GitHub? github;
  String? token;
  try {
    token = (await rootBundle.loadString('assets/secrets/token.txt')).trim();

    github = GitHub(auth: Authentication.withToken(token));
  } catch (e) {
    // no-op; use default auth
  }
  github ??= GitHub();

  var gestures = TestableGestures();
  if (kIsWeb ||
      Platform.isFuchsia ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows) {
    gestures = TestableGestures(
      widgetLongPress: null,
      widgetSecondaryLongPress: TestableGestureAction.open_test_actions_page,
      widgetSecondaryTap: TestableGestureAction.open_test_actions_dialog,
    );
  }

  var store = GithubTestStore(
    branch: 'tests',
    github: github,
    slug: RepositorySlug(
      'peiffer-innovations',
      'automated_testing_framework_plugin_github',
    ),
  );

  runApp(App(
    options: TestExampleOptions(
      autorun: kProfileMode,
      enabled: true,
      gestures: gestures,
      goldenImageWriter: store.goldenImageWriter,
      testImageReader: store.testImageReader,
      testReader: store.testReader,
      testWidgetsEnabled: true,
      testWriter: store.testWriter,
    ),
  ));
}
