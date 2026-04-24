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
import '../math_graph/math_graph_catalog.dart';
import '../math_graph/runtime/math_graph_compiler.dart';
import '../workspace/workspace_controller.dart';
import 'material_graph_catalog.dart';
import 'material_node_definition.dart';
import 'material_output_size.dart';
import 'material_socket_compatibility.dart';
import 'runtime/material_graph_backed_resolver.dart';
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

class _GraphSynchronizationResult {
  const _GraphSynchronizationResult({
    required this.graph,
    required this.changed,
  });

  final GraphDocument graph;
  final bool changed;
}

class _NodeSynchronizationResult {
  const _NodeSynchronizationResult({
    required this.node,
    required this.changed,
    required this.removedPropertyIds,
  });

  final GraphNodeDocument node;
  final bool changed;
  final Set<String> removedPropertyIds;
}

class MaterialGraphController extends ChangeNotifier {
  MaterialGraphController({
    required IdFactory idFactory,
    required MaterialGraphCatalog catalog,
    required MaterialGraphRuntime runtime,
    WorkspaceController? workspaceController,
    MathGraphCompiler? mathGraphCompiler,
  }) : _idFactory = idFactory,
       _catalog = catalog,
       _runtime = runtime,
       _resolver = MaterialGraphBackedNodeResolver(
         catalog: catalog,
         workspaceController: workspaceController,
         mathGraphCompiler: mathGraphCompiler,
       ) {
    _runtime.addListener(_handleRuntimeChanged);
  }

  factory MaterialGraphController.preview() {
    final idFactory = IdFactory();
    final catalog = MaterialGraphCatalog(idFactory);
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview();
    final mathGraphCompiler = MathGraphCompiler(
      catalog: MathGraphCatalog(IdFactory()),
    );
    return MaterialGraphController(
      idFactory: idFactory,
      catalog: catalog,
      workspaceController: workspaceController,
      mathGraphCompiler: mathGraphCompiler,
      runtime: MaterialGraphRuntime(
        compiler: MaterialGraphCompiler(
          catalog: catalog,
          workspaceController: workspaceController,
          mathGraphCompiler: mathGraphCompiler,
        ),
        renderer: const PreviewOnlyRendererFacade(),
      ),
    );
  }

  final IdFactory _idFactory;
  final MaterialGraphCatalog _catalog;
  final MaterialGraphRuntime _runtime;
  final MaterialGraphBackedNodeResolver _resolver;

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

  List<GraphNodeDocument> get graphInputNodes {
    if (!hasGraph) {
      return const <GraphNodeDocument>[];
    }
    return graph.nodes
        .where((node) => definitionForNode(node).isGraphInput)
        .toList(growable: false);
  }

  GraphValueUnit inputUnitForNode(GraphNodeDocument node) {
    final selectedUnit = node.inputUnit;
    if (selectedUnit != null) {
      return selectedUnit;
    }
    final inputValueKey = definitionForNode(node).inputValuePropertyKey;
    if (inputValueKey == null) {
      return GraphValueUnit.none;
    }
    return definitionForNode(node).propertyDefinition(inputValueKey).valueUnit;
  }

  List<GraphValueUnit> availableInputUnitsForNode(GraphNodeDocument node) {
    final inputValueKey = definitionForNode(node).inputValuePropertyKey;
    if (inputValueKey == null) {
      return const <GraphValueUnit>[GraphValueUnit.none];
    }
    return availableInputUnitsForDefinition(
      definitionForNode(node).propertyDefinition(inputValueKey),
    );
  }

