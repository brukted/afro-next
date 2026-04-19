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
import 'material_node_definition.dart';
import 'material_output_size.dart';
import 'runtime/material_graph_compiler.dart';
import 'runtime/material_execution_ir.dart';
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
  ValueChanged<MaterialOutputSizeSettings>? _onGraphOutputSizeSettingsChanged;
  MaterialOutputSizeSettings _graphOutputSizeSettings =
      const MaterialOutputSizeSettings();
  MaterialOutputSizeValue _sessionParentOutputSize =
      const MaterialOutputSizeValue.parentDefault();
  String? _selectedNodeId;
  PendingSocketConnection? _pendingConnection;

  bool get isInitialized => _runtime.isInitialized;

  bool get hasGraph => _graph != null;

  String? get graphId => _graph?.id;

  RendererBootstrapState get rendererState => _runtime.rendererState;

  List<MaterialNodeDefinition> get nodeDefinitions => _catalog.definitions;

  GraphDocument get graph => _graph!;

  MaterialOutputSizeSettings get graphOutputSizeSettings =>
      _graphOutputSizeSettings;

  MaterialOutputSizeValue get sessionParentOutputSize =>
      _sessionParentOutputSize;

  MaterialResolvedOutputSize? get resolvedGraphOutputSize =>
      _runtime.compiledGraph?.resolvedGraphOutputSize;

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
    MaterialOutputSizeSettings graphOutputSizeSettings =
        const MaterialOutputSizeSettings(),
    required ValueChanged<GraphDocument> onChanged,
    ValueChanged<MaterialOutputSizeSettings>? onGraphOutputSizeSettingsChanged,
  }) {
    final graphChanged = _graph?.id != graph.id;
    _graph = graph;
    _onGraphChanged = onChanged;
    _graphOutputSizeSettings = graphOutputSizeSettings;
    _onGraphOutputSizeSettingsChanged = onGraphOutputSizeSettingsChanged;
    if (graphChanged) {
      _selectedNodeId = null;
      _pendingConnection = null;
    }
    _runtime.bindGraph(
      graph,
      graphOutputSizeSettings: _graphOutputSizeSettings,
      sessionParentOutputSize: _sessionParentOutputSize,
    );
    notifyListeners();
  }

  void clearGraph() {
    _graph = null;
    _onGraphChanged = null;
    _onGraphOutputSizeSettingsChanged = null;
    _graphOutputSizeSettings = const MaterialOutputSizeSettings();
    _selectedNodeId = null;
    _pendingConnection = null;
    _runtime.clearGraph();
    notifyListeners();
  }

  void updateGraphOutputSizeSettings(MaterialOutputSizeSettings settings) {
    _graphOutputSizeSettings = settings;
    _onGraphOutputSizeSettingsChanged?.call(settings);
    _refreshAllNodeOutputSizes();
    notifyListeners();
  }

  void updateGraphOutputSizeMode(MaterialOutputSizeMode mode) {
    final currentResolved = resolvedGraphOutputSize;
    final inherited = MaterialResolvedOutputSize.fromLog2(
      _sessionParentOutputSize,
    );
    final nextValue = switch (mode) {
      MaterialOutputSizeMode.absolute => _log2ValueFromResolved(
        currentResolved ?? inherited,
      ),
      MaterialOutputSizeMode.relativeToInput ||
      MaterialOutputSizeMode.relativeToParent => _deltaFromResolved(
        resolved: currentResolved ?? inherited,
        inherited: inherited,
      ),
    };
    updateGraphOutputSizeSettings(
      _graphOutputSizeSettings.copyWith(mode: mode, value: nextValue),
    );
  }

  void updateGraphOutputSizeValue(MaterialOutputSizeValue value) {
    updateGraphOutputSizeSettings(
      _graphOutputSizeSettings.copyWith(
        value: _graphOutputSizeSettings.normalizeValue(value),
      ),
    );
  }

  void updateSessionParentOutputSize(MaterialOutputSizeValue value) {
    _sessionParentOutputSize = value.clampAbsolute();
    _refreshAllNodeOutputSizes();
    notifyListeners();
  }

  MaterialOutputSizeSettings outputSizeSettingsForNode(GraphNodeDocument node) {
    return materialOutputSizeSettingsFromStorage(
      modeValue: node
          .propertyByDefinitionKey(materialNodeOutputSizeModeKey)
          ?.value
          .enumValue,
      value: node
          .propertyByDefinitionKey(materialNodeOutputSizeValueKey)
          ?.value
          .integerValues,
    );
  }

  MaterialResolvedOutputSize? resolvedOutputSizeForNode(String nodeId) {
    return _runtime.compiledGraph?.passForNode(nodeId)?.resolvedOutputSize;
  }

  void updateNodeOutputSizeMode({
    required String nodeId,
    required MaterialOutputSizeMode mode,
  }) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }
    final definition = definitionForNode(node);
    final currentResolved =
        resolvedOutputSizeForNode(nodeId) ?? _fallbackResolvedSize;
    final inherited = _resolvedInheritedOutputSize(
      node: node,
      definition: definition,
      mode: mode,
    );
    final nextValue = inherited == null
        ? _log2ValueFromResolved(currentResolved)
        : _deltaFromResolved(resolved: currentResolved, inherited: inherited);
    _updateNodeOutputSizeSettings(
      node: node,
      settings: MaterialOutputSizeSettings(mode: mode, value: nextValue),
    );
  }

  void updateNodeOutputSizeValue({
    required String nodeId,
    required MaterialOutputSizeValue value,
  }) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }
    final settings = outputSizeSettingsForNode(node);
    _updateNodeOutputSizeSettings(
      node: node,
      settings: settings.copyWith(value: settings.normalizeValue(value)),
    );
  }

  bool updateOutputSizeProperty({
    required String nodeId,
    required String propertyKey,
    required GraphValueData value,
  }) {
    switch (propertyKey) {
      case materialNodeOutputSizeModeKey:
        updateNodeOutputSizeMode(
          nodeId: nodeId,
          mode: materialOutputSizeModeFromEnumValue(value.enumValue ?? 0),
        );
        return true;
      case materialNodeOutputSizeValueKey:
        updateNodeOutputSizeValue(
          nodeId: nodeId,
          value: MaterialOutputSizeValue.fromInteger2(
            value.integerValues ?? const <int>[0, 0],
          ),
        );
        return true;
      default:
        return false;
    }
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
      Vector2(760 + (matchingNodeCount * 42), 560 + (matchingNodeCount * 34)),
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
            .where(
              (link) => link.fromNodeId != nodeId && link.toNodeId != nodeId,
            )
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
            .where(
              (link) => link.fromNodeId != nodeId && link.toNodeId != nodeId,
            )
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

    final definition = definitionForNode(
      node,
    ).propertyDefinition(property.definitionKey);
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

    final removedLink = graph.links.firstWhereOrNull(
      (link) => link.id == linkId,
    );
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

  void disconnectSocket({required String nodeId, required String propertyId}) {
    if (!hasGraph) {
      return;
    }

    final node = nodeById(nodeId);
    if (node == null || node.propertyById(propertyId) == null) {
      return;
    }

    final linksToRemove = graph.links
        .where(
          (link) =>
              link.fromPropertyId == propertyId ||
              link.toPropertyId == propertyId,
        )
        .toList(growable: false);
    if (linksToRemove.isEmpty) {
      return;
    }

    if (_pendingConnection?.propertyId == propertyId) {
      _pendingConnection = null;
    }

    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where(
              (link) =>
                  link.fromPropertyId != propertyId &&
                  link.toPropertyId != propertyId,
            )
            .toList(growable: false),
      ),
      dirtyRootNodeIds: linksToRemove.map((link) => link.toNodeId).toSet(),
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
    final current =
        node.propertyById(propertyId)?.value.asFloat4() ?? Vector4.zero();
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

  PreviewRenderTarget? previewForNode(String nodeId) =>
      _runtime.previewForNode(nodeId);

  bool hasIncomingLink(String propertyId) {
    return graph.links.any((link) => link.toPropertyId == propertyId);
  }

  bool hasOutgoingLink(String propertyId) {
    return graph.links.any((link) => link.fromPropertyId == propertyId);
  }

  MaterialResolvedOutputSize? _resolvedPrimaryInputOutputSize(
    GraphNodeDocument node,
    MaterialNodeDefinition definition,
  ) {
    final primaryInputKey = definition.resolvedPrimaryInputPropertyKey;
    if (primaryInputKey == null) {
      return null;
    }
    final primaryInputProperty = node.propertyByDefinitionKey(primaryInputKey);
    if (primaryInputProperty == null) {
      return null;
    }
    final link = graph.links.firstWhereOrNull(
      (entry) => entry.toPropertyId == primaryInputProperty.id,
    );
    if (link == null) {
      return null;
    }
    return resolvedOutputSizeForNode(link.fromNodeId);
  }

  MaterialResolvedOutputSize get _fallbackResolvedSize =>
      resolvedGraphOutputSize ??
      MaterialResolvedOutputSize.fromLog2(_sessionParentOutputSize);

  void _refreshAllNodeOutputSizes() {
    if (!hasGraph) {
      return;
    }
    _runtime.updateGraph(
      graph,
      graphOutputSizeSettings: _graphOutputSizeSettings,
      sessionParentOutputSize: _sessionParentOutputSize,
      dirtyRootNodeIds: graph.nodes.map((node) => node.id),
    );
  }

  MaterialResolvedOutputSize? _resolvedInheritedOutputSize({
    required GraphNodeDocument node,
    required MaterialNodeDefinition definition,
    required MaterialOutputSizeMode mode,
  }) {
    return switch (mode) {
      MaterialOutputSizeMode.absolute => null,
      MaterialOutputSizeMode.relativeToParent => _fallbackResolvedSize,
      MaterialOutputSizeMode.relativeToInput =>
        _resolvedPrimaryInputOutputSize(node, definition) ??
            _fallbackResolvedSize,
    };
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
          (property) => property.id == propertyId
              ? property.copyWith(value: value)
              : property,
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

  void _updateNodeOutputSizeSettings({
    required GraphNodeDocument node,
    required MaterialOutputSizeSettings settings,
  }) {
    final updatedProperties = node.properties
        .map((property) {
          if (property.definitionKey == materialNodeOutputSizeModeKey) {
            return property.copyWith(
              value: GraphValueData.enumChoice(
                materialOutputSizeModeEnumValue(settings.mode),
              ),
            );
          }
          if (property.definitionKey == materialNodeOutputSizeValueKey) {
            return property.copyWith(
              value: GraphValueData.integer2(settings.value.asInteger2),
            );
          }
          return property;
        })
        .toList(growable: false);
    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == node.id
                  ? entry.copyWith(properties: updatedProperties)
                  : entry,
            )
            .toList(growable: false),
      ),
      dirtyRootNodeIds: [node.id],
    );
  }

  MaterialOutputSizeValue _log2ValueFromResolved(
    MaterialResolvedOutputSize resolved,
  ) {
    return MaterialOutputSizeValue(
      widthLog2: resolved.widthLog2,
      heightLog2: resolved.heightLog2,
    );
  }

  MaterialOutputSizeValue _deltaFromResolved({
    required MaterialResolvedOutputSize resolved,
    required MaterialResolvedOutputSize inherited,
  }) {
    return MaterialOutputSizeValue(
      widthLog2: resolved.widthLog2 - inherited.widthLog2,
      heightLog2: resolved.heightLog2 - inherited.heightLog2,
    ).clampRelative();
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
      graphOutputSizeSettings: _graphOutputSizeSettings,
      sessionParentOutputSize: _sessionParentOutputSize,
      dirtyRootNodeIds: dirtyRootNodeIds,
      refreshPreviews: refreshPreviews,
    );
    notifyListeners();
  }

  void _handleRuntimeChanged() {
    notifyListeners();
  }
}
