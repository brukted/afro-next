import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
// ignore: implementation_imports
import 'package:vulkan/src/vulkan_header.dart';

import 'vulkan_library_loader.dart';

class VulkanProbeResult {
  const VulkanProbeResult({
    required this.packageSupportedPlatform,
    required this.instanceCreationSucceeded,
    required this.status,
    required this.notes,
    this.loadedLibrary,
    this.apiVersion,
    this.resultCode,
  });

  final bool packageSupportedPlatform;
  final bool instanceCreationSucceeded;
  final String status;
  final List<String> notes;
  final String? loadedLibrary;
  final int? apiVersion;
  final int? resultCode;
}

class VulkanPackageProbe {
  Future<VulkanProbeResult> probe() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return const VulkanProbeResult(
        packageSupportedPlatform: false,
        instanceCreationSucceeded: false,
        status: 'The current platform is outside the Vulkan desktop target set.',
        notes: <String>[],
      );
    }

    final libraryHandle = _loadLibrary();
    final applicationName = 'Eyecandy'.toNativeUtf8();
    final engineName = 'Eyecandy Flutter'.toNativeUtf8();
    final appInfo = calloc<VkApplicationInfo>();
    final instanceCreateInfo = calloc<VkInstanceCreateInfo>();
    final instancePointer = calloc<Pointer<VkInstance>>();
    final apiVersionPointer = calloc<Uint32>();

    try {
      final vkCreateInstance = libraryHandle.library.lookupFunction<
          VkCreateInstanceNative, VkCreateInstance>('vkCreateInstance');
      final vkDestroyInstance = libraryHandle.library.lookupFunction<
          VkDestroyInstanceNative, VkDestroyInstance>('vkDestroyInstance');

      appInfo.ref
        ..sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
        ..pNext = nullptr
        ..pApplicationName = applicationName
        ..applicationVersion = _makeVersion(0, 1, 0)
        ..pEngineName = engineName
        ..engineVersion = _makeVersion(0, 1, 0)
        ..apiVersion = _makeVersion(1, 3, 0);

      instanceCreateInfo.ref
        ..sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        ..pNext = nullptr
        ..flags = 0
        ..pApplicationInfo = appInfo
        ..enabledExtensionCount = 0
        ..ppEnabledExtensionNames = nullptr
        ..enabledLayerCount = 0
        ..ppEnabledLayerNames = nullptr;

      int? apiVersion;
      if (libraryHandle.providesSymbol('vkEnumerateInstanceVersion')) {
        final vkEnumerateInstanceVersion = libraryHandle.library.lookupFunction<
            VkEnumerateInstanceVersionNative,
            VkEnumerateInstanceVersion>('vkEnumerateInstanceVersion');
        final versionResult =
            vkEnumerateInstanceVersion(apiVersionPointer.cast<Void>());
        if (versionResult == VK_SUCCESS) {
          apiVersion = apiVersionPointer.value;
        }
      }

      final result =
          vkCreateInstance(instanceCreateInfo, nullptr, instancePointer);
      if (result == VK_SUCCESS) {
        vkDestroyInstance(instancePointer.value, nullptr);
        return VulkanProbeResult(
          packageSupportedPlatform: true,
          instanceCreationSucceeded: true,
          status: 'Created a Vulkan instance successfully.',
          notes: <String>[
            'Loaded runtime: ${libraryHandle.path}',
            if (Platform.isMacOS)
              'MoltenVK can satisfy the package bindings when loaded directly.',
            'Surface and swapchain bootstrap still need a native Flutter bridge.',
          ],
          loadedLibrary: libraryHandle.path,
          apiVersion: apiVersion,
          resultCode: result,
        );
      }

      return VulkanProbeResult(
        packageSupportedPlatform: true,
        instanceCreationSucceeded: false,
        status: 'vkCreateInstance returned a non-success result.',
        notes: <String>[
          'Loaded runtime: ${libraryHandle.path}',
          'The loader is visible, but full runtime validation still needs work.',
        ],
        loadedLibrary: libraryHandle.path,
        apiVersion: apiVersion,
        resultCode: result,
      );
    } catch (error) {
      return VulkanProbeResult(
        packageSupportedPlatform: true,
        instanceCreationSucceeded: false,
        status: 'Failed to invoke the vulkan package probe at runtime: $error',
        notes: <String>[
          'Loaded runtime: ${libraryHandle.path}',
          'The package is configured, but the Vulkan runtime may be unavailable.',
        ],
        loadedLibrary: libraryHandle.path,
      );
    } finally {
      calloc
        ..free(applicationName)
        ..free(engineName)
        ..free(appInfo)
        ..free(instanceCreateInfo)
        ..free(instancePointer)
        ..free(apiVersionPointer);
    }
  }

  VulkanLibraryHandle _loadLibrary() {
    try {
      return VulkanLibraryLoader.openSystemLibrary();
    } on VulkanLibraryLoadException catch (error) {
      throw Exception(error.toString());
    }
  }

  int _makeVersion(int major, int minor, int patch) {
    return (major << 22) | (minor << 12) | patch;
  }
}
