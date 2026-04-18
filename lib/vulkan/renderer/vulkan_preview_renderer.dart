import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:vulkan/src/vulkan_header.dart';

import '../../features/graph/models/graph_models.dart';
import '../../features/graph/models/graph_schema.dart';
import '../../features/material_graph/runtime/material_execution_ir.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../ffi/vulkan_runtime_bindings.dart';
import '../material_backend/material_backend_models.dart';
import '../material_backend/material_node_preview_support.dart';
import '../material_backend/material_backend_planner.dart';
import '../preview/preview_texture_registry.dart';
import '../resources/preview_render_target.dart';
import 'placeholder_renderer.dart';
import 'renderer_facade.dart';

class VulkanPreviewRendererFacade implements RendererFacade {
  VulkanPreviewRendererFacade({
    required this.bootstrapper,
    VulkanMaterialBackendPlanner planner = const VulkanMaterialBackendPlanner(),
    PreviewTextureRegistry? textureRegistry,
    int previewExtent = 192,
  }) : _planner = planner,
       _textureRegistry = textureRegistry ?? PreviewTextureRegistry(),
       _previewExtent = previewExtent,
       _fallback = PlaceholderVulkanRendererFacade(
         bootstrapper: bootstrapper,
         planner: planner,
       );

  final VulkanBootstrapper bootstrapper;
  final VulkanMaterialBackendPlanner _planner;
  final PreviewTextureRegistry _textureRegistry;
  final int _previewExtent;
  final PlaceholderVulkanRendererFacade _fallback;

  _VulkanMaterialExecutor? _executor;
  RendererBootstrapState? _bootstrapState;
  final Map<String, Future<void>> _graphWorkByGraphId =
      <String, Future<void>>{};
  bool _isDisposing = false;
  bool _disposed = false;

  @override
  Future<RendererBootstrapState> bootstrap() async {
    if (_disposed || _isDisposing) {
      return const RendererBootstrapState.preview();
    }
    final baseState = await bootstrapper.bootstrap();
    _VulkanMaterialExecutor? initializingExecutor;
    try {
      final executor = initializingExecutor =
          _executor ??
          _VulkanMaterialExecutor(
            textureRegistry: _textureRegistry,
            previewExtent: _previewExtent,
          );
      await executor.initialize();
      _executor = executor;
      final state = RendererBootstrapState(
        mode: RendererMode.vulkanReady,
        backendLabel: 'MoltenVK executor',
        summary:
            'Rendering node previews with offscreen Vulkan fragment passes.',
        details: <String>[
          'Runtime: ${executor.loadedLibraryPath}',
          'Preview extent: ${_previewExtent}x$_previewExtent',
          ...baseState.details,
        ],
        surfacePlan: baseState.surfacePlan,
      );
      _bootstrapState = state;
      return state;
    } catch (error) {
      final executor = _executor ?? initializingExecutor;
      _executor = null;
      if (executor != null) {
        await executor.dispose();
      }
      final state = RendererBootstrapState(
        mode: RendererMode.placeholder,
        backendLabel: 'Preview placeholder',
        summary: 'Falling back to placeholder previews: $error',
        details: baseState.details,
        surfacePlan: baseState.surfacePlan,
      );
      _bootstrapState = state;
      return state;
    }
  }

  @override
  Future<Map<String, PreviewRenderTarget>> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) async {
    if (_disposed || _isDisposing) {
      return <String, PreviewRenderTarget>{};
    }
    final executor = _executor;
    if (executor == null ||
        (_bootstrapState?.mode != RendererMode.vulkanReady)) {
      return _fallback.renderGraphPreviews(
        graph: graph,
        dirtyNodeIds: dirtyNodeIds,
        revision: revision,
      );
    }

    final plan = _planner.createPlan(graph);
    return _enqueueGraphWork(
      graph.graphId,
      () => executor.renderGraph(
        graph: graph,
        plan: plan,
        dirtyNodeIds: dirtyNodeIds,
        revision: revision,
      ),
    );
  }

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {
    if (_disposed || _isDisposing) {
      return;
    }
    final executor = _executor;
    if (executor == null) {
      return;
    }
    await _enqueueGraphWork(
      graphId,
      () =>
          executor.disposeGraph(graphId: graphId, activeNodeIds: activeNodeIds),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed || _isDisposing) {
      return;
    }
    _isDisposing = true;
    final pendingWork = _graphWorkByGraphId.values.toList(growable: false);
    if (pendingWork.isNotEmpty) {
      await Future.wait(
        pendingWork.map(
          (future) =>
              future.catchError((Object error, StackTrace stackTrace) {}),
        ),
        eagerError: false,
      );
    }
    _graphWorkByGraphId.clear();
    await _executor?.dispose();
    _executor = null;
    await _fallback.dispose();
    _disposed = true;
    _isDisposing = false;
  }

  Future<T> _enqueueGraphWork<T>(String graphId, Future<T> Function() action) {
    final previous = _graphWorkByGraphId[graphId] ?? Future<void>.value();
    final completer = Completer<T>();
    late final Future<void> queued;
    queued = previous
        .catchError((Object error, StackTrace stackTrace) {})
        .then<void>((_) async {
          if (_disposed) {
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('Renderer work requested after dispose.'),
              );
            }
            return;
          }
          try {
            completer.complete(await action());
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_graphWorkByGraphId[graphId], queued)) {
            _graphWorkByGraphId.remove(graphId);
          }
        });
    _graphWorkByGraphId[graphId] = queued;
    return completer.future;
  }
}

class _VulkanMaterialExecutor {
  _VulkanMaterialExecutor({
    required PreviewTextureRegistry textureRegistry,
    required int previewExtent,
  }) : _textureRegistry = textureRegistry,
       _previewExtent = previewExtent;

  final PreviewTextureRegistry _textureRegistry;
  final int _previewExtent;

  late final VulkanRuntimeBindings _vk;
  Pointer<VkInstance> _instance = nullptr;
  Pointer<VkPhysicalDevice> _physicalDevice = nullptr;
  Pointer<VkDevice> _device = nullptr;
  Pointer<VkQueue> _graphicsQueue = nullptr;
  Pointer<VkCommandPool> _commandPool = nullptr;
  Pointer<VkSampler> _linearSampler = nullptr;
  int _graphicsQueueFamilyIndex = 0;
  bool _initialized = false;

  final Map<String, PreviewRenderTarget> _previewTargetsByKey =
      <String, PreviewRenderTarget>{};
  final Map<String, Uint8List> _outputBytesByKey = <String, Uint8List>{};
  final Map<String, Uint8List> _shaderBytesByAssetPath = <String, Uint8List>{};

