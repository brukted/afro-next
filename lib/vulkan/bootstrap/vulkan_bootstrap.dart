import '../ffi/vulkan_package_probe.dart';
import '../platform/platform_surface_bridge.dart';

enum RendererMode { placeholder, vulkanReady, awaitingBridge }

class RendererBootstrapState {
  const RendererBootstrapState({
    required this.mode,
    required this.backendLabel,
    required this.summary,
    required this.details,
    required this.surfacePlan,
  });

  final RendererMode mode;
  final String backendLabel;
  final String summary;
  final List<String> details;
  final SurfaceBootstrapPlan surfacePlan;

  const RendererBootstrapState.preview()
    : mode = RendererMode.placeholder,
      backendLabel = 'Preview placeholder',
      summary = 'Using the Flutter placeholder preview pipeline.',
      details = const <String>[],
      surfacePlan = const SurfaceBootstrapPlan(
        backend: SurfaceBackend.unsupported,
        summary: 'No surface bootstrap is needed in preview mode.',
        nextSteps: <String>[],
        requiresNativeBridge: false,
      );
}

class VulkanBootstrapper {
  const VulkanBootstrapper({
    required this.packageProbe,
    required this.platformSurfaceBridge,
  });

  final VulkanPackageProbe packageProbe;
  final PlatformSurfaceBridge platformSurfaceBridge;

  Future<RendererBootstrapState> bootstrap() async {
    final probeResult = await packageProbe.probe();
    final surfacePlan = platformSurfaceBridge.describe();

    if (probeResult.instanceCreationSucceeded) {
      return RendererBootstrapState(
        mode: RendererMode.awaitingBridge,
        backendLabel: 'Vulkan package',
        summary:
            'The Vulkan package is active and the renderer is waiting on a native surface bridge.',
        details: <String>[
          probeResult.status,
          ...probeResult.notes,
          surfacePlan.summary,
        ],
        surfacePlan: surfacePlan,
      );
    }

    final mode = probeResult.packageSupportedPlatform
        ? RendererMode.awaitingBridge
        : RendererMode.placeholder;

    return RendererBootstrapState(
      mode: mode,
      backendLabel: probeResult.packageSupportedPlatform
          ? 'Vulkan planned'
          : 'Preview placeholder',
      summary: probeResult.status,
      details: <String>[
        ...probeResult.notes,
        if (surfacePlan.summary.isNotEmpty) surfacePlan.summary,
      ],
      surfacePlan: surfacePlan,
    );
  }
}
