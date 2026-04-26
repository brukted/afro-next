import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/math_graph/math_graph_catalog.dart';
import 'package:eyecandy/features/math_graph/runtime/math_graph_backed_resolver.dart';
import 'package:eyecandy/features/math_graph/runtime/math_graph_compiler.dart';
import 'package:eyecandy/features/math_graph/runtime/math_graph_ir.dart';
import 'package:eyecandy/features/workspace/workspace_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('compiler lowers arithmetic graphs into deterministic GLSL', () {
    final catalog = MathGraphCatalog(IdFactory());
    final input = catalog.instantiateNode(
      definitionId: 'get_float1_node',
      position: Vector2.zero(),
    );
    final constant = catalog.instantiateNode(
      definitionId: 'float_constant_node',
      position: Vector2(200, 0),
    );
    final add = catalog.instantiateNode(
      definitionId: 'add_float_node',
      position: Vector2(400, 0),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(600, 0),
    );

    final updatedInput = _setStringProperty(input, 'identifier', 'intensity');
    final updatedConstant = _setFloatProperty(constant, 'value', 0.5);
    final graph = GraphDocument(
      id: 'math-graph-1',
      name: 'Math Graph',
      nodes: [updatedInput, updatedConstant, add, output],
      links: [
        _connect(updatedInput, '_output', add, 'a'),
        _connect(updatedConstant, '_output', add, 'b'),
        _connect(add, '_output', output, 'value'),
      ],
    );

    final result = _compile(
      catalog,
      graph,
      options: const MathGraphCompileOptions(functionName: 'computeValue'),
    );

    expect(result.hasErrors, isFalse);
    expect(result.compiledFunction!.topologicalNodeIds, [
      updatedInput.id,
      updatedConstant.id,
      add.id,
      output.id,
    ]);
    expect(
      result.compiledFunction!.parameters.map((parameter) => parameter.name),
      ['in_intensity'],
    );
    expect(
      result.compiledFunction!.source,
      contains('float computeValue(float in_intensity)'),
    );
    expect(result.compiledFunction!.source, contains('float t0 = 0.5;'));
    expect(
      result.compiledFunction!.source,
      contains('float t1 = (in_intensity + t0);'),
    );
    expect(result.compiledFunction!.source, contains('return t1;'));
  });

  test('compiler carries input metadata into compiled parameters', () {
    final catalog = MathGraphCatalog(IdFactory());
    final input = catalog.instantiateNode(
      definitionId: 'get_float1_node',
      position: Vector2.zero(),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(200, 0),
    );
    final updatedInput = _setStringProperty(input, 'identifier', 'gain')
        .copyWith(
          properties: input.properties
              .map((property) {
                switch (property.definitionKey) {
                  case 'identifier':
                    return property.copyWith(
                      value: GraphValueData.stringValue('gain'),
                    );
                  case 'defaultValue':
                    return property.copyWith(value: GraphValueData.float(0.25));
                  case 'unit':
                    return property.copyWith(
                      value: GraphValueData.enumChoice(1),
                    );
                  case 'hasMin':
                    return property.copyWith(
                      value: GraphValueData.boolean(true),
                    );
                  case 'min':
                    return property.copyWith(value: GraphValueData.float(-1.0));
                  case 'hasMax':
                    return property.copyWith(
                      value: GraphValueData.boolean(true),
                    );
                  case 'max':
                    return property.copyWith(value: GraphValueData.float(2.0));
                  case 'step':
                    return property.copyWith(
                      value: GraphValueData.float(0.125),
                    );
                  default:
                    return property;
                }
              })
              .toList(growable: false),
        );
    final graph = GraphDocument(
      id: 'math-graph-metadata',
      name: 'Metadata',
      nodes: [updatedInput, output],
      links: [_connect(updatedInput, '_output', output, 'value')],
    );

    final result = _compile(catalog, graph);

    expect(result.hasErrors, isFalse);
    final parameter = result.compiledFunction!.parameters.single;
    expect(parameter.rawIdentifier, 'gain');
    expect(parameter.defaultValue?.floatValue, 0.25);
    expect(parameter.minValue?.floatValue, -1.0);
    expect(parameter.maxValue?.floatValue, 2.0);
    expect(parameter.step, 0.125);
    expect(parameter.valueUnit, GraphValueUnit.rotation);
  });

  test('compiler rejects cycles instead of silently appending nodes', () {
    final catalog = MathGraphCatalog(IdFactory());
    final input = catalog.instantiateNode(
      definitionId: 'get_float1_node',
      position: Vector2.zero(),
    );
    final add = catalog.instantiateNode(
      definitionId: 'add_float_node',
      position: Vector2(200, 0),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(400, 0),
    );

    final graph = GraphDocument(
      id: 'math-graph-cycle',
      name: 'Cycle',
      nodes: [input, add, output],
      links: [
        _connect(input, '_output', add, 'a'),
        _connect(add, '_output', output, 'value'),
        _connect(add, '_output', add, 'b'),
      ],
    );

    final result = _compile(catalog, graph);

    expect(result.hasErrors, isTrue);
    expect(
      result.diagnostics.any(
        (diagnostic) => diagnostic.code == 'cycle_detected',
      ),
      isTrue,
    );
    expect(result.compiledFunction, isNull);
  });

  test('compiler reports type mismatches on invalid links', () {
    final catalog = MathGraphCatalog(IdFactory());
    final input = catalog.instantiateNode(
      definitionId: 'get_float1_node',
      position: Vector2.zero(),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_boolean_node',
      position: Vector2(200, 0),
    );
    final graph = GraphDocument(
      id: 'math-graph-mismatch',
      name: 'Mismatch',
      nodes: [input, output],
      links: [_connect(input, '_output', output, 'value')],
    );

    final result = _compile(catalog, graph);

    expect(result.hasErrors, isTrue);
    expect(
      result.diagnostics.any(
        (diagnostic) => diagnostic.code == 'type_mismatch',
      ),
      isTrue,
    );
  });

  test('compiler lowers sampler and local-variable nodes', () {
    final catalog = MathGraphCatalog(IdFactory());
    final pos = catalog.instantiateNode(
      definitionId: 'builtin_pos_node',
      position: Vector2.zero(),
    );
    final sample = catalog.instantiateNode(
      definitionId: 'sample_grey_node',
      position: Vector2(200, 0),
    );
    final setNode = catalog.instantiateNode(
      definitionId: 'set_float_node',
      position: Vector2(400, 0),
    );
    final getNode = catalog.instantiateNode(
      definitionId: 'get_float_node',
      position: Vector2(600, 0),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(800, 0),
    );

    final updatedSample = _setIntProperty(sample, 'sourceIndex', 2);
    final updatedSet = _setStringProperty(setNode, 'identifier', 'gain');
    final updatedGet = _setStringProperty(getNode, 'identifier', 'gain');
    final graph = GraphDocument(
      id: 'math-graph-sampler',
      name: 'Sampler Graph',
      nodes: [pos, updatedSample, updatedSet, updatedGet, output],
      links: [
        _connect(pos, '_output', updatedSample, 'uv'),
        _connect(updatedSample, '_output', updatedSet, 'value'),
        _connect(updatedGet, '_output', output, 'value'),
      ],
    );

    final result = _compile(
      catalog,
      graph,
      options: const MathGraphCompileOptions(functionName: 'sampleValue'),
    );

    expect(result.hasErrors, isFalse);
    expect(
      result.compiledFunction!.parameters.map((parameter) => parameter.name),
      ['pos', 'sampler_2'],
    );
    expect(
      result.compiledFunction!.parameters.map((parameter) => parameter.kind),
      [
        MathFunctionParameterKind.builtinValue,
        MathFunctionParameterKind.sampler2D,
      ],
    );
    expect(
      result.compiledFunction!.source,
      contains('float sampleValue(vec2 pos, sampler2D sampler_2)'),
    );
    expect(
      result.compiledFunction!.source,
      contains(
        'float t0 = dot(texture(sampler_2, pos).rgb, vec3(0.299, 0.587, 0.114));',
      ),
    );
    expect(result.compiledFunction!.source, contains('float var_gain = t0;'));
    expect(result.compiledFunction!.source, contains('return var_gain;'));
  });

  test('compiler resolves vector breakout outputs independently', () {
    final catalog = MathGraphCatalog(IdFactory());
    final input = catalog.instantiateNode(
      definitionId: 'get_float3_node',
      position: Vector2.zero(),
    );
    final breakNode = catalog.instantiateNode(
      definitionId: 'break_float3_node',
      position: Vector2(200, 0),
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(400, 0),
    );
    final updatedInput = _setStringProperty(input, 'identifier', 'normal');
    final graph = GraphDocument(
      id: 'math-graph-breakout',
      name: 'Breakout',
      nodes: [updatedInput, breakNode, output],
      links: [
        _connect(updatedInput, '_output', breakNode, 'input'),
        _connect(breakNode, 'z', output, 'value'),
      ],
    );

    final result = _compile(
      catalog,
      graph,
      options: const MathGraphCompileOptions(functionName: 'extractZ'),
    );

    expect(result.hasErrors, isFalse);
    expect(
      result.compiledFunction!.source,
      contains('float extractZ(vec3 in_normal)'),
    );
    expect(result.compiledFunction!.source, contains('return in_normal.z;'));
  });

  test(
    'compiler lowers referenced math subgraphs into helper function calls',
    () {
      final childGraph = _buildSubgraphChild('gain');
      final workspaceController = WorkspaceController.preview()
        ..initializeForPreview()
        ..createMathGraphAt(null)
        ..updateActiveMathGraph(childGraph);
      final childResourceId = workspaceController.openedResource!.id;
      final catalog = MathGraphCatalog(IdFactory());
      final compiler = MathGraphCompiler(
        catalog: catalog,
        workspaceController: workspaceController,
      );

      final constant = _setFloatProperty(
        catalog.instantiateNode(
          definitionId: 'float_constant_node',
          position: Vector2.zero(),
        ),
        'value',
        2.0,
      );
      final subgraph = _configureSubgraphNode(
        catalog: catalog,
        compiler: compiler,
        workspaceController: workspaceController,
        resourceId: childResourceId,
        propertyValues: <String, GraphValueData>{
          'in_gain': GraphValueData.float(0),
        },
      );
      final output = catalog.instantiateNode(
        definitionId: 'output_float_node',
        position: Vector2(420, 0),
      );
      final graph = GraphDocument(
        id: 'math-parent-subgraph',
        name: 'parentValue',
        nodes: [constant, subgraph, output],
        links: [
          _connect(constant, '_output', subgraph, 'in_gain'),
          _connect(subgraph, '_output', output, 'value'),
        ],
      );

      final result = compiler.compile(
        graph,
        options: const MathGraphCompileOptions(functionName: 'parentValue'),
      );

      expect(result.hasErrors, isFalse);
      expect(result.compiledFunction!.source, contains('float parentValue()'));
      expect(result.compiledFunction!.source, contains('(float in_gain)'));
      expect(
        result.compiledFunction!.source,
        contains('float t1 = (in_gain + t0);'),
      );
      expect(result.compiledFunction!.source, contains('float t0 = 2.0;'));
      expect(result.compiledFunction!.source, contains('float t1 = '));
      expect(result.compiledFunction!.source, contains('(t0);'));
    },
  );

  test('compiler rejects recursive math subgraph references', () {
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview()
      ..createMathGraphAt(null);
    final resourceId = workspaceController.openedResource!.id;
    final catalog = MathGraphCatalog(IdFactory());
    final compiler = MathGraphCompiler(
      catalog: catalog,
      workspaceController: workspaceController,
    );
    final subgraph = _configureSubgraphNode(
      catalog: catalog,
      compiler: compiler,
      workspaceController: workspaceController,
      resourceId: resourceId,
    );
    final output = catalog.instantiateNode(
      definitionId: 'output_float_node',
      position: Vector2(220, 0),
    );
    final graph = GraphDocument(
      id: 'recursive-graph',
      name: 'recursiveGraph',
      nodes: [subgraph, output],
      links: [_connect(subgraph, '_output', output, 'value')],
    );

    final result = compiler.compile(
      graph,
      options: MathGraphCompileOptions(
        functionName: 'recursiveGraph',
        resourceId: resourceId,
      ),
    );

    expect(result.hasErrors, isTrue);
    expect(
      result.diagnostics.any(
        (diagnostic) => diagnostic.code == 'recursive_subgraph_reference',
      ),
      isTrue,
    );
    expect(result.compiledFunction, isNull);
  });
}

