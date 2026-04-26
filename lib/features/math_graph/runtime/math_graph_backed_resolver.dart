import 'package:collection/collection.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../../workspace/models/workspace_models.dart';
import '../../workspace/workspace_controller.dart';
import '../math_graph_catalog.dart';
import '../math_node_definition.dart';
import 'math_graph_compiler.dart';
import 'math_graph_ir.dart';

class MathGraphBackedNodeResolution {
  const MathGraphBackedNodeResolution({
    required this.definition,
    this.compiledFunction,
    this.diagnostics = const <String>[],
  });

  final MathNodeDefinition definition;
  final MathCompiledFunction? compiledFunction;
  final List<String> diagnostics;
}

class MathGraphBackedNodeResolver {
  const MathGraphBackedNodeResolver({
    required MathGraphCatalog catalog,
    WorkspaceController? workspaceController,
    MathGraphCompiler? mathGraphCompiler,
  }) : _catalog = catalog,
       _workspaceController = workspaceController,
       _mathGraphCompiler = mathGraphCompiler;

  final MathGraphCatalog _catalog;
  final WorkspaceController? _workspaceController;
  final MathGraphCompiler? _mathGraphCompiler;

  MathGraphBackedNodeResolution resolveNode(
    GraphNodeDocument node, {
    MathGraphTarget target = MathGraphTarget.generic,
    String? currentResourceId,
  }) {
    final baseDefinition = _catalog.definitionById(node.definitionId);
    if (node.definitionId != mathSubgraphNodeDefinitionId) {
      return MathGraphBackedNodeResolution(definition: baseDefinition);
    }
    return _resolveSubgraphNode(
      node: node,
      baseDefinition: baseDefinition,
      target: target,
      currentResourceId: currentResourceId,
    );
  }

