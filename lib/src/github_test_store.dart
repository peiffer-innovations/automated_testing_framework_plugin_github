import 'package:automated_testing_framework/automated_testing_framework.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class GithubTestStore {
  GithubTestStore({
    this.branch = 'main',
    this.testsPath,
  });

  static final Logger _logger = Logger('GithubTestStore');

  final String branch;

  /// Optional path to store tests.  If omitted, this defaults to 'tests'.
  /// Provided to allow for a single GitHub repo the ability to host multiple
  /// applications or environments.
  final String? testsPath;

  /// Implementation of the [TestReader] functional interface that can read test
  /// data from GitHub.
  Future<List<PendingTest>> testReader(
    BuildContext? context, {
    String? suiteName,
  }) async {
    List<PendingTest>? results;

    try {
      results = [];
      // var actualTestsPath = (testsPath ?? 'tests');

      // ...
    } catch (e, stack) {
      _logger.severe('Error loading tests', e, stack);
    }

    return results ?? <PendingTest>[];
  }

  /// Implementation of the [TestWriter] functional interface that can submit
  /// test data to GitHub.
  Future<bool> testWriter(
    BuildContext context,
    Test test,
  ) async {
    var result = false;

    try {
      // var actualTestsPath = (testsPath ?? 'tests');

      // ...

      result = true;
    } catch (e, stack) {
      _logger.severe('Error writing test', e, stack);
    }
    return result;
  }
}
