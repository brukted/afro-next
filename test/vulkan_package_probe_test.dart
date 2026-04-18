import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/vulkan/ffi/vulkan_package_probe.dart';

void main() {
  test('loads a Vulkan runtime and creates an instance on desktop', () async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    final result = await VulkanPackageProbe().probe();

    expect(
      result.instanceCreationSucceeded,
      isTrue,
      reason: '${result.status}\n${result.notes.join('\n')}',
    );
    expect(result.loadedLibrary, isNotNull);

    if (Platform.isMacOS) {
      expect(
        result.loadedLibrary,
        contains('MoltenVK'),
        reason: 'Expected the macOS probe to load MoltenVK directly.',
      );
    }
  });
}
