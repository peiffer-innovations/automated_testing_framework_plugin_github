import 'dart:convert';
import 'dart:typed_data';

import 'package:automated_testing_framework_models/automated_testing_framework_models.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';
import 'package:pointycastle/pointycastle.dart';

class GithubTestStore {
  GithubTestStore({
    this.branch = 'main',
    String committerEmail = 'noop@github.com',
    String committerName = 'ATF GH Plugin',
    required GitHub github,
    this.goldenImagesPath = 'goldens',
    required this.slug,
    this.testsPath = 'tests',
  })  :
        // Double encode to turn it fully into an escaped JSON encoded string
        _committer = {
          'email': committerEmail,
          'name': committerName,
        },
        _github = github;

  static final Logger _logger = Logger('GithubTestStore');

  final String branch;

  final String goldenImagesPath;

  final RepositorySlug slug;

  /// Optional path to store tests.
  final String testsPath;

  final Map<String, dynamic> _committer;
  final GitHub _github;

  /// Cached value that will be refreshed as needed.
  GoldenTestImages? _currentGoldenTestImages;
  bool _dirty = true;
  late GitTree _tree;

  static String _createGoldenImageId({
    required TestDeviceInfo deviceInfo,
    String? suiteName,
    required String testName,
  }) {
    final suitePrefix = suiteName?.isNotEmpty == true
        ? '${suiteName!.replaceAll('/', '-')}/'
        : '';
    return '${deviceInfo.appIdentifier}/${suitePrefix}${testName.replaceAll('/', '-')}/${deviceInfo.os}/${deviceInfo.systemVersion}/${deviceInfo.model}/${deviceInfo.device}/${deviceInfo.orientation}/${deviceInfo.pixels?.height}x${deviceInfo.pixels?.width}';
  }

  static String _createGoldenImageIdFromReport(TestReport report) {
    final suiteName = report.suiteName;
    final testName = report.name;
    final deviceInfo = report.deviceInfo;

    return _createGoldenImageId(
      deviceInfo: deviceInfo ?? TestDeviceInfo.unknown(),
      suiteName: suiteName,
      testName: testName ?? 'unknown',
    );
  }

  /// Writes the golden images from the [report] to Cloud Storage and also
  /// writes the metadata that allows the reading of the golden images.  This
  /// will throw an exception on failure.
  Future<void> goldenImageWriter(TestReport report) async {
    await _loadData();
    final actualPath = goldenImagesPath.startsWith('/')
        ? goldenImagesPath.substring(1)
        : goldenImagesPath;

    final goldenId = _createGoldenImageIdFromReport(report);

    final data = <String, String>{};
    for (var image in report.images) {
      if (image.goldenCompatible == true) {
        data[image.id] = image.hash;
      }
    }
    final golden = GoldenTestImages(
      deviceInfo: report.deviceInfo!,
      goldenHashes: data,
      suiteName: report.suiteName,
      testName: report.name!,
      testVersion: report.version,
    );

    const batchSize = 10;
    final batch = <Future>[];

    final hashes = <String>{};

    final images = List.from(report.images);

    images.removeWhere((image) {
      var found = false;

      for (var e in _tree.entries!) {
        if (e.path == '$actualPath/$goldenId/${image.hash}.png') {
          found = true;
          break;
        }
      }

      return !found;
    });

    for (var image in report.images) {
      if (image.goldenCompatible) {
        if (!hashes.contains(image.hash)) {
          hashes.add(image.hash);
          final path = '$actualPath/$goldenId/${image.hash}.png';
          final entry = _tree.entries!.where((e) => e.path == path);

          if (entry.isNotEmpty) {
            final first = entry.first;
            final hash1 = hex.encode(Digest('SHA-1').process(image.image!));

            if (first.sha == hash1) {
              // Contents are the same, don't bother updating it.
              continue;
            }
          }

          batch.add(uploadFile(
            data: image.image!,
            message: 'Golden Image Update',
            path: path,
          ));

          if (batch.length >= batchSize) {
            await Future.wait(batch);
            batch.clear();
          }
        }
      }
    }

    batch.add(uploadFile(
      data: utf8.encode(golden.toString()),
      message: 'Golden Image Update',
      path: '$actualPath/$goldenId.json',
    ));

    await Future.wait(batch);
    batch.clear();

    _dirty = true;
  }

  /// Reader to read a golden image from GitHub.
  Future<Uint8List?> testImageReader({
    required TestDeviceInfo deviceInfo,
    required String imageId,
    String? suiteName,
    required String testName,
    int? testVersion,
  }) async {
    await _loadData();
    final goldenId = GoldenTestImages.createId(
      deviceInfo: deviceInfo,
      suiteName: suiteName,
      testName: testName,
    );
    final actualPath = goldenImagesPath.startsWith('/')
        ? goldenImagesPath.substring(1)
        : goldenImagesPath;
    GoldenTestImages? golden;
    if (_currentGoldenTestImages?.id == goldenId) {
      golden = _currentGoldenTestImages;
    } else {
      final name = '$actualPath/$goldenId.json';
      final entry = _tree.entries!.where((e) => e.path == name);

      if (entry.isNotEmpty) {
        final response = await _github.repositories.getContents(
          slug,
          _encodeGitPath(actualPath),
        );

        if (response.file?.content != null) {
          final data = utf8.decode(base64.decode(response.file!.content!));
          final goldenJson = json.decode(data);
          golden = GoldenTestImages.fromDynamic(goldenJson);
          _currentGoldenTestImages = golden;
        }
      }
    }

    Uint8List? image;
    if (golden != null) {
      final hash = golden.goldenHashes![imageId];
      final path = '$actualPath/$goldenId/$hash.png';
      final entry = _tree.entries!.where((e) => e.path == path);
      if (entry.isNotEmpty) {
        final response = await _github.repositories.getContents(
          slug,
          _encodeGitPath(path),
        );

        if (response.file?.content != null) {
          image = base64.decode(response.file!.content!);
        }
      }
    }

    return image;
  }

