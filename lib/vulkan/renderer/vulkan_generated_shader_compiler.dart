import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

abstract interface class VulkanGeneratedShaderCompiler {
  Future<Uint8List> compileFragmentShader({
    required String source,
    required String cacheKey,
  });

  Future<void> dispose();
}

abstract interface class VulkanProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

class IoVulkanProcessRunner implements VulkanProcessRunner {
  const IoVulkanProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }
}

class ExternalProcessVulkanGeneratedShaderCompiler
    implements VulkanGeneratedShaderCompiler {
  static const List<String> _defaultFallbackExecutablePaths = <String>[
    '/opt/homebrew/bin/glslangValidator',
    '/usr/local/bin/glslangValidator',
    '/opt/local/bin/glslangValidator',
  ];

  ExternalProcessVulkanGeneratedShaderCompiler({
    VulkanProcessRunner processRunner = const IoVulkanProcessRunner(),
    String? executablePath,
    List<String>? fallbackExecutablePaths,
  }) : _processRunner = processRunner,
       _executablePath = executablePath,
       _fallbackExecutablePaths = fallbackExecutablePaths;

  final VulkanProcessRunner _processRunner;
  final String? _executablePath;
  final List<String>? _fallbackExecutablePaths;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  static final Logger _logger = Logger('eyecandy.preview.shader');

  @override
  Future<Uint8List> compileFragmentShader({
    required String source,
    required String cacheKey,
  }) async {
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    Directory? tempDirectory;
    File? sourceFile;
    File? outputFile;
    String? executablePath;
    List<String> arguments = const <String>[];
    var stage = 'start';

    try {
      stage = 'create-temp-directory';
      tempDirectory = await Directory.systemTemp.createTemp(
        'eyecandy_generated_shader_',
      );
      stage = 'resolve-temp-directory';
      final canonicalTempDirectory = await tempDirectory.resolveSymbolicLinks();
      sourceFile = File('$canonicalTempDirectory/generated.frag');
      outputFile = File('$canonicalTempDirectory/generated.spv');
      stage = 'resolve-compiler-path';
      executablePath = _resolveExecutablePath();
      arguments = <String>[
        '-V',
        '-S',
        'frag',
        sourceFile.path,
        '-o',
        outputFile.path,
      ];
      stage = 'write-source-file';
      await sourceFile.writeAsString(source);
      stage = 'spawn-compiler-process';
      final result = await _processRunner.run(executablePath, arguments);
      if (result.exitCode != 0) {
        _logger.warning(
          'Generated fragment shader `$cacheKey` failed with exit code ${result.exitCode}.',
        );
        throw VulkanGeneratedShaderCompileException(
          message: 'Failed to compile generated fragment shader.',
          diagnostics: <String>[
            'Compiler: $executablePath',
            'Arguments: ${arguments.join(' ')}',
            if ('${result.stdout}'.trim().isNotEmpty)
              'stdout: ${'${result.stdout}'.trim()}',
            if ('${result.stderr}'.trim().isNotEmpty)
              'stderr: ${'${result.stderr}'.trim()}',
            'Exit code: ${result.exitCode}',
          ],
        );
      }
      stage = 'verify-spirv-output';
      if (!await outputFile.exists()) {
        throw VulkanGeneratedShaderCompileException(
          message: 'Shader compiler did not produce SPIR-V output.',
          diagnostics: <String>[
            'Compiler: $executablePath',
            'Arguments: ${arguments.join(' ')}',
          ],
        );
      }
      stage = 'read-spirv-output';
      final bytes = await outputFile.readAsBytes();
      _cache[cacheKey] = bytes;
      return bytes;
    } on ProcessException catch (error) {
      _logger.severe(
        'Generated shader compiler process failed for `$cacheKey`.',
        error,
      );
      throw VulkanGeneratedShaderCompileException(
        message: 'Generated shader compiler is unavailable.',
        diagnostics: <String>[
          'Compiler: $executablePath',
          'Arguments: ${arguments.join(' ')}',
          'PATH: ${Platform.environment['PATH'] ?? '<unset>'}',
          '$error',
        ],
      );
    } on VulkanGeneratedShaderCompileException {
      rethrow;
    } catch (error, stackTrace) {
      _logger.severe(
        'Unexpected generated shader compiler failure for `$cacheKey` during `$stage`.',
        error,
        stackTrace,
      );
      throw VulkanGeneratedShaderCompileException(
        message: 'Generated shader compiler failed unexpectedly.',
        diagnostics: <String>[
          'Stage: $stage',
          if (executablePath != null) 'Compiler: $executablePath',
          if (arguments.isNotEmpty) 'Arguments: ${arguments.join(' ')}',
          if (sourceFile != null) 'Source file: ${sourceFile.path}',
          if (outputFile != null) 'Output file: ${outputFile.path}',
          'PATH: ${Platform.environment['PATH'] ?? '<unset>'}',
          '$error',
          '$stackTrace',
        ],
      );
    } finally {
      if (tempDirectory != null && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> dispose() async {
    _cache.clear();
  }

  String _resolveExecutablePath() {
    final override =
        _executablePath ?? Platform.environment['EYECANDY_GLSLANG_VALIDATOR'];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    final fallbackExecutablePaths =
        _fallbackExecutablePaths ?? _defaultFallbackExecutablePaths;
    for (final candidate in fallbackExecutablePaths) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    final onPath = _lookupExecutableOnPath('glslangValidator');
    if (onPath != null) {
      return onPath;
    }
    return 'glslangValidator';
  }

  String? _lookupExecutableOnPath(String executable) {
    final pathValue = Platform.environment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return null;
    }
    final separator = Platform.isWindows ? ';' : ':';
    for (final directory in pathValue.split(separator)) {
      final trimmed = directory.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final candidate = File('$trimmed/$executable');
      if (candidate.existsSync()) {
        return candidate.path;
      }
    }
    return null;
  }
}

class VulkanGeneratedShaderCompileException implements Exception {
  const VulkanGeneratedShaderCompileException({
    required this.message,
    required this.diagnostics,
  });

  final String message;
  final List<String> diagnostics;

  @override
  String toString() => message;
}
