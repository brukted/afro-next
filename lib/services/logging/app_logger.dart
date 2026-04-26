import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  AppLogger._({
    required this.logger,
    required File? logFile,
    required bool mirrorToConsole,
  })  : _logFile = logFile,
        _mirrorToConsole = mirrorToConsole {
    _configureRootLogging();
  }

  final Logger logger;
  final File? _logFile;
  final bool _mirrorToConsole;

  static bool _rootConfigured = false;

  static Future<AppLogger> bootstrap({
    required Directory logsDirectory,
  }) async {
    final logFile = File(p.join(logsDirectory.path, 'afro.log'));
    await logFile.create(recursive: true);

    return AppLogger._(
      logger: Logger('afro'),
      logFile: logFile,
      mirrorToConsole: true,
    );
  }

  factory AppLogger.memory() {
    return AppLogger._(
      logger: Logger.detached('afro.preview'),
      logFile: null,
      mirrorToConsole: true,
    );
  }

  void info(String message) => logger.info(message);

  void warning(String message) => logger.warning(message);

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    logger.severe(message, error, stackTrace);
  }

  void debug(String message) => logger.fine(message);

  void _configureRootLogging() {
    if (_rootConfigured) {
      return;
    }

    hierarchicalLoggingEnabled = true;
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(_writeRecord);
    _rootConfigured = true;
  }

  Future<void> _writeRecord(LogRecord record) async {
    final line =
        '[${record.level.name}] ${record.time.toIso8601String()} ${record.loggerName}: ${record.message}';

    if (_mirrorToConsole) {
      debugPrint(line);
      if (record.error != null) {
        debugPrint('  error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('$record.stackTrace');
      }
    }

    if (_logFile == null) {
      return;
    }

    unawaited(
      _logFile.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      ),
    );
  }
}
