import '../../features/math_graph/math_graph_controller.dart';
import '../../features/material_graph/material_graph_controller.dart';
import '../../features/workspace/workspace_controller.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.workspaceController,
    required this.materialGraphController,
    required this.mathGraphController,
  });

  final WorkspaceController workspaceController;
  final MaterialGraphController materialGraphController;
  final MathGraphController mathGraphController;

  factory AppBootstrap.preview() {
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview();
    final materialGraphController = MaterialGraphController.preview();
    final mathGraphController = MathGraphController.preview();
    return AppBootstrap(
      workspaceController: workspaceController,
      materialGraphController: materialGraphController,
      mathGraphController: mathGraphController,
    );
  }
}
