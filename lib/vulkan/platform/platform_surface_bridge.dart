import 'dart:io';

enum SurfaceBackend {
  win32,
  x11,
  wayland,
  metalLayer,
  unsupported,
}

class SurfaceBootstrapPlan {
  const SurfaceBootstrapPlan({
    required this.backend,
    required this.summary,
    required this.nextSteps,
    this.requiresNativeBridge = true,
  });

  final SurfaceBackend backend;
  final String summary;
  final List<String> nextSteps;
  final bool requiresNativeBridge;
}

abstract interface class PlatformSurfaceBridge {
  SurfaceBootstrapPlan describe();

  factory PlatformSurfaceBridge.current() => _CurrentPlatformSurfaceBridge();
}

class _CurrentPlatformSurfaceBridge implements PlatformSurfaceBridge {
  @override
  SurfaceBootstrapPlan describe() {
    if (Platform.isMacOS) {
      return const SurfaceBootstrapPlan(
        backend: SurfaceBackend.metalLayer,
        summary:
            'MoltenVK will need a native bridge that exposes a CAMetalLayer-backed surface to Flutter.',
        nextSteps: [
          'Bridge the Flutter desktop window handle to a native macOS plugin.',
          'Provide a CAMetalLayer or NSView-backed surface for MoltenVK.',
          'Feed the resulting surface into the Vulkan renderer bootstrap.',
        ],
      );
    }

    if (Platform.isWindows) {
      return const SurfaceBootstrapPlan(
        backend: SurfaceBackend.win32,
        summary:
            'Windows will use a Win32 Vulkan surface once the native window handle bridge is in place.',
        nextSteps: [
          'Expose the HWND from the Flutter runner.',
          'Create the Win32 VkSurfaceKHR during renderer bootstrap.',
        ],
      );
    }

    if (Platform.isLinux) {
      return const SurfaceBootstrapPlan(
        backend: SurfaceBackend.x11,
        summary:
            'Linux will start from an X11-oriented surface plan until the Flutter runner display backend is confirmed.',
        nextSteps: [
          'Inspect the Linux runner to confirm X11 or Wayland availability.',
          'Bridge the native window handle into the Vulkan bootstrap layer.',
        ],
      );
    }

    return const SurfaceBootstrapPlan(
      backend: SurfaceBackend.unsupported,
      summary: 'The current platform is outside the desktop Vulkan setup scope.',
      nextSteps: <String>[],
      requiresNativeBridge: false,
    );
  }
}