MathCompileResult _compile(
  MathGraphCatalog catalog,
  GraphDocument graph, {
  MathGraphCompileOptions options = const MathGraphCompileOptions(),
}) {
  return MathGraphCompiler(catalog: catalog).compile(graph, options: options);
}

GraphNodeDocument _configureSubgraphNode({
  required MathGraphCatalog catalog,
  required MathGraphCompiler compiler,
  required WorkspaceController workspaceController,
  required String resourceId,
  Map<String, GraphValueData> propertyValues = const <String, GraphValueData>{},
}) {
  final node = catalog.instantiateNode(
    definitionId: mathSubgraphNodeDefinitionId,
    position: Vector2(200, 0),
  );
  final configuredNode = node.copyWith(
    properties: node.properties
        .map(
          (property) =>
              property.definitionKey == mathSubgraphResourcePropertyKey
              ? property.copyWith(
                  value: GraphValueData.workspaceResource(resourceId),
                )
              : property,
        )
        .toList(growable: false),
  );
  final definition = MathGraphBackedNodeResolver(
    catalog: catalog,
    workspaceController: workspaceController,
    mathGraphCompiler: compiler,
  ).resolveNode(configuredNode).definition;
  return configuredNode.copyWith(
    properties: definition.properties
        .map((propertyDefinition) {
          final existing = configuredNode.properties.firstWhere(
            (property) => property.definitionKey == propertyDefinition.key,
            orElse: () => GraphNodePropertyData(
              id: '${configuredNode.id}:${propertyDefinition.key}',
              definitionKey: propertyDefinition.key,
              value: catalog.defaultValueForProperty(propertyDefinition),
            ),
          );
          return GraphNodePropertyData(
            id: existing.id,
            definitionKey: propertyDefinition.key,
            value:
                propertyValues[propertyDefinition.key] ??
                existing.value.deepCopy(),
          );
        })
        .toList(growable: false),
  );
}

