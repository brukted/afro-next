import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/runtime/material_execution_ir.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_runtime.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:eyecandy/vulkan/bootstrap/vulkan_bootstrap.dart';
import 'package:eyecandy/vulkan/renderer/renderer_facade.dart';
import 'package:eyecandy/vulkan/resources/preview_render_target.dart';

void main() {
  test('runtime expands dirty roots through downstream nodes', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final renderer = _CapturingRenderer();
    final runtime = MaterialGraphRuntime(
      compiler: MaterialGraphCompiler(catalog: catalog),
      renderer: renderer,
    );

    runtime.bindGraph(graph);
    final solidColor = graph.nodes.firstWhere(
      (node) => node.definitionId == 'solid_color_node',
    );
    runtime.updateGraph(
      graph,
      dirtyRootNodeIds: [solidColor.id],
    );

    final mixNode = graph.nodes.firstWhere((node) => node.definitionId == 'mix_node');
    final channelSelectNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'channel_select_node',
    );
    final circleNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'circle_node',
    );

    expect(renderer.lastDirtyNodeIds, contains(solidColor.id));
    expect(renderer.lastDirtyNodeIds, contains(mixNode.id));
    expect(renderer.lastDirtyNodeIds, contains(channelSelectNode.id));
    expect(renderer.lastDirtyNodeIds, isNot(contains(circleNode.id)));
    expect(runtime.previewForNode(mixNode.id)?.label, 'Dirty');
    expect(runtime.previewForNode(circleNode.id)?.label, 'Ready');
  });
}

class _CapturingRenderer implements RendererFacade {
  Set<String> lastDirtyNodeIds = <String>{};

  @override
  Future<RendererBootstrapState> bootstrap() async {
    return const RendererBootstrapState.preview();
  }

  @override
  Map<String, PreviewRenderTarget> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) {
    lastDirtyNodeIds = dirtyNodeIds;
    return {
      for (final pass in graph.nodePasses)
        pass.nodeId: PreviewRenderTarget(
          id: pass.nodeId,
          kind: PreviewRenderTargetKind.placeholder,
          label: dirtyNodeIds.contains(pass.nodeId) ? 'Dirty' : 'Ready',
          accentColor: const Color(0xFF7D67FF),
          diagnostics: ['Revision: $revision'],
        ),
    };
  }
}
