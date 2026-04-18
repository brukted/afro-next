import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/material_graph/material_graph_controller.dart';
import '../../features/workspace/workspace_controller.dart';
import '../../shared/ids/id_factory.dart';
import '../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../vulkan/ffi/vulkan_package_probe.dart';
import '../../vulkan/platform/platform_surface_bridge.dart';
import '../../vulkan/renderer/placeholder_renderer.dart';
import '../../vulkan/renderer/renderer_facade.dart';
import '../filesystem/app_file_picker.dart';
import '../filesystem/app_paths.dart';
import '../filesystem/workspace_file_store.dart';
import '../logging/app_logger.dart';
import '../preferences/app_preferences.dart';
import '../windowing/desktop_window_service.dart';

final serviceLocator = GetIt.instance;

Future<void> configureServiceLocator({
  required AppPaths appPaths,
  required SharedPreferences sharedPreferences,
  required AppLogger logger,
}) async {
  await serviceLocator.reset();

  serviceLocator
    ..registerSingleton<AppPaths>(appPaths)
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<AppPreferences>(AppPreferences(sharedPreferences))
    ..registerLazySingleton<AppFilePicker>(() => const AppFilePicker())
    ..registerLazySingleton<WorkspaceFileStore>(() => const WorkspaceFileStore())
    ..registerLazySingleton<DesktopWindowService>(() => DesktopWindowService())
    ..registerLazySingleton<IdFactory>(() => IdFactory())
    ..registerLazySingleton<PlatformSurfaceBridge>(
      PlatformSurfaceBridge.current,
    )
    ..registerLazySingleton<VulkanPackageProbe>(() => VulkanPackageProbe())
    ..registerLazySingleton<VulkanBootstrapper>(
      () => VulkanBootstrapper(
        packageProbe: serviceLocator<VulkanPackageProbe>(),
        platformSurfaceBridge: serviceLocator<PlatformSurfaceBridge>(),
      ),
    )
    ..registerLazySingleton<RendererFacade>(
      () => PlaceholderVulkanRendererFacade(
        bootstrapper: serviceLocator<VulkanBootstrapper>(),
      ),
    )
    ..registerLazySingleton<MaterialGraphController>(
      () => MaterialGraphController(
        idFactory: serviceLocator<IdFactory>(),
        renderer: serviceLocator<RendererFacade>(),
      ),
    )
    ..registerLazySingleton<WorkspaceController>(
      () => WorkspaceController(
        idFactory: serviceLocator<IdFactory>(),
        preferences: serviceLocator<AppPreferences>(),
        filePicker: serviceLocator<AppFilePicker>(),
        logger: serviceLocator<AppLogger>(),
        fileStore: serviceLocator<WorkspaceFileStore>(),
      ),
    );
}
