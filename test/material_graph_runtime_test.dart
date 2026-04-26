import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:afro/features/material_graph/material_graph_catalog.dart';
import 'package:afro/features/material_graph/runtime/material_execution_ir.dart';
import 'package:afro/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:afro/features/material_graph/runtime/material_graph_runtime.dart';
import 'package:afro/shared/ids/id_factory.dart';
import 'package:afro/vulkan/bootstrap/vulkan_bootstrap.dart';
import 'package:afro/vulkan/renderer/renderer_facade.dart';
import 'package:afro/vulkan/resources/preview_render_target.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

void main() {
  test('runtime expands dirty roots through downstream nodes', () async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final renderer = _CapturingRenderer();
    final runtime = MaterialGraphRuntime(
      compiler: MaterialGraphCompiler(catalog: catalog),
      renderer: renderer,
    );

    runtime.bindGraph(graph);
    await Future<void>.delayed(Duration.zero);
    final solidColor = graph.nodes.firstWhere(
      (node) => node.definitionId == 'solid_color_node',
    );
    runtime.updateGraph(
      graph,
      dirtyRootNodeIds: [solidColor.id],
    );
    await Future<void>.delayed(Duration.zero);

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

  test('runtime ignores stale preview results from earlier revisions', () async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final renderer = _SequencedRenderer();
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

    await Future<void>.delayed(Duration.zero);
    expect(
      runtime.previewForNode(solidColor.id)?.diagnostics.first,
      'Revision: 2',
    );

    renderer.completeFirst();
    await Future<void>.delayed(Duration.zero);

    expect(
      runtime.previewForNode(solidColor.id)?.diagnostics.first,
      'Revision: 2',
    );
  });

  test('runtime keeps compiled graph current when preview refresh is skipped', () async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final renderer = _CapturingRenderer();
    final runtime = MaterialGraphRuntime(
      compiler: MaterialGraphCompiler(catalog: catalog),
      renderer: renderer,
    );

    runtime.bindGraph(graph);
    await Future<void>.delayed(Duration.zero);

    final extraNode = catalog.instantiateNode(
      definitionId: 'solid_color_node',
      position: Vector2(48, 48),
      sequence: 2,
    );
    final updatedGraph = graph.copyWith(nodes: [...graph.nodes, extraNode]);

    runtime.updateGraph(updatedGraph, refreshPreviews: false);
    await Future<void>.delayed(Duration.zero);

    expect(runtime.compiledGraph?.passForNode(extraNode.id), isNotNull);
    expect(renderer.renderCallCount, 1);
  });
}

class _CapturingRenderer implements RendererFacade {
  Set<String> lastDirtyNodeIds = <String>{};
  int renderCallCount = 0;

  @override
  Future<RendererBootstrapState> bootstrap() async {
    return const RendererBootstrapState.preview();
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<Map<String, PreviewRenderTarget>> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) async {
    renderCallCount += 1;
    lastDirtyNodeIds = dirtyNodeIds;
    return {
      for (final pass in graph.nodePasses)
        pass.nodeId: PreviewRenderTarget(
          id: pass.nodeId,
          kind: PreviewRenderTargetKind.placeholder,
          label: dirtyNodeIds.contains(pass.nodeId) ? 'Dirty' : 'Ready',
          diagnostics: ['Revision: $revision'],
        ),
    };
  }

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {}
}

class _SequencedRenderer implements RendererFacade {
  final Completer<Map<String, PreviewRenderTarget>> _firstCompleter =
      Completer<Map<String, PreviewRenderTarget>>();
  var _callCount = 0;
  MaterialCompiledGraph? _firstGraph;

  @override
  Future<RendererBootstrapState> bootstrap() async {
    return const RendererBootstrapState.preview();
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<Map<String, PreviewRenderTarget>> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) {
    _callCount += 1;
    if (_callCount == 1) {
      _firstGraph = graph;
      return _firstCompleter.future;
    }

    return Future.value(_targetsFor(graph: graph, revision: revision));
  }

  void completeFirst() {
    if (_firstCompleter.isCompleted || _firstGraph == null) {
      return;
    }
    _firstCompleter.complete(_targetsFor(graph: _firstGraph!, revision: 1));
  }

  Map<String, PreviewRenderTarget> _targetsFor({
    required MaterialCompiledGraph graph,
    required int revision,
  }) {
    return {
      for (final pass in graph.nodePasses)
        pass.nodeId: PreviewRenderTarget(
          id: pass.nodeId,
          kind: PreviewRenderTargetKind.placeholder,
          label: 'Ready',
          diagnostics: ['Revision: $revision'],
        ),
    };
  }

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {}
}
