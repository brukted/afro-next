import 'package:flutter/material.dart';

import '../features/workspace/workspace_screen.dart';
import 'startup/app_bootstrap.dart';
import 'theme/app_theme.dart';

class EyecandyApp extends StatelessWidget {
  const EyecandyApp({
    super.key,
    required this.bootstrap,
  });

  final AppBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyecandy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: WorkspaceScreen(
        workspaceController: bootstrap.workspaceController,
        materialGraphController: bootstrap.materialGraphController,
        mathGraphController: bootstrap.mathGraphController,
      ),
    );
  }
}