  String get loadedLibraryPath => _vk.loadedLibraryPath;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _vk = VulkanRuntimeBindings.load();
    _createInstance();
    _pickPhysicalDevice();
    _createDevice();
    _getGraphicsQueue();
    _createCommandPool();
    _createSampler();
    _initialized = true;
  }

  Future<void> dispose() async {
    if (_graphicsQueue != nullptr) {
      _checkResult(_vk.vkQueueWaitIdle(_graphicsQueue), 'vkQueueWaitIdle');
    }
    await _textureRegistry.clear();
    _previewTargetsByKey.clear();
    _outputBytesByKey.clear();
    _shaderBytesByAssetPath.clear();

    if (_linearSampler != nullptr) {
      _vk.vkDestroySampler(_device, _linearSampler, nullptr);
      _linearSampler = nullptr;
    }
    if (_commandPool != nullptr) {
      _vk.vkDestroyCommandPool(_device, _commandPool, nullptr);
      _commandPool = nullptr;
    }
    if (_device != nullptr) {
      _vk.vkDestroyDevice(_device, nullptr);
      _device = nullptr;
    }
    if (_instance != nullptr) {
      _vk.vkDestroyInstance(_instance, nullptr);
      _instance = nullptr;
    }
    _physicalDevice = nullptr;
    _graphicsQueue = nullptr;
    _graphicsQueueFamilyIndex = 0;
    _initialized = false;
  }

  Future<Map<String, PreviewRenderTarget>> renderGraph({
    required MaterialCompiledGraph graph,
    required VulkanMaterialBackendPlan plan,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) async {
    final results = <String, PreviewRenderTarget>{};
    final activeKeys = {
      for (final pass in plan.passes) _nodeKey(graph.graphId, pass.nodeId),
    };

    for (final passPlan in plan.passes) {
      final nodeKey = _nodeKey(graph.graphId, passPlan.nodeId);
      final existing = _previewTargetsByKey[nodeKey];
      if (!dirtyNodeIds.contains(passPlan.nodeId) && existing != null) {
        results[passPlan.nodeId] = existing;
        continue;
      }

      final compiledPass = graph.passForNode(passPlan.nodeId);
      if (compiledPass == null || !passPlan.isSupported) {
        final unsupportedTarget = PreviewRenderTarget(
          id: passPlan.outputTarget.id,
          kind: PreviewRenderTargetKind.placeholder,
          label: 'Unsupported preview',
          diagnostics: <String>[
            'Shader: ${passPlan.shader?.assetId ?? 'Unassigned'}',
            'Stage: ${passPlan.shader?.stage.name ?? 'unsupported'}',
            'Revision: $revision',
          ],
          status: PreviewRenderStatus.unsupported,
        );
        _previewTargetsByKey[nodeKey] = unsupportedTarget;
        results[passPlan.nodeId] = unsupportedTarget;
        continue;
      }

      try {
        final outputBytes = await _renderPass(graph: graph, pass: compiledPass);
        _outputBytesByKey[nodeKey] = outputBytes;
        final descriptor = await _textureRegistry.updateTexture(
          key: nodeKey,
          width: _previewExtent,
          height: _previewExtent,
          bgraBytes: outputBytes,
        );
        final target = descriptor == null
            ? PreviewRenderTarget(
                id: passPlan.outputTarget.id,
                kind: PreviewRenderTargetKind.placeholder,
                label: 'Texture bridge unavailable',
                diagnostics: <String>[
                  'Shader: ${compiledPass.shaderAssetId ?? 'Unassigned'}',
                  'Revision: $revision',
                ],
                status: PreviewRenderStatus.failed,
              )
            : PreviewRenderTarget(
                id: passPlan.outputTarget.id,
                kind: PreviewRenderTargetKind.externalTexture,
                label: 'Live preview',
                diagnostics: <String>[
                  'Shader: ${compiledPass.shaderAssetId ?? 'Unassigned'}',
                  'Extent: ${descriptor.width}x${descriptor.height}',
                  'Revision: $revision',
                ],
                texture: descriptor,
                status: PreviewRenderStatus.ready,
              );
        _previewTargetsByKey[nodeKey] = target;
        results[passPlan.nodeId] = target;
      } catch (error) {
        final errorTarget = PreviewRenderTarget(
          id: passPlan.outputTarget.id,
          kind: PreviewRenderTargetKind.error,
          label: 'Preview failed',
          diagnostics: <String>['$error', 'Revision: $revision'],
          status: PreviewRenderStatus.failed,
        );
        _previewTargetsByKey[nodeKey] = errorTarget;
        results[passPlan.nodeId] = errorTarget;
      }
    }

    await _trimInactiveKeys(activeKeys);
    return results;
  }

  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {
    final allowedKeys = {
      for (final nodeId in activeNodeIds) _nodeKey(graphId, nodeId),
    };
    await _trimInactiveKeys(allowedKeys, graphPrefix: '$graphId:');
  }

  Future<void> _trimInactiveKeys(
    Set<String> allowedKeys, {
    String? graphPrefix,
  }) async {
    final retainedKeys = _previewTargetsByKey.keys.where((key) {
      if (graphPrefix == null) {
        return allowedKeys.contains(key);
      }
      return !key.startsWith(graphPrefix) || allowedKeys.contains(key);
    }).toSet();
    await _textureRegistry.releaseMissingKeys(retainedKeys);

    final staleKeys = _previewTargetsByKey.keys
        .where((key) {
          if (graphPrefix == null) {
            return !allowedKeys.contains(key);
          }
          return key.startsWith(graphPrefix) && !allowedKeys.contains(key);
        })
        .toList(growable: false);
    for (final key in staleKeys) {
      _previewTargetsByKey.remove(key);
      _outputBytesByKey.remove(key);
    }
  }

  Future<Uint8List> _renderPass({
    required MaterialCompiledGraph graph,
    required MaterialCompiledNodePass pass,
  }) async {
    final fragmentShader = await _loadShaderBytes(
      _compiledShaderAssetPath(pass.shaderAssetId!),
    );
    final vertexShader = await _loadShaderBytes(
      'assets/shaders/spirv/material/fullscreen_triangle.vert.spv',
    );
    final uniformBytes = MaterialNodePreviewSupportRegistry.packUniforms(pass);

    final inputs = <_TextureUpload>[];
    for (final input in pass.textureInputs) {
      final sourceBytes = input.sourceNodeId == null
          ? null
          : _outputBytesByKey[_nodeKey(graph.graphId, input.sourceNodeId!)];
      inputs.add(
        _TextureUpload(
          bindingKey: input.bindingKey,
          bytes: sourceBytes ?? _defaultTextureBytes(input.fallbackValue),
          width: sourceBytes == null ? 1 : _previewExtent,
          height: sourceBytes == null ? 1 : _previewExtent,
        ),
      );
    }

    final invocation = _OffscreenRenderInvocation(
      width: _previewExtent,
      height: _previewExtent,
      vertexShaderBytes: vertexShader,
      fragmentShaderBytes: fragmentShader,
      uniformBytes: uniformBytes,
      inputs: inputs,
    );
    return _executeInvocation(invocation);
  }

  Uint8List _defaultTextureBytes(GraphValueData value) {
    switch (value.valueType) {
      case GraphValueType.float4:
        final color = value.asFloat4();
        return Uint8List.fromList(<int>[
          _toByte(color.z),
          _toByte(color.y),
          _toByte(color.x),
          _toByte(color.w),
        ]);
      case GraphValueType.float:
        final scalar = value.floatValue ?? 0;
        return Uint8List.fromList(<int>[0, 0, _toByte(scalar), 255]);
      default:
        return Uint8List.fromList(const <int>[0, 0, 0, 255]);
    }
  }

  int _toByte(double value) => (value.clamp(0, 1) * 255).round();

  Future<Uint8List> _loadShaderBytes(String assetPath) async {
    final cached = _shaderBytesByAssetPath[assetPath];
    if (cached != null) {
      return cached;
    }

    final bundleData = await rootBundle.load(assetPath);
    final bytes = bundleData.buffer.asUint8List(
      bundleData.offsetInBytes,
      bundleData.lengthInBytes,
    );
    _shaderBytesByAssetPath[assetPath] = bytes;
    return bytes;
  }

  String _compiledShaderAssetPath(String shaderAssetId) {
    if (shaderAssetId.startsWith('assets/')) {
      return shaderAssetId;
    }
    return 'assets/shaders/spirv/$shaderAssetId.spv';
  }

  String _nodeKey(String graphId, String nodeId) => '$graphId:$nodeId';

  Future<Uint8List> _executeInvocation(
    _OffscreenRenderInvocation invocation,
  ) async {
    final outputImage = _createImage(
      width: invocation.width,
      height: invocation.height,
      usage:
          VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
    );
    final outputView = _createImageView(outputImage.image);
    final renderPass = _createRenderPass();
    final framebuffer = _createFramebuffer(
      renderPass: renderPass,
      colorView: outputView,
      width: invocation.width,
      height: invocation.height,
    );
    final uniformBuffer = _createBufferWithData(
      invocation.uniformBytes,
      VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
    );
    final uploadedInputs = invocation.inputs
        .map(
          (input) => _createSampledTexture(
            bytes: input.bytes,
            width: input.width,
            height: input.height,
          ),
        )
        .toList(growable: false);
    final descriptorSetLayout = _createDescriptorSetLayout(
      uploadedInputs.length,
    );
    final pipelineLayout = _createPipelineLayout(descriptorSetLayout);
    final vertexModule = _createShaderModule(invocation.vertexShaderBytes);
    final fragmentModule = _createShaderModule(invocation.fragmentShaderBytes);
    final pipeline = _createGraphicsPipeline(
      renderPass: renderPass,
      pipelineLayout: pipelineLayout,
      vertexShader: vertexModule,
      fragmentShader: fragmentModule,
      width: invocation.width,
      height: invocation.height,
    );
    final descriptorPool = _createDescriptorPool(uploadedInputs.length);
    final descriptorSet = _allocateDescriptorSet(
      descriptorPool,
      descriptorSetLayout,
    );
    _writeDescriptorSet(
      descriptorSet: descriptorSet,
      uniformBuffer: uniformBuffer,
      textures: uploadedInputs,
    );
    final readbackBuffer = _createBuffer(
      size: invocation.width * invocation.height * 4,
      usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT,
      memoryFlags:
          VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );

    try {
      final commandBuffer = _allocateCommandBuffer();
      try {
        _recordRenderCommandBuffer(
          commandBuffer: commandBuffer,
          renderPass: renderPass,
          framebuffer: framebuffer,
          pipeline: pipeline,
          pipelineLayout: pipelineLayout,
          descriptorSet: descriptorSet,
          outputImage: outputImage.image,
          readbackBuffer: readbackBuffer.buffer,
          width: invocation.width,
          height: invocation.height,
        );
        _submitAndWait(commandBuffer);
      } finally {
        _freeCommandBuffer(commandBuffer);
      }
      return _readBufferBytes(
        readbackBuffer,
        invocation.width * invocation.height * 4,
      );
    } finally {
      _destroyBuffer(readbackBuffer);
      _destroyDescriptorPool(descriptorPool);
      _destroyPipeline(pipeline);
      _destroyPipelineLayout(pipelineLayout);
      _destroyDescriptorSetLayout(descriptorSetLayout);
      _destroyShaderModule(vertexModule);
      _destroyShaderModule(fragmentModule);
      for (final texture in uploadedInputs) {
        _destroyTexture(texture);
      }
      _destroyBuffer(uniformBuffer);
      _destroyFramebuffer(framebuffer);
      _destroyRenderPass(renderPass);
      _destroyImageView(outputView);
      _destroyImage(outputImage);
    }
  }

  void _createInstance() {
    final appName = 'Eyecandy'.toNativeUtf8();
    final engineName = 'Eyecandy Vulkan'.toNativeUtf8();

    final appInfo = calloc<VkApplicationInfo>();
    appInfo.ref
      ..sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
      ..pApplicationName = appName
      ..applicationVersion = _makeVersion(0, 1, 0)
      ..pEngineName = engineName
      ..engineVersion = _makeVersion(0, 1, 0)
      ..apiVersion = _makeVersion(1, 1, 0);

    final createInfo = calloc<VkInstanceCreateInfo>();
    createInfo.ref
      ..sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
      ..flags = 0
      ..pApplicationInfo = appInfo
      ..enabledExtensionCount = 0
      ..ppEnabledExtensionNames = nullptr;

    final instancePointer = calloc<Pointer<VkInstance>>();
    try {
      _checkResult(
        _vk.vkCreateInstance(createInfo, nullptr, instancePointer),
        'vkCreateInstance',
      );
      _instance = instancePointer.value;
    } finally {
      calloc
        ..free(appInfo)
        ..free(createInfo)
        ..free(instancePointer)
        ..free(appName)
        ..free(engineName);
    }
  }

  void _pickPhysicalDevice() {
    final count = calloc<Uint32>();
    try {
      _checkResult(
        _vk.vkEnumeratePhysicalDevices(_instance, count, nullptr),
        'vkEnumeratePhysicalDevices(count)',
      );
      final devicePointers = calloc<Pointer<VkPhysicalDevice>>(count.value);
      try {
        _checkResult(
          _vk.vkEnumeratePhysicalDevices(_instance, count, devicePointers),
          'vkEnumeratePhysicalDevices(list)',
        );
        for (var index = 0; index < count.value; index += 1) {
          final candidate = devicePointers[index];
          final queueFamilyIndex = _findGraphicsQueueFamily(candidate);
          if (queueFamilyIndex != null) {
            _physicalDevice = candidate;
            _graphicsQueueFamilyIndex = queueFamilyIndex;
            return;
          }
        }
      } finally {
        calloc.free(devicePointers);
      }
    } finally {
      calloc.free(count);
    }
    throw StateError('No Vulkan graphics queue family was found.');
  }

  int? _findGraphicsQueueFamily(Pointer<VkPhysicalDevice> device) {
    final count = calloc<Uint32>();
    try {
      _vk.vkGetPhysicalDeviceQueueFamilyProperties(device, count, nullptr);
      final families = calloc<VkQueueFamilyProperties>(count.value);
      try {
        _vk.vkGetPhysicalDeviceQueueFamilyProperties(device, count, families);
        for (var index = 0; index < count.value; index += 1) {
          if ((families[index].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0) {
            return index;
          }
        }
      } finally {
        calloc.free(families);
      }
    } finally {
      calloc.free(count);
    }
    return null;
  }

  void _createDevice() {
    final queuePriority = calloc<Float>()..value = 1;
    final queueCreateInfo = calloc<VkDeviceQueueCreateInfo>();
    queueCreateInfo.ref
      ..sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
      ..queueFamilyIndex = _graphicsQueueFamilyIndex
      ..queueCount = 1
      ..pQueuePriorities = queuePriority;

    final extensionNames = _deviceExtensionNames();
    final extensionPointers = calloc<Pointer<Utf8>>(extensionNames.length);
    for (var index = 0; index < extensionNames.length; index += 1) {
      extensionPointers[index] = extensionNames[index].toNativeUtf8();
    }

    final features = calloc<VkPhysicalDeviceFeatures>();
    final createInfo = calloc<VkDeviceCreateInfo>();
    createInfo.ref
      ..sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
      ..queueCreateInfoCount = 1
      ..pQueueCreateInfos = queueCreateInfo
      ..enabledExtensionCount = extensionNames.length
      ..ppEnabledExtensionNames = extensionNames.isEmpty
          ? nullptr
          : extensionPointers.cast()
      ..pEnabledFeatures = features;

    final devicePointer = calloc<Pointer<VkDevice>>();
    try {
      _checkResult(
        _vk.vkCreateDevice(_physicalDevice, createInfo, nullptr, devicePointer),
        'vkCreateDevice',
      );
      _device = devicePointer.value;
    } finally {
      for (var index = 0; index < extensionNames.length; index += 1) {
        calloc.free(extensionPointers[index]);
      }
      calloc
        ..free(extensionPointers)
        ..free(queuePriority)
        ..free(queueCreateInfo)
        ..free(features)
        ..free(createInfo)
        ..free(devicePointer);
    }
  }

  List<String> _deviceExtensionNames() {
    final count = calloc<Uint32>();
    try {
      _checkResult(
        _vk.vkEnumerateDeviceExtensionProperties(
          _physicalDevice,
          nullptr,
          count,
          nullptr,
        ),
        'vkEnumerateDeviceExtensionProperties(count)',
      );
      final properties = calloc<VkExtensionProperties>(count.value);
      try {
        _checkResult(
          _vk.vkEnumerateDeviceExtensionProperties(
            _physicalDevice,
            nullptr,
            count,
            properties,
          ),
          'vkEnumerateDeviceExtensionProperties(list)',
        );
        final extensions = <String>[];
        for (var index = 0; index < count.value; index += 1) {
          final name = properties[index].extensionName.toNativeString(256);
          if (name == 'VK_KHR_portability_subset') {
            extensions.add(name);
          }
        }
        return extensions;
      } finally {
        calloc.free(properties);
      }
    } finally {
      calloc.free(count);
    }
  }

  void _getGraphicsQueue() {
    final queuePointer = calloc<Pointer<VkQueue>>();
    try {
      _vk.vkGetDeviceQueue(_device, _graphicsQueueFamilyIndex, 0, queuePointer);
      _graphicsQueue = queuePointer.value;
    } finally {
      calloc.free(queuePointer);
    }
  }

  void _createCommandPool() {
    final createInfo = calloc<VkCommandPoolCreateInfo>();
    final poolPointer = calloc<Pointer<VkCommandPool>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        ..flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
        ..queueFamilyIndex = _graphicsQueueFamilyIndex;
      _checkResult(
        _vk.vkCreateCommandPool(_device, createInfo, nullptr, poolPointer),
        'vkCreateCommandPool',
      );
      _commandPool = poolPointer.value;
    } finally {
      calloc
        ..free(createInfo)
        ..free(poolPointer);
    }
  }

  void _createSampler() {
    final createInfo = calloc<VkSamplerCreateInfo>();
    final samplerPointer = calloc<Pointer<VkSampler>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
        ..magFilter = VK_FILTER_LINEAR
        ..minFilter = VK_FILTER_LINEAR
        ..addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        ..addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        ..addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        ..anisotropyEnable = VK_FALSE
        ..maxAnisotropy = 1
        ..borderColor = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE
        ..unnormalizedCoordinates = VK_FALSE
        ..compareEnable = VK_FALSE
        ..mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
      _checkResult(
        _vk.vkCreateSampler(_device, createInfo, nullptr, samplerPointer),
        'vkCreateSampler',
      );
      _linearSampler = samplerPointer.value;
    } finally {
      calloc
        ..free(createInfo)
        ..free(samplerPointer);
    }
  }

  _VulkanBuffer _createBufferWithData(Uint8List bytes, int usage) {
    final buffer = _createBuffer(
      size: bytes.lengthInBytes,
      usage: usage,
      memoryFlags:
          VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    final mappedPointer = calloc<Pointer<Void>>();
    try {
      _checkResult(
        _vk.vkMapMemory(
          _device,
          buffer.memory,
          0,
          bytes.lengthInBytes,
          0,
          mappedPointer,
        ),
        'vkMapMemory',
      );
      mappedPointer.value
          .cast<Uint8>()
          .asTypedList(bytes.lengthInBytes)
          .setAll(0, bytes);
    } finally {
      _vk.vkUnmapMemory(_device, buffer.memory);
      calloc.free(mappedPointer);
    }
    return buffer;
  }

  _VulkanBuffer _createBuffer({
    required int size,
    required int usage,
    required int memoryFlags,
  }) {
    final createInfo = calloc<VkBufferCreateInfo>();
    final bufferPointer = calloc<Pointer<VkBuffer>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
        ..size = size
        ..usage = usage
        ..sharingMode = VK_SHARING_MODE_EXCLUSIVE;
      _checkResult(
        _vk.vkCreateBuffer(_device, createInfo, nullptr, bufferPointer),
        'vkCreateBuffer',
      );
      final memory = _allocateForBuffer(bufferPointer.value, memoryFlags);
      return _VulkanBuffer(
        buffer: bufferPointer.value,
        memory: memory,
        size: size,
      );
    } finally {
      calloc
        ..free(createInfo)
        ..free(bufferPointer);
    }
  }

  Pointer<VkDeviceMemory> _allocateForBuffer(
    Pointer<VkBuffer> buffer,
    int memoryFlags,
  ) {
    final requirements = calloc<VkMemoryRequirements>();
    try {
      _vk.vkGetBufferMemoryRequirements(_device, buffer, requirements);
      final memory = _allocateMemory(requirements.ref, memoryFlags);
      _checkResult(
        _vk.vkBindBufferMemory(_device, buffer, memory, 0),
        'vkBindBufferMemory',
      );
      return memory;
    } finally {
      calloc.free(requirements);
    }
  }

  _VulkanImage _createImage({
    required int width,
    required int height,
    required int usage,
  }) {
    final createInfo = calloc<VkImageCreateInfo>();
    final imagePointer = calloc<Pointer<VkImage>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
        ..imageType = VK_IMAGE_TYPE_2D
        ..format = VK_FORMAT_B8G8R8A8_UNORM
        ..extent.width = width
        ..extent.height = height
        ..extent.depth = 1
        ..mipLevels = 1
        ..arrayLayers = 1
        ..samples = VK_SAMPLE_COUNT_1_BIT
        ..tiling = VK_IMAGE_TILING_OPTIMAL
        ..usage = usage
        ..sharingMode = VK_SHARING_MODE_EXCLUSIVE
        ..initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
      _checkResult(
        _vk.vkCreateImage(_device, createInfo, nullptr, imagePointer),
        'vkCreateImage',
      );
      final memory = _allocateForImage(imagePointer.value);
      return _VulkanImage(
        image: imagePointer.value,
        memory: memory,
        width: width,
        height: height,
      );
    } finally {
      calloc
        ..free(createInfo)
        ..free(imagePointer);
    }
  }

  Pointer<VkDeviceMemory> _allocateForImage(Pointer<VkImage> image) {
    final requirements = calloc<VkMemoryRequirements>();
    try {
      _vk.vkGetImageMemoryRequirements(_device, image, requirements);
      final memory = _allocateMemory(
        requirements.ref,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
      );
      _checkResult(
        _vk.vkBindImageMemory(_device, image, memory, 0),
        'vkBindImageMemory',
      );
      return memory;
    } finally {
      calloc.free(requirements);
    }
  }

  Pointer<VkDeviceMemory> _allocateMemory(
    VkMemoryRequirements requirements,
    int desiredFlags,
  ) {
    final memoryProperties = calloc<VkPhysicalDeviceMemoryProperties>();
    try {
      _vk.vkGetPhysicalDeviceMemoryProperties(
        _physicalDevice,
        memoryProperties,
      );
      final index = _findMemoryTypeIndex(
        memoryTypeBits: requirements.memoryTypeBits,
        desiredFlags: desiredFlags,
        memoryProperties: memoryProperties.ref,
      );
      final allocateInfo = calloc<VkMemoryAllocateInfo>();
      final memoryPointer = calloc<Pointer<VkDeviceMemory>>();
      try {
        allocateInfo.ref
          ..sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
          ..allocationSize = requirements.size
          ..memoryTypeIndex = index;
        _checkResult(
          _vk.vkAllocateMemory(_device, allocateInfo, nullptr, memoryPointer),
          'vkAllocateMemory',
        );
        return memoryPointer.value;
      } finally {
        calloc
          ..free(allocateInfo)
          ..free(memoryPointer);
      }
    } finally {
      calloc.free(memoryProperties);
    }
  }

  int _findMemoryTypeIndex({
    required int memoryTypeBits,
    required int desiredFlags,
    required VkPhysicalDeviceMemoryProperties memoryProperties,
  }) {
    for (var index = 0; index < memoryProperties.memoryTypeCount; index += 1) {
      final typeSupported = (memoryTypeBits & (1 << index)) != 0;
      if (!typeSupported) {
        continue;
      }
      final flags = memoryProperties.memoryTypes[index].propertyFlags;
      if ((flags & desiredFlags) == desiredFlags) {
        return index;
      }
    }
    throw StateError(
      'No Vulkan memory type matched flags 0x${desiredFlags.toRadixString(16)}.',
    );
  }

  Pointer<VkImageView> _createImageView(Pointer<VkImage> image) {
    final createInfo = calloc<VkImageViewCreateInfo>();
    final viewPointer = calloc<Pointer<VkImageView>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
        ..image = image
        ..viewType = VK_IMAGE_VIEW_TYPE_2D
        ..format = VK_FORMAT_B8G8R8A8_UNORM
        ..subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
        ..subresourceRange.baseMipLevel = 0
        ..subresourceRange.levelCount = 1
        ..subresourceRange.baseArrayLayer = 0
        ..subresourceRange.layerCount = 1;
      _checkResult(
        _vk.vkCreateImageView(_device, createInfo, nullptr, viewPointer),
        'vkCreateImageView',
      );
      return viewPointer.value;
    } finally {
      calloc
        ..free(createInfo)
        ..free(viewPointer);
    }
  }

  _UploadedTexture _createSampledTexture({
    required Uint8List bytes,
    required int width,
    required int height,
  }) {
    final stagingBuffer = _createBufferWithData(
      bytes,
      VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
    );
    final image = _createImage(
      width: width,
      height: height,
      usage: VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
    );
    final imageView = _createImageView(image.image);
    try {
      _runOneShotCommandBuffer((commandBuffer) {
        _transitionImageLayout(
          commandBuffer: commandBuffer,
          image: image.image,
          oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
          newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
          srcAccessMask: 0,
          dstAccessMask: VK_ACCESS_TRANSFER_WRITE_BIT,
          srcStageMask: VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
          dstStageMask: VK_PIPELINE_STAGE_TRANSFER_BIT,
        );
        final region = calloc<VkBufferImageCopy>();
        try {
          region.ref
            ..bufferOffset = 0
            ..bufferRowLength = 0
            ..bufferImageHeight = 0
            ..imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
            ..imageSubresource.mipLevel = 0
            ..imageSubresource.baseArrayLayer = 0
            ..imageSubresource.layerCount = 1
            ..imageExtent.width = width
            ..imageExtent.height = height
            ..imageExtent.depth = 1;
          _vk.vkCmdCopyBufferToImage(
            commandBuffer,
            stagingBuffer.buffer,
            image.image,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            region,
          );
        } finally {
          calloc.free(region);
        }
        _transitionImageLayout(
          commandBuffer: commandBuffer,
          image: image.image,
          oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
          newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
          srcAccessMask: VK_ACCESS_TRANSFER_WRITE_BIT,
          dstAccessMask: VK_ACCESS_SHADER_READ_BIT,
          srcStageMask: VK_PIPELINE_STAGE_TRANSFER_BIT,
          dstStageMask: VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        );
      });
      return _UploadedTexture(image: image, view: imageView);
    } finally {
      _destroyBuffer(stagingBuffer);
    }
  }

  Pointer<VkRenderPass> _createRenderPass() {
    final attachment = calloc<VkAttachmentDescription>();
    final colorReference = calloc<VkAttachmentReference>();
    final subpass = calloc<VkSubpassDescription>();
    final createInfo = calloc<VkRenderPassCreateInfo>();
    final renderPassPointer = calloc<Pointer<VkRenderPass>>();
    try {
      attachment.ref
        ..format = VK_FORMAT_B8G8R8A8_UNORM
        ..samples = VK_SAMPLE_COUNT_1_BIT
        ..loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
        ..storeOp = VK_ATTACHMENT_STORE_OP_STORE
        ..stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
        ..stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
        ..initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        ..finalLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
      colorReference.ref
        ..attachment = 0
        ..layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
      subpass.ref
        ..pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
        ..colorAttachmentCount = 1
        ..pColorAttachments = colorReference;
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
        ..attachmentCount = 1
        ..pAttachments = attachment
        ..subpassCount = 1
        ..pSubpasses = subpass;
      _checkResult(
        _vk.vkCreateRenderPass(_device, createInfo, nullptr, renderPassPointer),
        'vkCreateRenderPass',
      );
      return renderPassPointer.value;
    } finally {
      calloc
        ..free(attachment)
        ..free(colorReference)
        ..free(subpass)
        ..free(createInfo)
        ..free(renderPassPointer);
    }
  }

  Pointer<VkFramebuffer> _createFramebuffer({
    required Pointer<VkRenderPass> renderPass,
    required Pointer<VkImageView> colorView,
    required int width,
    required int height,
  }) {
    final attachments = calloc<Pointer<VkImageView>>()..value = colorView;
    final createInfo = calloc<VkFramebufferCreateInfo>();
    final framebufferPointer = calloc<Pointer<VkFramebuffer>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
        ..renderPass = renderPass
        ..attachmentCount = 1
        ..pAttachments = attachments
        ..width = width
        ..height = height
        ..layers = 1;
      _checkResult(
        _vk.vkCreateFramebuffer(
          _device,
          createInfo,
          nullptr,
          framebufferPointer,
        ),
        'vkCreateFramebuffer',
      );
      return framebufferPointer.value;
    } finally {
      calloc
        ..free(attachments)
        ..free(createInfo)
        ..free(framebufferPointer);
    }
  }

  Pointer<VkDescriptorSetLayout> _createDescriptorSetLayout(int textureCount) {
    final bindingCount = textureCount == 0 ? 1 : textureCount + 2;
    final bindings = calloc<VkDescriptorSetLayoutBinding>(bindingCount);
    final createInfo = calloc<VkDescriptorSetLayoutCreateInfo>();
    final layoutPointer = calloc<Pointer<VkDescriptorSetLayout>>();
    try {
      bindings[0]
        ..binding = 0
        ..descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        ..descriptorCount = 1
        ..stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
      if (textureCount > 0) {
        bindings[1]
          ..binding = 1
          ..descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER
          ..descriptorCount = 1
          ..stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        for (var index = 0; index < textureCount; index += 1) {
          bindings[index + 2]
            ..binding = index + 2
            ..descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE
            ..descriptorCount = 1
            ..stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        }
      }
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
        ..bindingCount = bindingCount
        ..pBindings = bindings;
      _checkResult(
        _vk.vkCreateDescriptorSetLayout(
          _device,
          createInfo,
          nullptr,
          layoutPointer,
        ),
        'vkCreateDescriptorSetLayout',
      );
      return layoutPointer.value;
    } finally {
      calloc
        ..free(bindings)
        ..free(createInfo)
        ..free(layoutPointer);
    }
  }

  Pointer<VkPipelineLayout> _createPipelineLayout(
    Pointer<VkDescriptorSetLayout> descriptorSetLayout,
  ) {
    final setLayouts = calloc<Pointer<VkDescriptorSetLayout>>()
      ..value = descriptorSetLayout;
    final createInfo = calloc<VkPipelineLayoutCreateInfo>();
    final layoutPointer = calloc<Pointer<VkPipelineLayout>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        ..setLayoutCount = 1
        ..pSetLayouts = setLayouts;
      _checkResult(
        _vk.vkCreatePipelineLayout(_device, createInfo, nullptr, layoutPointer),
        'vkCreatePipelineLayout',
      );
      return layoutPointer.value;
    } finally {
      calloc
        ..free(setLayouts)
        ..free(createInfo)
        ..free(layoutPointer);
    }
  }

  Pointer<VkShaderModule> _createShaderModule(Uint8List bytes) {
    final words = calloc<Uint32>((bytes.lengthInBytes + 3) ~/ 4);
    words.cast<Uint8>().asTypedList(bytes.lengthInBytes).setAll(0, bytes);
    final createInfo = calloc<VkShaderModuleCreateInfo>();
    final modulePointer = calloc<Pointer<VkShaderModule>>();
    try {
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
        ..codeSize = bytes.lengthInBytes
        ..pCode = words;
      _checkResult(
        _vk.vkCreateShaderModule(_device, createInfo, nullptr, modulePointer),
        'vkCreateShaderModule',
      );
      return modulePointer.value;
    } finally {
      calloc
        ..free(words)
        ..free(createInfo)
        ..free(modulePointer);
    }
  }

  Pointer<VkPipeline> _createGraphicsPipeline({
    required Pointer<VkRenderPass> renderPass,
    required Pointer<VkPipelineLayout> pipelineLayout,
    required Pointer<VkShaderModule> vertexShader,
    required Pointer<VkShaderModule> fragmentShader,
    required int width,
    required int height,
  }) {
    final entryPoint = 'main'.toNativeUtf8();
    final shaderStages = calloc<VkPipelineShaderStageCreateInfo>(2);
    final vertexInputState = calloc<VkPipelineVertexInputStateCreateInfo>();
    final inputAssemblyState = calloc<VkPipelineInputAssemblyStateCreateInfo>();
    final viewport = calloc<VkViewport>();
    final scissor = calloc<VkRect2D>();
    final viewportState = calloc<VkPipelineViewportStateCreateInfo>();
    final rasterizationState = calloc<VkPipelineRasterizationStateCreateInfo>();
    final multisampleState = calloc<VkPipelineMultisampleStateCreateInfo>();
    final colorBlendAttachment = calloc<VkPipelineColorBlendAttachmentState>();
    final colorBlendState = calloc<VkPipelineColorBlendStateCreateInfo>();
    final pipelineCreateInfo = calloc<VkGraphicsPipelineCreateInfo>();
    final pipelinePointer = calloc<Pointer<VkPipeline>>();
    try {
      shaderStages[0]
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        ..stage = VK_SHADER_STAGE_VERTEX_BIT
        ..module = vertexShader
        ..pName = entryPoint;
      shaderStages[1]
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        ..stage = VK_SHADER_STAGE_FRAGMENT_BIT
        ..module = fragmentShader
        ..pName = entryPoint;

      vertexInputState.ref.sType =
          VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
      inputAssemblyState.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
        ..topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
        ..primitiveRestartEnable = VK_FALSE;

      viewport.ref
        ..x = 0
        ..y = 0
        ..width = width.toDouble()
        ..height = height.toDouble()
        ..minDepth = 0
        ..maxDepth = 1;
      scissor.ref
        ..offset.x = 0
        ..offset.y = 0
        ..extent.width = width
        ..extent.height = height;
      viewportState.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
        ..viewportCount = 1
        ..pViewports = viewport
        ..scissorCount = 1
        ..pScissors = scissor;

      rasterizationState.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
        ..depthClampEnable = VK_FALSE
        ..rasterizerDiscardEnable = VK_FALSE
        ..polygonMode = VK_POLYGON_MODE_FILL
        ..lineWidth = 1
        ..cullMode = VK_CULL_MODE_NONE
        ..frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE
        ..depthBiasEnable = VK_FALSE;

      multisampleState.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
        ..rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
        ..sampleShadingEnable = VK_FALSE;

      colorBlendAttachment.ref
        ..colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT |
            VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT |
            VK_COLOR_COMPONENT_A_BIT
        ..blendEnable = VK_FALSE;
      colorBlendState.ref
        ..sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
        ..logicOpEnable = VK_FALSE
        ..attachmentCount = 1
        ..pAttachments = colorBlendAttachment;

      pipelineCreateInfo.ref
        ..sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
        ..stageCount = 2
        ..pStages = shaderStages
        ..pVertexInputState = vertexInputState
        ..pInputAssemblyState = inputAssemblyState
        ..pViewportState = viewportState
        ..pRasterizationState = rasterizationState
        ..pMultisampleState = multisampleState
        ..pColorBlendState = colorBlendState
        ..layout = pipelineLayout
        ..renderPass = renderPass
        ..subpass = 0;

      _checkResult(
        _vk.vkCreateGraphicsPipelines(
          _device,
          nullptr,
          1,
          pipelineCreateInfo,
          nullptr,
          pipelinePointer,
        ),
        'vkCreateGraphicsPipelines',
      );
      return pipelinePointer.value;
    } finally {
      calloc
        ..free(entryPoint)
        ..free(shaderStages)
        ..free(vertexInputState)
        ..free(inputAssemblyState)
        ..free(viewport)
        ..free(scissor)
        ..free(viewportState)
        ..free(rasterizationState)
        ..free(multisampleState)
        ..free(colorBlendAttachment)
        ..free(colorBlendState)
        ..free(pipelineCreateInfo)
        ..free(pipelinePointer);
    }
  }

  Pointer<VkDescriptorPool> _createDescriptorPool(int textureCount) {
    final sizes = calloc<VkDescriptorPoolSize>(textureCount == 0 ? 1 : 3);
    final createInfo = calloc<VkDescriptorPoolCreateInfo>();
    final poolPointer = calloc<Pointer<VkDescriptorPool>>();
    try {
      sizes[0]
        ..type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        ..descriptorCount = 1;
      var sizeCount = 1;
      if (textureCount > 0) {
        sizes[1]
          ..type = VK_DESCRIPTOR_TYPE_SAMPLER
          ..descriptorCount = 1;
        sizes[2]
          ..type = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE
          ..descriptorCount = textureCount;
        sizeCount = 3;
      }
      createInfo.ref
        ..sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
        ..maxSets = 1
        ..poolSizeCount = sizeCount
        ..pPoolSizes = sizes;
      _checkResult(
        _vk.vkCreateDescriptorPool(_device, createInfo, nullptr, poolPointer),
        'vkCreateDescriptorPool',
      );
      return poolPointer.value;
    } finally {
      calloc
        ..free(sizes)
        ..free(createInfo)
        ..free(poolPointer);
    }
  }

  Pointer<VkDescriptorSet> _allocateDescriptorSet(
    Pointer<VkDescriptorPool> descriptorPool,
    Pointer<VkDescriptorSetLayout> descriptorSetLayout,
  ) {
    final layouts = calloc<Pointer<VkDescriptorSetLayout>>()
      ..value = descriptorSetLayout;
    final allocateInfo = calloc<VkDescriptorSetAllocateInfo>();
    final descriptorSetPointer = calloc<Pointer<VkDescriptorSet>>();
    try {
      allocateInfo.ref
        ..sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
        ..descriptorPool = descriptorPool
        ..descriptorSetCount = 1
        ..pSetLayouts = layouts;
      _checkResult(
        _vk.vkAllocateDescriptorSets(
          _device,
          allocateInfo,
          descriptorSetPointer,
        ),
        'vkAllocateDescriptorSets',
      );
      return descriptorSetPointer.value;
    } finally {
      calloc
        ..free(layouts)
        ..free(allocateInfo)
        ..free(descriptorSetPointer);
    }
  }

  void _writeDescriptorSet({
    required Pointer<VkDescriptorSet> descriptorSet,
    required _VulkanBuffer uniformBuffer,
    required List<_UploadedTexture> textures,
  }) {
    final writeCount = textures.isEmpty ? 1 : textures.length + 2;
    final writes = calloc<VkWriteDescriptorSet>(writeCount);
    final bufferInfo = calloc<VkDescriptorBufferInfo>()
      ..ref.buffer = uniformBuffer.buffer
      ..ref.offset = 0
      ..ref.range = uniformBuffer.size;
    final samplerInfo = calloc<VkDescriptorImageInfo>()
      ..ref.sampler = _linearSampler;
    final imageInfos = textures.isEmpty
        ? nullptr
        : calloc<VkDescriptorImageInfo>(textures.length);
    try {
      writes[0]
        ..sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
        ..dstSet = descriptorSet
        ..dstBinding = 0
        ..descriptorCount = 1
        ..descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        ..pBufferInfo = bufferInfo;
      if (textures.isNotEmpty) {
        writes[1]
          ..sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
          ..dstSet = descriptorSet
          ..dstBinding = 1
          ..descriptorCount = 1
          ..descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER
          ..pImageInfo = samplerInfo;
        for (var index = 0; index < textures.length; index += 1) {
          imageInfos[index]
            ..sampler = nullptr
            ..imageView = textures[index].view
            ..imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
          writes[index + 2]
            ..sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
            ..dstSet = descriptorSet
            ..dstBinding = index + 2
            ..descriptorCount = 1
            ..descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE
            ..pImageInfo = imageInfos + index;
        }
      }
      _vk.vkUpdateDescriptorSets(_device, writeCount, writes, 0, nullptr);
    } finally {
      calloc
        ..free(writes)
        ..free(bufferInfo)
        ..free(samplerInfo);
      if (imageInfos != nullptr) {
        calloc.free(imageInfos);
      }
    }
  }

  Pointer<VkCommandBuffer> _allocateCommandBuffer() {
    final allocateInfo = calloc<VkCommandBufferAllocateInfo>();
    final commandBufferPointer = calloc<Pointer<VkCommandBuffer>>();
    try {
      allocateInfo.ref
        ..sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        ..commandPool = _commandPool
        ..level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
        ..commandBufferCount = 1;
      _checkResult(
        _vk.vkAllocateCommandBuffers(
          _device,
          allocateInfo,
          commandBufferPointer,
        ),
        'vkAllocateCommandBuffers',
      );
      return commandBufferPointer.value;
    } finally {
      calloc
        ..free(allocateInfo)
        ..free(commandBufferPointer);
    }
  }

  void _freeCommandBuffer(Pointer<VkCommandBuffer> commandBuffer) {
    final commandBuffers = calloc<Pointer<VkCommandBuffer>>()
      ..value = commandBuffer;
    try {
      _vk.vkFreeCommandBuffers(_device, _commandPool, 1, commandBuffers);
    } finally {
      calloc.free(commandBuffers);
    }
  }

  void _recordRenderCommandBuffer({
    required Pointer<VkCommandBuffer> commandBuffer,
    required Pointer<VkRenderPass> renderPass,
    required Pointer<VkFramebuffer> framebuffer,
    required Pointer<VkPipeline> pipeline,
    required Pointer<VkPipelineLayout> pipelineLayout,
    required Pointer<VkDescriptorSet> descriptorSet,
    required Pointer<VkImage> outputImage,
    required Pointer<VkBuffer> readbackBuffer,
    required int width,
    required int height,
  }) {
    final beginInfo = calloc<VkCommandBufferBeginInfo>();
    final clearValues = calloc<VkClearValue>();
    final renderPassInfo = calloc<VkRenderPassBeginInfo>();
    final descriptorSets = calloc<Pointer<VkDescriptorSet>>()
      ..value = descriptorSet;
    final copyRegion = calloc<VkBufferImageCopy>();
    try {
      beginInfo.ref.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
      _checkResult(
        _vk.vkBeginCommandBuffer(commandBuffer, beginInfo),
        'vkBeginCommandBuffer',
      );

      clearValues[0].color.float32[0] = 0;
      clearValues[0].color.float32[1] = 0;
      clearValues[0].color.float32[2] = 0;
      clearValues[0].color.float32[3] = 0;

      renderPassInfo.ref
        ..sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
        ..renderPass = renderPass
        ..framebuffer = framebuffer
        ..renderArea.offset.x = 0
        ..renderArea.offset.y = 0
        ..renderArea.extent.width = width
        ..renderArea.extent.height = height
        ..clearValueCount = 1
        ..pClearValues = clearValues;

      _vk.vkCmdBeginRenderPass(
        commandBuffer,
        renderPassInfo,
        VK_SUBPASS_CONTENTS_INLINE,
      );
      _vk.vkCmdBindPipeline(
        commandBuffer,
        VK_PIPELINE_BIND_POINT_GRAPHICS,
        pipeline,
      );
      _vk.vkCmdBindDescriptorSets(
        commandBuffer,
        VK_PIPELINE_BIND_POINT_GRAPHICS,
        pipelineLayout,
        0,
        1,
        descriptorSets,
        0,
        nullptr,
      );
      _vk.vkCmdDraw(commandBuffer, 3, 1, 0, 0);
      _vk.vkCmdEndRenderPass(commandBuffer);

      copyRegion.ref
        ..bufferOffset = 0
        ..bufferRowLength = 0
        ..bufferImageHeight = 0
        ..imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
        ..imageSubresource.mipLevel = 0
        ..imageSubresource.baseArrayLayer = 0
        ..imageSubresource.layerCount = 1
        ..imageExtent.width = width
        ..imageExtent.height = height
        ..imageExtent.depth = 1;
      _vk.vkCmdCopyImageToBuffer(
        commandBuffer,
        outputImage,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        readbackBuffer,
        1,
        copyRegion,
      );

      _checkResult(_vk.vkEndCommandBuffer(commandBuffer), 'vkEndCommandBuffer');
    } finally {
      calloc
        ..free(beginInfo)
        ..free(clearValues)
        ..free(renderPassInfo)
        ..free(descriptorSets)
        ..free(copyRegion);
    }
  }

  Uint8List _readBufferBytes(_VulkanBuffer buffer, int byteCount) {
    final mappedPointer = calloc<Pointer<Void>>();
    try {
      _checkResult(
        _vk.vkMapMemory(_device, buffer.memory, 0, byteCount, 0, mappedPointer),
        'vkMapMemory(readback)',
      );
      return Uint8List.fromList(
        mappedPointer.value.cast<Uint8>().asTypedList(byteCount),
      );
    } finally {
      _vk.vkUnmapMemory(_device, buffer.memory);
      calloc.free(mappedPointer);
    }
  }

  void _runOneShotCommandBuffer(
    void Function(Pointer<VkCommandBuffer> commandBuffer) record,
  ) {
    final commandBuffer = _allocateCommandBuffer();
    try {
      final beginInfo = calloc<VkCommandBufferBeginInfo>();
      try {
        beginInfo.ref
          ..sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
          ..flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        _checkResult(
          _vk.vkBeginCommandBuffer(commandBuffer, beginInfo),
          'vkBeginCommandBuffer(oneShot)',
        );
        record(commandBuffer);
        _checkResult(
          _vk.vkEndCommandBuffer(commandBuffer),
          'vkEndCommandBuffer(oneShot)',
        );
      } finally {
        calloc.free(beginInfo);
      }
      _submitAndWait(commandBuffer);
    } finally {
      _freeCommandBuffer(commandBuffer);
    }
  }

  void _submitAndWait(Pointer<VkCommandBuffer> commandBuffer) {
    final commandBuffers = calloc<Pointer<VkCommandBuffer>>()
      ..value = commandBuffer;
    final submitInfo = calloc<VkSubmitInfo>();
    try {
      submitInfo.ref
        ..sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
        ..commandBufferCount = 1
        ..pCommandBuffers = commandBuffers;
      _checkResult(
        _vk.vkQueueSubmit(_graphicsQueue, 1, submitInfo, nullptr),
        'vkQueueSubmit',
      );
      _checkResult(_vk.vkQueueWaitIdle(_graphicsQueue), 'vkQueueWaitIdle');
    } finally {
      calloc
        ..free(commandBuffers)
        ..free(submitInfo);
    }
  }

  void _transitionImageLayout({
    required Pointer<VkCommandBuffer> commandBuffer,
    required Pointer<VkImage> image,
    required int oldLayout,
    required int newLayout,
    required int srcAccessMask,
    required int dstAccessMask,
    required int srcStageMask,
    required int dstStageMask,
  }) {
    final barrier = calloc<VkImageMemoryBarrier>();
    try {
      barrier.ref
        ..sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
        ..oldLayout = oldLayout
        ..newLayout = newLayout
        ..srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
        ..dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
        ..image = image
        ..subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
        ..subresourceRange.baseMipLevel = 0
        ..subresourceRange.levelCount = 1
        ..subresourceRange.baseArrayLayer = 0
        ..subresourceRange.layerCount = 1
        ..srcAccessMask = srcAccessMask
        ..dstAccessMask = dstAccessMask;
      _vk.vkCmdPipelineBarrier(
        commandBuffer,
        srcStageMask,
        dstStageMask,
        0,
        0,
        nullptr,
        0,
        nullptr,
        1,
        barrier,
      );
    } finally {
      calloc.free(barrier);
    }
  }

  void _destroyTexture(_UploadedTexture texture) {
    _destroyImageView(texture.view);
    _destroyImage(texture.image);
  }

  void _destroyBuffer(_VulkanBuffer buffer) {
    _vk.vkDestroyBuffer(_device, buffer.buffer, nullptr);
    _vk.vkFreeMemory(_device, buffer.memory, nullptr);
  }

  void _destroyImage(_VulkanImage image) {
    _vk.vkDestroyImage(_device, image.image, nullptr);
    _vk.vkFreeMemory(_device, image.memory, nullptr);
  }

  void _destroyImageView(Pointer<VkImageView> imageView) {
    _vk.vkDestroyImageView(_device, imageView, nullptr);
  }

  void _destroyShaderModule(Pointer<VkShaderModule> module) {
    _vk.vkDestroyShaderModule(_device, module, nullptr);
  }

  void _destroyPipeline(Pointer<VkPipeline> pipeline) {
    _vk.vkDestroyPipeline(_device, pipeline, nullptr);
  }

  void _destroyPipelineLayout(Pointer<VkPipelineLayout> pipelineLayout) {
    _vk.vkDestroyPipelineLayout(_device, pipelineLayout, nullptr);
  }

  void _destroyDescriptorSetLayout(Pointer<VkDescriptorSetLayout> layout) {
    _vk.vkDestroyDescriptorSetLayout(_device, layout, nullptr);
  }

  void _destroyDescriptorPool(Pointer<VkDescriptorPool> descriptorPool) {
    _vk.vkDestroyDescriptorPool(_device, descriptorPool, nullptr);
  }

  void _destroyFramebuffer(Pointer<VkFramebuffer> framebuffer) {
    _vk.vkDestroyFramebuffer(_device, framebuffer, nullptr);
  }

  void _destroyRenderPass(Pointer<VkRenderPass> renderPass) {
    _vk.vkDestroyRenderPass(_device, renderPass, nullptr);
  }

  int _makeVersion(int major, int minor, int patch) {
    return (major << 22) | (minor << 12) | patch;
  }

  void _checkResult(int result, String operation) {
    if (result != VK_SUCCESS) {
      throw StateError('$operation failed with Vulkan result $result.');
    }
  }
}

