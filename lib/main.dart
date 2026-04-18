import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/startup/app_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await AppStartup.initialize();
  runApp(EyecandyApp(bootstrap: bootstrap));
}
