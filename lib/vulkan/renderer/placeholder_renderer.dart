import '../../features/material_graph/models/material_graph_models.dart';
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
    required GraphNodeDefinition definition,
    required GraphNodeInstance node,
    required int revision,
  }) {
    final primaryProperty = node
        .bindProperties(definition)
        .where((property) => property.isEditable)
        .firstOrNull;
    final label = node.isDirty ? 'Dirty preview' : 'Ready';
    final diagnostics = <String>[
      'Definition: ${definition.label}',
      'Revision: $revision',
      if (primaryProperty != null) 'Primary property: ${primaryProperty.label}',
    ];

    return PreviewRenderTarget(
      id: node.id,
      kind: PreviewRenderTargetKind.placeholder,
      label: label,
      accentColor: definition.accentColor,
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
    required GraphNodeDefinition definition,
    required GraphNodeInstance node,
    required int revision,
  }) {
    return PreviewRenderTarget(
      id: node.id,
      kind: PreviewRenderTargetKind.placeholder,
      label: 'Preview',
      accentColor: definition.accentColor,
      diagnostics: <String>[
        'Definition: ${definition.label}',
        'Revision: $revision',
      ],
    );
  }
}

extension on Iterable<GraphNodePropertyView> {
  GraphNodePropertyView? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
