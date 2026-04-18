import 'package:shared_preferences/shared_preferences.dart';

import '../../features/workspace/workspace_controller.dart';
import '../../services/di/service_locator.dart';
import '../../services/filesystem/app_paths.dart';
import '../../services/logging/app_logger.dart';
import '../../services/windowing/desktop_window_service.dart';
import 'app_bootstrap.dart';

class AppStartup {
  static Future<AppBootstrap> initialize() async {
    final appPaths = await AppPaths.initialize();
    final sharedPreferences = await SharedPreferences.getInstance();
    final logger = await AppLogger.bootstrap(logsDirectory: appPaths.logsDirectory);

    await configureServiceLocator(
      appPaths: appPaths,
      sharedPreferences: sharedPreferences,
      logger: logger,
    );

    await serviceLocator<DesktopWindowService>().initialize();

    final workspaceController = serviceLocator<WorkspaceController>();
    await workspaceController.initialize();

    logger.info('Eyecandy startup completed.');

    return AppBootstrap(workspaceController: workspaceController);
  }
}