  /// Implementation of the [TestReader] functional interface that can read test
  /// data from GitHub.
  Future<List<PendingTest>> testReader(
    BuildContext? context, {
    String? suiteName,
  }) async {
    await _loadData();
    final results = <PendingTest>[];

    try {
      final actualTestsPath =
          testsPath.startsWith('/') ? testsPath.substring(1) : testsPath;

      final tests = _tree.entries!.where(
        (entry) =>
            (actualTestsPath.isEmpty ||
                entry.path?.startsWith(actualTestsPath) == true) &&
            entry.path!.endsWith('.json'),
      );

      final batchSize = 10;
      final batch = <Future>[];

      for (var test in tests) {
        batch.add(
          Future.microtask(() async {
            final encodedPath = _encodeGitPath(test.path!);
            try {
              final contents = await _github.repositories.getContents(
                slug,
                encodedPath,
                ref: branch,
              );

              final body = utf8.decode(
                base64.decode(
                  contents.file!.content!.replaceAll('\n', ''),
                ),
              );
              final fullTest = Test.fromDynamic(json.decode(body));
              results.add(
                PendingTest.memory(fullTest),
              );
            } catch (e, stack) {
              _logger.warning(
                '[TEST LOAD FAILED]: Failed attempting to load test at path: [${test.path}]',
                e,
                stack,
              );
            }
          }),
        );
        if (batch.length >= batchSize) {
          await Future.wait(batch);
          batch.clear();
        }
      }

      if (batch.isNotEmpty) {
        await Future.wait(batch);
        batch.clear();
      }

      results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } catch (e, stack) {
      _logger.severe('Error loading tests', e, stack);
    }

    return results;
  }

  /// Implementation of the [TestWriter] functional interface that can submit
  /// test data to GitHub.
  Future<bool> testWriter(
    BuildContext context,
    Test test,
  ) async {
    await _loadData();
    var result = false;

    try {
      final actualTestsPath =
          testsPath.startsWith('/') ? testsPath.substring(1) : testsPath;

      final version = test.version + 1;
      final testData = test
          .copyWith(
            steps: test.steps
                .map(
                  (step) => step.copyWith(
                    image: Uint8List.fromList(<int>[]),
                  ),
                )
                .toList(),
            timestamp: DateTime.now(),
            version: version,
          )
          .toJson();

      final testSuitePrefix =
          test.suiteName?.isNotEmpty == true ? '${test.suiteName}/' : '';

      final path = '$actualTestsPath/$testSuitePrefix${test.name}.json';

      final encoder = const JsonEncoder.withIndent('  ');
      await uploadFile(
        data: utf8.encode(encoder.convert(testData)),
        message: 'Updating test',
        path: path,
      );
      result = true;
    } catch (e, stack) {
      _logger.severe('Error writing test', e, stack);
    }
    return result;
  }

  /// Uploads a file to GitHub
  Future<void> uploadFile({
    required List<int> data,
    required String message,
    required String path,
  }) async {
    await _loadData();

    String? sha;
    for (var entry in _tree.entries!) {
      if (path == entry.path) {
        sha = entry.sha;
        break;
      }
    }

    final url = '/repos/${slug.fullName}/contents/${_encodeGitPath(path)}';
    final body = json.encode({
      'branch': branch,
      'committer': _committer,
      'content': base64.encode(data),
      'message': message,
      if (sha != null) 'sha': sha
    });
    final response = await _github.putJSON(
      url,
      body: body,
      headers: {
        'content-type': 'application/json',
      },
    );

    if (response?['commit']?['sha'] == null) {
      throw Exception('[GITHUB UPLOAD]: Error -- [$response]');
    } else {
      _dirty = true;
      _logger.finest(
        '[GITHUB UPLOAD]: [$path] -- [${response?['commit']?['sha']}]',
      );
    }
  }

  Future<void> _loadData() async {
    if (_dirty) {
      _currentGoldenTestImages = null;
      _tree = await _github.git.getTree(slug, branch, recursive: true);
      _dirty = false;
    }
  }

  /// Encodes a path to be suitable to send to GitHub's for the content API.
  String _encodeGitPath(String path) {
    final builder = StringBuffer();

    for (var i = 0; i < path.length; i++) {
      var ch = path.substring(i, i + 1);

      switch (ch) {
        case ' ':
          ch = '%20';
          break;
        case '!':
          ch = '%21';
          break;
        case ':':
          ch = '%3A';
          break;
        case ';':
          ch = '%3B';
          break;
        case '#':
          ch = '%23';
          break;
        case '&':
          ch = '%26';
          break;
        case '?':
          ch = '%3F';
          break;
      }

      builder.write(ch);
    }

    return builder.toString();
  }
}
