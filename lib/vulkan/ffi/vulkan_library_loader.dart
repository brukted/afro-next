import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

class VulkanLibraryLoadException implements Exception {
  const VulkanLibraryLoadException(this.message, this.attemptedLibraries);

  final String message;
  final List<String> attemptedLibraries;

  @override
  String toString() {
    return '$message Tried: ${attemptedLibraries.join(', ')}';
  }
}

class VulkanLibraryHandle {
  const VulkanLibraryHandle({
    required this.path,
    required this.library,
  });

  final String path;
  final DynamicLibrary library;

  bool providesSymbol(String symbolName) => library.providesSymbol(symbolName);
}

class VulkanLibraryLoader {
  const VulkanLibraryLoader._();

  static VulkanLibraryHandle openSystemLibrary() {
    final attempts = <String>[];

    for (final candidate in _candidateLibraries()) {
      attempts.add(candidate);
      try {
        return VulkanLibraryHandle(
          path: candidate,
          library: DynamicLibrary.open(candidate),
        );
      } catch (_) {
        continue;
      }
    }

    throw VulkanLibraryLoadException(
      'Failed to open a Vulkan runtime library.',
      attempts,
    );
  }

  static List<String> _candidateLibraries() {
    final libraries = <String>[];
    final overridePath = Platform.environment['AFRO_VULKAN_LIBRARY'];
    if (overridePath != null && overridePath.isNotEmpty) {
      libraries.add(overridePath);
    }

    if (Platform.isWindows) {
      libraries.add('vulkan-1.dll');
      return libraries;
    }

    if (Platform.isLinux) {
      libraries.addAll([
        'libvulkan.so.1',
        '/usr/lib/libvulkan.so.1',
        '/usr/local/lib/libvulkan.so.1',
      ]);
      return libraries;
    }

    if (Platform.isMacOS) {
      libraries.addAll([
        ..._macOSBundleLibraries(),
        'libvulkan.1.dylib',
        '/opt/homebrew/lib/libvulkan.1.dylib',
        '/usr/local/lib/libvulkan.1.dylib',
        'libMoltenVK.dylib',
        '/opt/homebrew/lib/libMoltenVK.dylib',
        '/usr/local/lib/libMoltenVK.dylib',
      ]);
      return libraries;
    }

    return libraries;
  }

  static List<String> _macOSBundleLibraries() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final frameworkDirectory = p.normalize(
      p.join(executableDirectory, '..', 'Frameworks'),
    );

    return [
      p.join(frameworkDirectory, 'libMoltenVK.dylib'),
      p.join(frameworkDirectory, 'libvulkan.1.dylib'),
    ];
  }
}