GraphLinkDocument _connect(
  GraphNodeDocument fromNode,
  String fromKey,
  GraphNodeDocument toNode,
  String toKey,
) {
  return GraphLinkDocument(
    id: '${fromNode.id}:$fromKey->${toNode.id}:$toKey',
    fromNodeId: fromNode.id,
    fromPropertyId: fromNode.propertyByDefinitionKey(fromKey)!.id,
    toNodeId: toNode.id,
    toPropertyId: toNode.propertyByDefinitionKey(toKey)!.id,
  );
}

GraphNodeDocument _setStringProperty(
  GraphNodeDocument node,
  String key,
  String value,
) {
  return node.copyWith(
    properties: node.properties
        .map(
          (property) => property.definitionKey == key
              ? property.copyWith(value: GraphValueData.stringValue(value))
              : property,
        )
        .toList(growable: false),
  );
}

GraphNodeDocument _setFloatProperty(
  GraphNodeDocument node,
  String key,
  double value,
) {
  return node.copyWith(
    properties: node.properties
        .map(
          (property) => property.definitionKey == key
              ? property.copyWith(value: GraphValueData.float(value))
              : property,
        )
        .toList(growable: false),
  );
}

GraphNodeDocument _setIntProperty(
  GraphNodeDocument node,
  String key,
  int value,
) {
  return node.copyWith(
    properties: node.properties
        .map(
          (property) => property.definitionKey == key
              ? property.copyWith(value: GraphValueData.integer(value))
              : property,
        )
        .toList(growable: false),
  );
}

GraphDocument _buildSubgraphChild(String identifier) {
  final catalog = MathGraphCatalog(IdFactory());
  final input = _setStringProperty(
    catalog.instantiateNode(
      definitionId: 'get_float1_node',
      position: Vector2.zero(),
    ),
    'identifier',
    identifier,
  );
  final constant = _setFloatProperty(
    catalog.instantiateNode(
      definitionId: 'float_constant_node',
      position: Vector2(180, 80),
    ),
    'value',
    0.5,
  );
  final add = catalog.instantiateNode(
    definitionId: 'add_float_node',
    position: Vector2(360, 0),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float_node',
    position: Vector2(560, 0),
  );
  return GraphDocument(
    id: 'subgraph-child-$identifier',
    name: 'Subgraph Child',
    nodes: [input, constant, add, output],
    links: [
      _connect(input, '_output', add, 'a'),
      _connect(constant, '_output', add, 'b'),
      _connect(add, '_output', output, 'value'),
    ],
  );
}
