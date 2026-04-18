import '../../features/graph/models/graph_bindings.dart';
import '../../features/graph/models/graph_models.dart';
import '../../features/material_graph/material_node_definition.dart';
import '../../shared/colors/vector4_color_adapter.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../resources/preview_render_target.dart';
import 'renderer_facade.dart';

class PlaceholderVulkanRendererFacade implements RendererFacade {
  const PlaceholderVulkanRendererFacade({
    required this.bootstrapper,
  });

  final VulkanBootstrapper bootstrapper;

  @override
  Future<RendererBootstrapState> bootstrap() => bootstrapper.bootstrap();

  @override
  PreviewRenderTarget renderNodePreview({
    required MaterialNodeDefinition definition,
    required GraphNodeDocument node,
    required List<GraphPropertyBinding> bindings,
    required int revision,
    required bool isDirty,
  }) {
    final primaryProperty =
        bindings.where((property) => property.isEditable).firstOrNull;
    final label = isDirty ? 'Dirty preview' : 'Ready';
    final diagnostics = <String>[
      'Definition: ${definition.label}',
      'Revision: $revision',
      if (primaryProperty != null) 'Primary property: ${primaryProperty.label}',
    ];

    return PreviewRenderTarget(
      id: node.id,
      kind: PreviewRenderTargetKind.placeholder,
      label: label,
      accentColor: Vector4ColorAdapter.toFlutterColor(definition.accentColor),
      diagnostics: diagnostics,
    );
  }
}

class PreviewOnlyRendererFacade implements RendererFacade {
  const PreviewOnlyRendererFacade();

  @override
  Future<RendererBootstrapState> bootstrap() async {
    return const RendererBootstrapState.preview();
  }

  @override
  PreviewRenderTarget renderNodePreview({
    required MaterialNodeDefinition definition,
    required GraphNodeDocument node,
    required List<GraphPropertyBinding> bindings,
    required int revision,
    required bool isDirty,
  }) {
    return PreviewRenderTarget(
      id: node.id,
      kind: PreviewRenderTargetKind.placeholder,
      label: 'Preview',
      accentColor: Vector4ColorAdapter.toFlutterColor(definition.accentColor),
      diagnostics: <String>[
        'Definition: ${definition.label}',
        'Revision: $revision',
      ],
    );
  }
}

extension on Iterable<GraphPropertyBinding> {
  GraphPropertyBinding? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
