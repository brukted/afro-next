import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/ids/id_factory.dart';
import '../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../vulkan/renderer/placeholder_renderer.dart';
import '../../vulkan/resources/preview_render_target.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'material_graph_catalog.dart';
import 'material_graph_migration.dart';
import 'material_node_definition.dart';
import 'runtime/material_graph_compiler.dart';
import 'runtime/material_graph_runtime.dart';

class PendingSocketConnection {
  const PendingSocketConnection({
    required this.nodeId,
    required this.propertyId,
    required this.direction,
  });

  final String nodeId;
  final String propertyId;
  final GraphSocketDirection direction;
}

class MaterialGraphController extends ChangeNotifier {
  MaterialGraphController({
    required IdFactory idFactory,
    required MaterialGraphCatalog catalog,
    required MaterialGraphRuntime runtime,
  }) : _idFactory = idFactory,
       _catalog = catalog,
       _runtime = runtime {
    _runtime.addListener(_handleRuntimeChanged);
  }

  factory MaterialGraphController.preview() {
    final idFactory = IdFactory();
    final catalog = MaterialGraphCatalog(idFactory);
    return MaterialGraphController(
      idFactory: idFactory,
      catalog: catalog,
      runtime: MaterialGraphRuntime(
        compiler: MaterialGraphCompiler(catalog: catalog),
        renderer: const PreviewOnlyRendererFacade(),
      ),
    );
  }

  final IdFactory _idFactory;
  final MaterialGraphCatalog _catalog;
  final MaterialGraphRuntime _runtime;

  GraphDocument? _graph;
  ValueChanged<GraphDocument>? _onGraphChanged;
  String? _selectedNodeId;
  PendingSocketConnection? _pendingConnection;

  bool get isInitialized => _runtime.isInitialized;

  bool get hasGraph => _graph != null;

  String? get graphId => _graph?.id;

  RendererBootstrapState get rendererState => _runtime.rendererState;

  List<MaterialNodeDefinition> get nodeDefinitions => _catalog.definitions;

  GraphDocument get graph => _graph!;

  String? get selectedNodeId => _selectedNodeId;

  PendingSocketConnection? get pendingConnection => _pendingConnection;

  GraphNodeDocument? get selectedNode {
    if (_selectedNodeId == null || _graph == null) {
      return null;
    }

    return graph.nodes.firstWhereOrNull((node) => node.id == _selectedNodeId);
  }

  GraphNodeDocument? nodeById(String nodeId) {
    if (!hasGraph) {
      return null;
    }

    return graph.nodes.firstWhereOrNull((node) => node.id == nodeId);
  }

  Future<void> initialize() async {
    await _runtime.initialize();
  }

  @override
  void dispose() {
    _runtime.removeListener(_handleRuntimeChanged);
    super.dispose();
  }

  void bindGraph({
    required GraphDocument graph,
    required ValueChanged<GraphDocument> onChanged,
  }) {
    final normalizedGraph = MaterialGraphMigration.normalize(graph);
    final graphChanged = _graph?.id != normalizedGraph.id;
    _graph = normalizedGraph;
    _onGraphChanged = onChanged;
    if (graphChanged) {
      _selectedNodeId = null;
      _pendingConnection = null;
    }
    if (!identical(normalizedGraph, graph)) {
      onChanged(normalizedGraph);
    }
    _runtime.bindGraph(normalizedGraph);
    notifyListeners();
  }

  void clearGraph() {
    _graph = null;
    _onGraphChanged = null;
    _selectedNodeId = null;
    _pendingConnection = null;
    _runtime.clearGraph();
    notifyListeners();
  }

  void selectNode(String? nodeId) {
    if (_selectedNodeId == nodeId) {
      return;
    }

    _selectedNodeId = nodeId;
    notifyListeners();
  }

  void addNode(String definitionId) {
    final matchingNodeCount = hasGraph
        ? graph.nodes.where((node) => node.definitionId == definitionId).length
        : 0;
    addNodeAt(
      definitionId,
      Vector2(
        760 + (matchingNodeCount * 42),
        560 + (matchingNodeCount * 34),
      ),
    );
  }

  void addNodeAt(String definitionId, Vector2 position) {
    if (!hasGraph) {
      return;
    }

    final matchingNodeCount = graph.nodes
        .where((node) => node.definitionId == definitionId)
        .length;

    final node = _catalog.instantiateNode(
      definitionId: definitionId,
      position: position,
      sequence: matchingNodeCount + 1,
    );

    _selectedNodeId = node.id;
    _commitGraph(
      graph.copyWith(nodes: [...graph.nodes, node]),
      dirtyRootNodeIds: [node.id],
    );
  }