extension on Array<Uint8> {
  String toNativeString(int length) {
    final bytes = List<int>.generate(
      length,
      (index) => this[index],
      growable: false,
    );
    final nullIndex = bytes.indexOf(0);
    return String.fromCharCodes(
      nullIndex == -1 ? bytes : bytes.take(nullIndex),
    );
  }
}

class _OffscreenRenderInvocation {
  const _OffscreenRenderInvocation({
    required this.width,
    required this.height,
    required this.vertexShaderBytes,
    required this.fragmentShaderBytes,
    required this.uniformBytes,
    required this.inputs,
  });

  final int width;
  final int height;
  final Uint8List vertexShaderBytes;
  final Uint8List fragmentShaderBytes;
  final Uint8List uniformBytes;
  final List<_TextureUpload> inputs;
}

class _TextureUpload {
  const _TextureUpload({
    required this.bindingKey,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String bindingKey;
  final Uint8List bytes;
  final int width;
  final int height;
}

class _VulkanBuffer {
  const _VulkanBuffer({
    required this.buffer,
    required this.memory,
    required this.size,
  });

  final Pointer<VkBuffer> buffer;
  final Pointer<VkDeviceMemory> memory;
  final int size;
}

class _VulkanImage {
  const _VulkanImage({
    required this.image,
    required this.memory,
    required this.width,
    required this.height,
  });

  final Pointer<VkImage> image;
  final Pointer<VkDeviceMemory> memory;
  final int width;
  final int height;
}

class _UploadedTexture {
  const _UploadedTexture({required this.image, required this.view});

  final _VulkanImage image;
  final Pointer<VkImageView> view;
}
