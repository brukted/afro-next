import 'dart:io';

import 'package:eyecandy/vulkan/ffi/vulkan_package_probe.dart';

Future<void> main() async {
  final result = await VulkanPackageProbe().probe();

  stdout.writeln('status: ${result.status}');
  stdout.writeln('loadedLibrary: ${result.loadedLibrary ?? 'none'}');
  stdout.writeln(
    'instanceCreationSucceeded: ${result.instanceCreationSucceeded}',
  );
  stdout.writeln('packageSupportedPlatform: ${result.packageSupportedPlatform}');
  stdout.writeln('apiVersion: ${result.apiVersion ?? 'unknown'}');
  stdout.writeln('resultCode: ${result.resultCode ?? 'none'}');
  if (result.notes.isNotEmpty) {
    stdout.writeln('notes:');
    for (final note in result.notes) {
      stdout.writeln('- $note');
    }
  }
}
