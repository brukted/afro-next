import '../../features/material_graph/material_graph_controller.dart';
import '../../features/workspace/workspace_controller.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.workspaceController,
    required this.materialGraphController,
  });

  final WorkspaceController workspaceController;
  final MaterialGraphController materialGraphController;

  factory AppBootstrap.preview() {
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview();
    final materialGraphController = MaterialGraphController.preview();
    return AppBootstrap(
      workspaceController: workspaceController,
      materialGraphController: materialGraphController,
    );
  }
}