  void duplicateNode(String nodeId) {
    final source = nodeById(nodeId);
    if (source == null) {
      return;
    }

    final duplicatedNode = GraphNodeDocument(
      id: _idFactory.next(),
      definitionId: source.definitionId,
      name: _nextDuplicateName(source.name),
      position: source.position + Vector2(40, 32),
      properties: source.properties
          .map(
            (property) => GraphNodePropertyData(
              id: _idFactory.next(),
              definitionKey: property.definitionKey,
              value: property.value.deepCopy(),
            ),
          )
          .toList(growable: false),
    );

    _selectedNodeId = duplicatedNode.id;
    _commitGraph(
      graph.copyWith(nodes: [...graph.nodes, duplicatedNode]),
      dirtyRootNodeIds: [duplicatedNode.id],
    );
  }

  void deleteNode(String nodeId) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }

    final linksToRemove = graph.links
        .where((link) => link.fromNodeId == nodeId || link.toNodeId == nodeId)
        .toList(growable: false);
    final dirtyRootNodeIds = linksToRemove
        .where((entry) => entry.fromNodeId == nodeId)
        .map((link) => link.toNodeId)
        .toSet();

    if (_pendingConnection?.nodeId == nodeId) {
      _pendingConnection = null;
    }
    if (_selectedNodeId == nodeId) {
      _selectedNodeId = null;
    }
    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .where((entry) => entry.id != nodeId)
            .toList(growable: false),
        links: graph.links
            .where((link) => link.fromNodeId != nodeId && link.toNodeId != nodeId)
            .toList(growable: false),
      ),
      dirtyRootNodeIds: dirtyRootNodeIds,
    );
  }

  void disconnectNode(String nodeId) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }

    final linksToRemove = graph.links
        .where((link) => link.fromNodeId == nodeId || link.toNodeId == nodeId)
        .toList(growable: false);
    if (linksToRemove.isEmpty) {
      return;
    }

    final dirtyRootNodeIds = <String>{
      nodeId,
      ...linksToRemove
          .where((entry) => entry.fromNodeId == nodeId)
          .map((link) => link.toNodeId),
    };

    if (_pendingConnection?.nodeId == nodeId) {
      _pendingConnection = null;
    }

    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where((link) => link.fromNodeId != nodeId && link.toNodeId != nodeId)
            .toList(growable: false),
      ),
      dirtyRootNodeIds: dirtyRootNodeIds,
    );
  }

  void setNodePosition(String nodeId, Vector2 position) {
    if (!hasGraph) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(position: position)
                  : entry,
            )
            .toList(growable: false),
      ),
      refreshPreviews: false,
    );
  }

  void handleSocketTap({required String nodeId, required String propertyId}) {
    if (!hasGraph) {
      return;
    }

    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final property = node.propertyById(propertyId);
    if (property == null) {
      return;
    }

    final definition = definitionForNode(node).propertyDefinition(
      property.definitionKey,
    );
    final direction = definition.socketDirection;
    if (direction == null) {
      return;
    }

    if (_pendingConnection == null) {
      if (direction == GraphSocketDirection.output) {
        _pendingConnection = PendingSocketConnection(
          nodeId: nodeId,
          propertyId: propertyId,
          direction: direction,
        );
        notifyListeners();
      }
      return;
    }

    final pendingConnection = _pendingConnection!;
    if (pendingConnection.propertyId == propertyId) {
      _pendingConnection = null;
      notifyListeners();
      return;
    }

    if (pendingConnection.direction == direction) {
      if (direction == GraphSocketDirection.output) {
        _pendingConnection = PendingSocketConnection(
          nodeId: nodeId,
          propertyId: propertyId,
          direction: direction,
        );
        notifyListeners();
      }
      return;
    }

    if (direction == GraphSocketDirection.input) {
      _connectProperties(
        fromNodeId: pendingConnection.nodeId,
        fromPropertyId: pendingConnection.propertyId,
        toNodeId: nodeId,
        toPropertyId: propertyId,
      );
      return;
    }

    _connectProperties(
      fromNodeId: nodeId,
      fromPropertyId: propertyId,
      toNodeId: pendingConnection.nodeId,
      toPropertyId: pendingConnection.propertyId,
    );
  }

  void cancelPendingConnection() {
    if (_pendingConnection == null) {
      return;
    }

    _pendingConnection = null;
    notifyListeners();
  }

  void removeLink(String linkId) {
    if (!hasGraph) {
      return;
    }

    final removedLink = graph.links.firstWhereOrNull((link) => link.id == linkId);
    if (removedLink == null) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where((link) => link.id != linkId)
            .toList(growable: false),
      ),
      dirtyRootNodeIds: [removedLink.toNodeId],
    );
  }

  void updateFloatProperty({
    required String nodeId,
    required String propertyId,
    required double value,
  }) {
    updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.float(value),
    );
  }

  void updateEnumProperty({
    required String nodeId,
    required String propertyId,
    required int value,
  }) {
    updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.enumChoice(value),
    );
  }

  void updateColorProperty({
    required String nodeId,
    required String propertyId,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final current = node.propertyById(propertyId)?.value.asFloat4() ?? Vector4.zero();
    updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.float4(
        Vector4ColorAdapter.withChannel(
          current,
          red: red,
          green: green,
          blue: blue,
          alpha: alpha,
        ),
      ),
    );
  }

  void updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required GraphValueData value,
  }) {
    _updatePropertyValue(nodeId: nodeId, propertyId: propertyId, value: value);
  }

  MaterialNodeDefinition definitionForNode(GraphNodeDocument node) {
    return _catalog.definitionById(node.definitionId);
  }

  List<GraphPropertyBinding> boundPropertiesForNode(GraphNodeDocument node) {
    final definition = definitionForNode(node);
    return definition.properties
        .map((propertyDefinition) {
          final property = node.properties.firstWhere(
            (entry) => entry.definitionKey == propertyDefinition.key,
          );
          return GraphPropertyBinding(
            property: property,
            definition: propertyDefinition,
          );
        })
        .toList(growable: false);
  }

  PreviewRenderTarget? previewForNode(String nodeId) => _runtime.previewForNode(nodeId);

  bool hasIncomingLink(String propertyId) {
    return graph.links.any((link) => link.toPropertyId == propertyId);
  }

  bool hasOutgoingLink(String propertyId) {
    return graph.links.any((link) => link.fromPropertyId == propertyId);
  }

  void _connectProperties({
    required String fromNodeId,
    required String fromPropertyId,
    required String toNodeId,
    required String toPropertyId,
  }) {
    final filteredLinks = graph.links
        .where((link) {
          if (link.toPropertyId == toPropertyId) {
            return false;
          }

          final duplicatesSameDirection =
              link.fromPropertyId == fromPropertyId &&
              link.toPropertyId == toPropertyId;
          return !duplicatesSameDirection;
        })
        .toList(growable: true);

    filteredLinks.add(
      GraphLinkDocument(
        id: _idFactory.next(),
        fromNodeId: fromNodeId,
        fromPropertyId: fromPropertyId,
        toNodeId: toNodeId,
        toPropertyId: toPropertyId,
      ),
    );

    _pendingConnection = null;
    _commitGraph(
      graph.copyWith(links: filteredLinks),
      dirtyRootNodeIds: [fromNodeId],
    );
  }

  void _updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required GraphValueData value,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final updatedProperties = node.properties
        .map(
          (property) =>
              property.id == propertyId ? property.copyWith(value: value) : property,
        )
        .toList(growable: false);

    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(properties: updatedProperties)
                  : entry,
            )
            .toList(growable: false),
      ),
      dirtyRootNodeIds: [nodeId],
    );
  }

  String _nextDuplicateName(String baseName) {
    final takenNames = graph.nodes.map((node) => node.name).toSet();
    var index = 1;
    while (true) {
      final suffix = index == 1 ? ' Copy' : ' Copy $index';
      final candidate = '$baseName$suffix';
      if (!takenNames.contains(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  void _commitGraph(
    GraphDocument updatedGraph, {
    bool refreshPreviews = true,
    Iterable<String> dirtyRootNodeIds = const <String>[],
  }) {
    _graph = updatedGraph;
    _onGraphChanged?.call(updatedGraph);
    _runtime.updateGraph(
      updatedGraph,
      dirtyRootNodeIds: dirtyRootNodeIds,
      refreshPreviews: refreshPreviews,
    );
    notifyListeners();
  }

  void _handleRuntimeChanged() {
    notifyListeners();
  }
}
