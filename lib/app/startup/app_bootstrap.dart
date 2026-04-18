import '../../features/workspace/workspace_controller.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.workspaceController,
  });

  final WorkspaceController workspaceController;

  factory AppBootstrap.preview() {
    final controller = WorkspaceController.preview()..initializeForPreview();
    return AppBootstrap(workspaceController: controller);
  }
}