  MathGraphBackedNodeResolution _resolveSubgraphNode({
    required GraphNodeDocument node,
    required MathNodeDefinition baseDefinition,
    required MathGraphTarget target,
    String? currentResourceId,
  }) {
    final resourceId =
        node
            .propertyByDefinitionKey(mathSubgraphResourcePropertyKey)
            ?.value
            .asWorkspaceResource() ??
        '';
    if (resourceId.isEmpty) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: const <String>[
          'Select a math graph to configure this node.',
        ],
      );
    }
    if (currentResourceId != null && currentResourceId == resourceId) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: const <String>[
          'A math graph cannot reference itself as a subgraph.',
        ],
      );
    }

    final workspaceController = _workspaceController;
    final mathGraphCompiler = _mathGraphCompiler;
    if (workspaceController == null ||
        mathGraphCompiler == null ||
        !workspaceController.isInitialized) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: const <String>[
          'Workspace math graph resolution is unavailable.',
        ],
      );
    }

    final resource = workspaceController.resourceById(resourceId);
    if (resource == null || resource.kind != WorkspaceResourceKind.mathGraph) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: <String>[
          'Selected resource `$resourceId` is not a math graph.',
        ],
      );
    }

    final document = workspaceController.workspace.mathGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
    if (document == null) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: <String>[
          'Math graph document for `${resource.name}` could not be found.',
        ],
      );
    }

    final compileResult = mathGraphCompiler.compile(
      document.graph,
      options: MathGraphCompileOptions(
        functionName: _subgraphFunctionName(resource.name),
        target: target,
        resourceId: resource.id,
        resourceReferenceChain: currentResourceId == null
            ? const <String>[]
            : <String>[currentResourceId],
      ),
    );
    final diagnostics = <String>[
      for (final diagnostic in compileResult.diagnostics)
        '${diagnostic.severity.name}: ${diagnostic.message}',
    ];
    final compiledFunction = compileResult.compiledFunction;
    if (compiledFunction == null) {
      return MathGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: diagnostics.isEmpty
            ? const <String>['Failed to compile the selected math graph.']
            : diagnostics,
      );
    }

    final signatureDiagnostics = <String>[];
    final resolvedDefinition = MathNodeDefinition(
      schema: GraphNodeSchema(
        id: baseDefinition.schema.id,
        label: baseDefinition.schema.label,
        description: baseDefinition.schema.description,
        properties: _resolvedPropertiesForFunction(
          baseDefinition,
          compiledFunction,
          diagnostics: signatureDiagnostics,
        ),
      ),
      compileMetadata: baseDefinition.compileMetadata,
    );
    return MathGraphBackedNodeResolution(
      definition: resolvedDefinition,
      compiledFunction: compiledFunction,
      diagnostics: [...diagnostics, ...signatureDiagnostics],
    );
  }

  List<GraphPropertyDefinition> _resolvedPropertiesForFunction(
    MathNodeDefinition baseDefinition,
    MathCompiledFunction function, {
    required List<String> diagnostics,
  }) {
    final properties = <GraphPropertyDefinition>[
      baseDefinition.propertyDefinition(mathSubgraphResourcePropertyKey),
    ];
    for (final parameter in function.parameters) {
      switch (parameter.kind) {
        case MathFunctionParameterKind.inputValue:
          final valueType = parameter.valueType;
          if (valueType == null) {
            diagnostics.add(
              'Input parameter `${parameter.name}` is missing a concrete value type.',
            );
            continue;
          }
          properties.add(
            GraphPropertyDefinition(
              key: parameter.name,
              label: parameter.rawIdentifier ?? parameter.name,
              description:
                  'Input forwarded to the referenced math graph parameter.',
              propertyType: GraphPropertyType.input,
              socket: true,
              valueType: valueType,
              valueUnit: parameter.valueUnit,
              defaultValue: parameter.defaultValue?.valueType == valueType
                  ? parameter.defaultValue!.unwrap()
                  : _defaultValueForType(valueType),
            ),
          );
        case MathFunctionParameterKind.builtinValue:
          if (parameter.rawIdentifier != 'pos' ||
              parameter.valueType != GraphValueType.float2) {
            diagnostics.add(
              'Unsupported builtin `${parameter.rawIdentifier ?? parameter.name}` in referenced math graph.',
            );
          }
        case MathFunctionParameterKind.sampler2D:
          diagnostics.add(
            'Referenced math graphs that sample textures are not supported inside math subgraphs yet.',
          );
      }
    }
    properties.add(
      GraphPropertyDefinition(
        key: '_output',
        label: 'Output',
        description: 'Result returned by the referenced math graph.',
        propertyType: GraphPropertyType.output,
        socket: true,
        valueType: function.returnType,
        valueUnit: GraphValueUnit.none,
        defaultValue: _defaultValueForType(function.returnType),
      ),
    );
    return properties;
  }

  String _subgraphFunctionName(String resourceName) {
    final sanitized = resourceName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.isEmpty) {
      return 'mathSubgraph';
    }
    return 'mathSubgraph_$sanitized';
  }

  Object _defaultValueForType(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.boolean:
        return false;
      case GraphValueType.integer:
        return 0;
      case GraphValueType.integer2:
        return const <int>[0, 0];
      case GraphValueType.integer3:
        return const <int>[0, 0, 0];
      case GraphValueType.integer4:
        return const <int>[0, 0, 0, 0];
      case GraphValueType.float:
        return 0.0;
      case GraphValueType.float2:
        return vmath.Vector2.zero();
      case GraphValueType.float3:
        return vmath.Vector3.zero();
      case GraphValueType.float4:
        return vmath.Vector4.zero();
      case GraphValueType.float3x3:
        return vmath.Matrix3.zero();
      case GraphValueType.stringValue:
        return '';
      case GraphValueType.workspaceResource:
        return '';
      case GraphValueType.enumChoice:
        return 0;
      case GraphValueType.gradient:
      case GraphValueType.colorBezierCurve:
      case GraphValueType.textBlock:
        throw StateError('Unsupported subgraph default type: $valueType');
    }
  }
}
