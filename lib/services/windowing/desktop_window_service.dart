import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowService {
  Future<void> initialize() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: 'Eyecandy',
      size: Size(1440, 920),
      minimumSize: Size(1100, 720),
      center: true,
      backgroundColor: Color(0xFF0F1015),
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