  List<GraphValueUnit> availableInputUnitsForDefinition(
    GraphPropertyDefinition definition,
  ) {
    return switch (definition.valueType) {
      GraphValueType.integer => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.power2,
      ],
      GraphValueType.integer2 => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.position,
        GraphValueUnit.power2,
      ],
      GraphValueType.integer3 => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.position,
      ],
      GraphValueType.float => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.rotation,
      ],
      GraphValueType.float2 => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.position,
        GraphValueUnit.power2,
      ],
      GraphValueType.float3 => const <GraphValueUnit>[
        GraphValueUnit.none,
        GraphValueUnit.position,
        GraphValueUnit.color,
      ],
      GraphValueType.float4 when definition.valueUnit == GraphValueUnit.color =>
        const <GraphValueUnit>[GraphValueUnit.color],
      _ => <GraphValueUnit>[definition.valueUnit],
    };
  }

  String inputUnitLabel(GraphValueUnit unit) {
    return switch (unit) {
      GraphValueUnit.none => 'None',
      GraphValueUnit.rotation => 'Rotation',
      GraphValueUnit.position => 'Position',
      GraphValueUnit.power2 => 'Power of Two',
      GraphValueUnit.color => 'Color',
      GraphValueUnit.path => 'Path',
    };
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
    final synchronized = _synchronizeGraphBackedNodes(graph);
    _graph = synchronized.graph;
    _onGraphChanged = onChanged;
    _graphOutputSizeSettings = graphOutputSizeSettings;
    _onGraphOutputSizeSettingsChanged = onGraphOutputSizeSettingsChanged;
    if (graphChanged) {
      _selectedNodeId = null;
      _pendingConnection = null;
    }
    if (synchronized.changed) {
      onChanged(synchronized.graph);
    }
    _runtime.bindGraph(
      synchronized.graph,
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

  void renameNode(String nodeId, String name) {
    final node = nodeById(nodeId);
    final trimmedName = name.trim();
    if (node == null || trimmedName.isEmpty || node.name == trimmedName) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(name: trimmedName)
                  : entry,
            )
            .toList(growable: false),
      ),
      refreshPreviews: false,
    );
  }

  void updateInputUnit(String nodeId, GraphValueUnit unit) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }
    final definition = definitionForNode(node);
    if (!definition.isGraphInput) {
      return;
    }
    final supportedUnits = availableInputUnitsForNode(node);
    if (!supportedUnits.contains(unit)) {
      return;
    }
    if (node.inputUnit == unit) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(inputUnitId: unit.name)
                  : entry,
            )
            .toList(growable: false),
      ),
      refreshPreviews: false,
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
      inputUnitId: source.inputUnitId,
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

  bool canExposePropertyAsInput({
    required String nodeId,
    required GraphPropertyBinding property,
  }) {
    final node = nodeById(nodeId);
    if (node == null || definitionForNode(node).isGraphInput) {
      return false;
    }
    if (property.definition.propertyType != GraphPropertyType.input ||
        !property.definition.isSocket) {
      return false;
    }
    return _catalog.inputDefinitionIdForProperty(property.definition) != null;
  }

  void exposePropertyAsInput({
    required String nodeId,
    required String propertyId,
  }) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }
    final nodeDefinition = definitionForNode(node);
    if (nodeDefinition.isGraphInput) {
      return;
    }
    final property = node.propertyById(propertyId);
    if (property == null) {
      return;
    }
    final propertyDefinition = nodeDefinition.propertyDefinition(
      property.definitionKey,
    );
    final inputDefinitionId = _catalog.inputDefinitionIdForProperty(
      propertyDefinition,
    );
    if (inputDefinitionId == null ||
        propertyDefinition.propertyType != GraphPropertyType.input ||
        !propertyDefinition.isSocket) {
      return;
    }

    final matchingNodeCount = graph.nodes
        .where((entry) => entry.definitionId == inputDefinitionId)
        .length;
    final inputDefinition = _catalog.definitionById(inputDefinitionId);
    var inputNode = _catalog.instantiateNode(
      definitionId: inputDefinitionId,
      position: node.position + Vector2(-320, 0),
      sequence: matchingNodeCount + 1,
    );
    final inputValueKey = inputDefinition.inputValuePropertyKey;
    final nextName = _nextAvailableNodeName(
      '${propertyDefinition.label} Input',
    );
    inputNode = inputNode.copyWith(
      name: nextName,
      inputUnitId: propertyDefinition.valueUnit.name,
      properties: inputNode.properties
          .map((entry) {
            if (entry.definitionKey == inputValueKey) {
              return entry.copyWith(value: property.value.deepCopy());
            }
            return entry;
          })
          .toList(growable: false),
    );
    final outputProperty = inputNode.propertyByDefinitionKey('_output');
    if (outputProperty == null) {
      return;
    }
    final outputDefinition = inputDefinition.propertyDefinition('_output');
    if (!_canConnectResolvedProperties(
      fromNode: inputNode,
      fromProperty: outputProperty,
      fromDefinition: outputDefinition,
      toNode: node,
      toProperty: property,
      toDefinition: propertyDefinition,
    )) {
      return;
    }

    final nextLinks =
        graph.links
            .where((link) => link.toPropertyId != propertyId)
            .toList(growable: true)
          ..add(
            GraphLinkDocument(
              id: _idFactory.next(),
              fromNodeId: inputNode.id,
              fromPropertyId: outputProperty.id,
              toNodeId: node.id,
              toPropertyId: property.id,
            ),
          );

    _selectedNodeId = inputNode.id;
    _pendingConnection = null;
    _commitGraph(
      graph.copyWith(nodes: [...graph.nodes, inputNode], links: nextLinks),
      dirtyRootNodeIds: [inputNode.id, node.id],
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
    return _resolver.resolveNode(node).definition;
  }

  List<GraphPropertyBinding> boundPropertiesForNode(GraphNodeDocument node) {
    final definition = definitionForNode(node);
    return definition.properties
        .map((propertyDefinition) {
          final property =
              node.properties.firstWhereOrNull(
                (entry) => entry.definitionKey == propertyDefinition.key,
              ) ??
              GraphNodePropertyData(
                id: '${node.id}:${propertyDefinition.key}',
                definitionKey: propertyDefinition.key,
                value: _catalog.defaultValueForProperty(propertyDefinition),
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
    if (!_canConnectProperties(
      fromNodeId: fromNodeId,
      fromPropertyId: fromPropertyId,
      toNodeId: toNodeId,
      toPropertyId: toPropertyId,
    )) {
      return;
    }
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
      dirtyRootNodeIds: [fromNodeId, toNodeId],
    );
  }

  bool _canConnectProperties({
    required String fromNodeId,
    required String fromPropertyId,
    required String toNodeId,
    required String toPropertyId,
  }) {
    final fromNode = nodeById(fromNodeId);
    final toNode = nodeById(toNodeId);
    if (fromNode == null || toNode == null) {
      return false;
    }
    if (fromNode.id == toNode.id) {
      return false;
    }
    final fromProperty = fromNode.propertyById(fromPropertyId);
    final toProperty = toNode.propertyById(toPropertyId);
    if (fromProperty == null || toProperty == null) {
      return false;
    }
    final fromDefinition = definitionForNode(
      fromNode,
    ).propertyDefinition(fromProperty.definitionKey);
    final toDefinition = definitionForNode(
      toNode,
    ).propertyDefinition(toProperty.definitionKey);
    return _canConnectResolvedProperties(
      fromNode: fromNode,
      fromProperty: fromProperty,
      fromDefinition: fromDefinition,
      toNode: toNode,
      toProperty: toProperty,
      toDefinition: toDefinition,
    );
  }

  bool _canConnectResolvedProperties({
    required GraphNodeDocument fromNode,
    required GraphNodePropertyData fromProperty,
    required GraphPropertyDefinition fromDefinition,
    required GraphNodeDocument toNode,
    required GraphNodePropertyData toProperty,
    required GraphPropertyDefinition toDefinition,
  }) {
    if (!materialSocketDefinitionsCompatible(
      fromDefinition: fromDefinition,
      toDefinition: toDefinition,
    )) {
      return false;
    }
    if (toDefinition.socketTransport == GraphSocketTransport.texture) {
      return true;
    }
    final fromNodeDefinition = definitionForNode(fromNode);
    final sourceValueKey = fromNodeDefinition.inputValuePropertyKey;
    if (!fromNodeDefinition.isGraphInput || sourceValueKey == null) {
      return false;
    }
    final sourceValueProperty = fromNode.propertyByDefinitionKey(
      sourceValueKey,
    );
    return sourceValueProperty?.value.valueType == toDefinition.valueType;
  }

  void _updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required GraphValueData value,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final changedProperty = node.propertyById(propertyId);
    if (changedProperty == null) {
      return;
    }
    final updatedProperties = node.properties
        .map(
          (property) => property.id == propertyId
              ? property.copyWith(value: value)
              : property,
        )
        .toList(growable: false);
    final updatedGraph = graph.copyWith(
      nodes: graph.nodes
          .map(
            (entry) => entry.id == nodeId
                ? entry.copyWith(properties: updatedProperties)
                : entry,
          )
          .toList(growable: false),
    );
    final synchronized =
        _isTexelGraphNode(node) &&
            changedProperty.definitionKey ==
                materialTexelGraphResourcePropertyKey
        ? _synchronizeGraphBackedNodes(updatedGraph)
        : _GraphSynchronizationResult(graph: updatedGraph, changed: false);
    _commitGraph(synchronized.graph, dirtyRootNodeIds: [nodeId]);
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

  String _nextAvailableNodeName(String baseName) {
    final takenNames = graph.nodes.map((node) => node.name).toSet();
    if (!takenNames.contains(baseName)) {
      return baseName;
    }

    var index = 2;
    while (true) {
      final candidate = '$baseName $index';
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

  _GraphSynchronizationResult _synchronizeGraphBackedNodes(
    GraphDocument source,
  ) {
    var changed = false;
    var nodes = source.nodes.toList(growable: false);
    var links = source.links.toList(growable: false);
    for (final node in source.nodes) {
      if (!_isTexelGraphNode(node)) {
        continue;
      }
      final synchronizedNode = _synchronizeNodeProperties(
        node,
        definitionForNode(node).properties,
      );
      if (!synchronizedNode.changed) {
        continue;
      }
      changed = true;
      nodes = nodes
          .map((entry) => entry.id == node.id ? synchronizedNode.node : entry)
          .toList(growable: false);
      if (synchronizedNode.removedPropertyIds.isNotEmpty) {
        links = links
            .where(
              (link) =>
                  !synchronizedNode.removedPropertyIds.contains(
                    link.fromPropertyId,
                  ) &&
                  !synchronizedNode.removedPropertyIds.contains(
                    link.toPropertyId,
                  ),
            )
            .toList(growable: false);
      }
    }
    if (!changed) {
      return _GraphSynchronizationResult(graph: source, changed: false);
    }
    return _GraphSynchronizationResult(
      graph: source.copyWith(nodes: nodes, links: links),
      changed: true,
    );
  }

  _NodeSynchronizationResult _synchronizeNodeProperties(
    GraphNodeDocument node,
    List<GraphPropertyDefinition> definitions,
  ) {
    final existingByKey = {
      for (final property in node.properties) property.definitionKey: property,
    };
    final nextProperties = <GraphNodePropertyData>[];
    final removedPropertyIds = <String>{
      for (final property in node.properties) property.id,
    };
    var changed = false;
    for (final definition in definitions) {
      final existing = existingByKey[definition.key];
      if (existing != null &&
          existing.value.valueType == definition.valueType) {
        nextProperties.add(existing);
        removedPropertyIds.remove(existing.id);
        continue;
      }
      changed = true;
      nextProperties.add(
        GraphNodePropertyData(
          id: _idFactory.next(),
          definitionKey: definition.key,
          value: _catalog.defaultValueForProperty(definition),
        ),
      );
      if (existing != null) {
        removedPropertyIds.add(existing.id);
      }
    }

    if (!changed && nextProperties.length == node.properties.length) {
      for (var index = 0; index < nextProperties.length; index += 1) {
        if (nextProperties[index].id != node.properties[index].id) {
          changed = true;
          break;
        }
      }
    } else if (nextProperties.length != node.properties.length) {
      changed = true;
    }

    return _NodeSynchronizationResult(
      node: changed ? node.copyWith(properties: nextProperties) : node,
      changed: changed,
      removedPropertyIds: removedPropertyIds,
    );
  }

  void _handleRuntimeChanged() {
    notifyListeners();
  }

  bool _isTexelGraphNode(GraphNodeDocument node) {
    return node.definitionId == materialTexelGraphNodeDefinitionId;
  }
}
