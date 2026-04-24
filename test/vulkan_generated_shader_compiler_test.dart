import 'dart:io';
import 'dart:typed_data';

import 'package:eyecandy/vulkan/renderer/vulkan_generated_shader_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caches compiled fragment shaders by cache key', () async {
    final runner = _FakeProcessRunner(
      onRun: (executable, arguments, workingDirectory) async {
        final outputPath = arguments[arguments.indexOf('-o') + 1];
        await File(outputPath).writeAsBytes(const <int>[1, 2, 3, 4]);
        return ProcessResult(1, 0, '', '');
      },
    );
    final compiler = ExternalProcessVulkanGeneratedShaderCompiler(
      processRunner: runner,
      executablePath: '/usr/bin/glslangValidator',
    );
    addTearDown(compiler.dispose);

    final first = await compiler.compileFragmentShader(
      source: _sampleFragmentSource,
      cacheKey: 'shader-cache-key',
    );
    final second = await compiler.compileFragmentShader(
      source: _sampleFragmentSource,
      cacheKey: 'shader-cache-key',
    );

    expect(first, Uint8List.fromList(const <int>[1, 2, 3, 4]));
    expect(second, Uint8List.fromList(const <int>[1, 2, 3, 4]));
    expect(runner.runCount, 1);
  });

  test('includes compiler stderr when external compilation fails', () async {
    final runner = _FakeProcessRunner(
      onRun: (executable, arguments, workingDirectory) async {
        return ProcessResult(
          1,
          2,
          'stdout message',
          'stderr message',
        );
      },
    );
    final compiler = ExternalProcessVulkanGeneratedShaderCompiler(
      processRunner: runner,
      executablePath: 'glslangValidator',
    );
    addTearDown(compiler.dispose);

    expect(
      () => compiler.compileFragmentShader(
        source: _sampleFragmentSource,
        cacheKey: 'failing-shader',
      ),
      throwsA(
        isA<VulkanGeneratedShaderCompileException>().having(
          (error) => error.diagnostics.join('\n'),
          'diagnostics',
          allOf(
            contains('Compiler: glslangValidator'),
            contains('stdout message'),
            contains('stderr message'),
            contains('Exit code: 2'),
          ),
        ),
      ),
    );
  });

  test('uses fallback absolute compiler paths when PATH lookup is unavailable', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'eyecandy_glslang_fallback_test_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final fallbackPath = '${tempDirectory.path}/glslangValidator';
    await File(fallbackPath).writeAsString('');

    late String capturedExecutable;
    final runner = _FakeProcessRunner(
      onRun: (executable, arguments, workingDirectory) async {
        capturedExecutable = executable;
        final outputPath = arguments[arguments.indexOf('-o') + 1];
        await File(outputPath).writeAsBytes(const <int>[5, 6, 7, 8]);
        return ProcessResult(1, 0, '', '');
      },
    );
    final compiler = ExternalProcessVulkanGeneratedShaderCompiler(
      processRunner: runner,
      fallbackExecutablePaths: <String>[fallbackPath],
    );
    addTearDown(compiler.dispose);

    final result = await compiler.compileFragmentShader(
      source: _sampleFragmentSource,
      cacheKey: 'fallback-lookup',
    );

    expect(result, Uint8List.fromList(const <int>[5, 6, 7, 8]));
    expect(capturedExecutable, fallbackPath);
  });
}

const String _sampleFragmentSource = '''
#version 450
layout(location = 0) out vec4 outColor;

void main() {
  outColor = vec4(1.0);
}
''';

class _FakeProcessRunner implements VulkanProcessRunner {
  _FakeProcessRunner({
    required this.onRun,
  });

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
    String? workingDirectory,
  ) onRun;

  int runCount = 0;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    runCount += 1;
    return onRun(executable, arguments, workingDirectory);
  }
}
