import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  const AppPaths({
    required this.rootDirectory,
    required this.configDirectory,
    required this.logsDirectory,
    required this.workspaceDirectory,
    required this.cacheDirectory,
  });

  final Directory rootDirectory;
  final Directory configDirectory;
  final Directory logsDirectory;
  final Directory workspaceDirectory;
  final Directory cacheDirectory;

  static Future<AppPaths> initialize({
    String applicationName = 'afro',
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final cacheBaseDirectory = await getTemporaryDirectory();

    final rootDirectory = Directory(
      p.join(supportDirectory.path, applicationName),
    );
    final configDirectory = Directory(p.join(rootDirectory.path, 'config'));
    final logsDirectory = Directory(p.join(rootDirectory.path, 'logs'));
    final workspaceDirectory = Directory(p.join(rootDirectory.path, 'workspace'));
    final cacheDirectory = Directory(
      p.join(cacheBaseDirectory.path, applicationName, 'cache'),
    );

    for (final directory in [
      rootDirectory,
      configDirectory,
      logsDirectory,
      workspaceDirectory,
      cacheDirectory,
    ]) {
      await directory.create(recursive: true);
    }

    return AppPaths(
      rootDirectory: rootDirectory,
      configDirectory: configDirectory,
      logsDirectory: logsDirectory,
      workspaceDirectory: workspaceDirectory,
      cacheDirectory: cacheDirectory,
    );
  }
}
