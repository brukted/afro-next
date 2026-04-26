import 'package:collection/collection.dart';

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../../workspace/models/workspace_models.dart';
import '../../workspace/workspace_controller.dart';
import '../math_graph_catalog.dart';
import '../math_node_definition.dart';
import 'math_glsl_emitter.dart';
import 'math_graph_ir.dart';

class MathGraphCompileOptions {
  const MathGraphCompileOptions({
    this.functionName,
    this.target = MathGraphTarget.generic,
    this.resourceId,
    this.resourceReferenceChain = const <String>[],
  });

  final String? functionName;
  final MathGraphTarget target;
  final String? resourceId;
  final List<String> resourceReferenceChain;
}

class MathGraphCompiler {
  const MathGraphCompiler({
    required MathGraphCatalog catalog,
    WorkspaceController? workspaceController,
    MathGlslEmitter emitter = const MathGlslEmitter(),
  }) : _catalog = catalog,
       _workspaceController = workspaceController,
       _emitter = emitter;

  final MathGraphCatalog _catalog;
  final WorkspaceController? _workspaceController;
  final MathGlslEmitter _emitter;

  MathCompileResult compile(
    GraphDocument graph, {
    MathGraphCompileOptions options = const MathGraphCompileOptions(),
  }) {
    final diagnostics = <MathCompileDiagnostic>[];
    final nodesById = <String, GraphNodeDocument>{
      for (final node in graph.nodes) node.id: node,
    };
    final definitionsByNodeId = <String, MathNodeDefinition>{};
    final propertyById = <String, GraphNodePropertyData>{};
    final propertyDefinitionById = <String, GraphPropertyDefinition>{};
    final nodeIdByPropertyId = <String, String>{};
    final subgraphResolutionByNodeId = <String, _ResolvedSubgraphNode>{};

    for (final node in graph.nodes) {
      MathNodeDefinition? definition;
      try {
        definition = _definitionForNode(
          node,
          options: options,
          diagnostics: diagnostics,
          subgraphResolutionByNodeId: subgraphResolutionByNodeId,
        );
        definitionsByNodeId[node.id] = definition;
      } on StateError {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'unknown_node_definition',
            message: 'Unknown math node definition `${node.definitionId}`.',
            nodeId: node.id,
          ),
        );
        continue;
      }

      for (final property in node.properties) {
        propertyById[property.id] = property;
        nodeIdByPropertyId[property.id] = node.id;
        final definitionMatch = _propertyDefinitionForNode(
          definition,
          property.definitionKey,
        );
        if (definitionMatch == null) {
          diagnostics.add(
            MathCompileDiagnostic(
              severity: MathCompileDiagnosticSeverity.error,
              code: 'unknown_node_property',
              message:
                  'Property `${property.definitionKey}` is not declared by `${definition.id}`.',
              nodeId: node.id,
              propertyId: property.id,
            ),
          );
          continue;
        }
        propertyDefinitionById[property.id] = definitionMatch;
      }
    }

    final linkByInputPropertyId = <String, GraphLinkDocument>{};
    final incomingCounts = <String, int>{
      for (final node in graph.nodes) node.id: 0,
    };
    final outgoingNodeIds = <String, List<String>>{
      for (final node in graph.nodes) node.id: <String>[],
    };

    for (final link in graph.links) {
      final fromNode = nodesById[link.fromNodeId];
      final toNode = nodesById[link.toNodeId];
      final fromProperty = propertyById[link.fromPropertyId];
      final toProperty = propertyById[link.toPropertyId];
      final fromDefinition = propertyDefinitionById[link.fromPropertyId];
      final toDefinition = propertyDefinitionById[link.toPropertyId];

      if (fromNode == null ||
          toNode == null ||
          fromProperty == null ||
          toProperty == null ||
          fromDefinition == null ||
          toDefinition == null) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'dangling_link',
            message: 'A graph link references a missing node or property.',
          ),
        );
        continue;
      }
      if (fromDefinition.socketDirection != GraphSocketDirection.output) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'invalid_link_source',
            message:
                'Link sources must connect from output sockets, but `${fromDefinition.key}` is not an output.',
            nodeId: fromNode.id,
            propertyId: fromProperty.id,
          ),
        );
      }
      if (toDefinition.socketDirection != GraphSocketDirection.input) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'invalid_link_target',
            message:
                'Link targets must connect to input sockets, but `${toDefinition.key}` is not an input.',
            nodeId: toNode.id,
            propertyId: toProperty.id,
          ),
        );
      }
      if (fromDefinition.valueType != toDefinition.valueType) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'type_mismatch',
            message:
                'Cannot connect `${fromDefinition.valueType}` to `${toDefinition.valueType}`.',
            nodeId: toNode.id,
            propertyId: toProperty.id,
          ),
        );
      }
      if (linkByInputPropertyId.containsKey(link.toPropertyId)) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'multiple_input_links',
            message:
                'Input socket `${toDefinition.key}` already has an incoming connection.',
            nodeId: toNode.id,
            propertyId: toProperty.id,
          ),
        );
        continue;
      }

      linkByInputPropertyId[link.toPropertyId] = link;
      incomingCounts.update(link.toNodeId, (value) => value + 1);
      outgoingNodeIds
          .putIfAbsent(link.fromNodeId, () => <String>[])
          .add(link.toNodeId);
    }

    if (diagnostics.any((diagnostic) => diagnostic.isError)) {
      return MathCompileResult(
        diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      );
    }

    final orderedNodeIds = _topologicalOrder(
      graph: graph,
      incomingCounts: incomingCounts,
      outgoingNodeIds: outgoingNodeIds,
      diagnostics: diagnostics,
    );
    if (diagnostics.any((diagnostic) => diagnostic.isError)) {
      return MathCompileResult(
        diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      );
    }

    final outputNodeIds = orderedNodeIds
        .where((nodeId) => definitionsByNodeId[nodeId]?.isGraphOutput ?? false)
        .toList(growable: false);
    if (outputNodeIds.length != 1) {
      diagnostics.add(
        MathCompileDiagnostic(
          severity: MathCompileDiagnosticSeverity.error,
          code: 'invalid_output_count',
          message:
              'Math graph compilation requires exactly one output node, but found ${outputNodeIds.length}.',
        ),
      );
      return MathCompileResult(
        diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      );
    }

    final state = _CompilerState(
      graph: graph,
      options: options,
      diagnostics: diagnostics,
      nodesById: nodesById,
      definitionsByNodeId: definitionsByNodeId,
      propertyById: propertyById,
      propertyDefinitionById: propertyDefinitionById,
      linkByInputPropertyId: linkByInputPropertyId,
      subgraphResolutionByNodeId: subgraphResolutionByNodeId,
      emitter: _emitter,
    );

    for (final nodeId in orderedNodeIds) {
      final node = nodesById[nodeId]!;
      final definition = definitionsByNodeId[nodeId]!;
      if (!definition.compileMetadata.supportedTargets.contains(
        options.target,
      )) {
        diagnostics.add(
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'unsupported_target',
            message:
                'Node `${definition.id}` is not supported for `${options.target.name}` compilation.',
            nodeId: node.id,
          ),
        );
        continue;
      }
      _compileNode(node, definition, state);
    }

    state.validateVariables();

    final hasErrors = diagnostics.any((diagnostic) => diagnostic.isError);
    if (hasErrors ||
        state.returnExpression == null ||
        state.returnType == null) {
      return MathCompileResult(
        diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      );
    }

    final ir = MathIrGraph(
      graphId: graph.id,
      functionName: state.functionName,
      target: options.target,
      returnType: state.returnType!,
      parameters: List<MathFunctionParameter>.unmodifiable(state.parameters),
      statements: List<MathIrStatement>.unmodifiable(state.statements),
      returnExpression: state.returnExpression!,
      topologicalNodeIds: List<String>.unmodifiable(orderedNodeIds),
      helperFunctionSources: List<String>.unmodifiable(
        state.helperFunctionSources,
      ),
    );
    final compiledFunction = _emitter.emit(ir);

    return MathCompileResult(
      diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      ir: ir,
      compiledFunction: compiledFunction,
    );
  }

  MathNodeDefinition _definitionForNode(
    GraphNodeDocument node, {
    required MathGraphCompileOptions options,
    required List<MathCompileDiagnostic> diagnostics,
    required Map<String, _ResolvedSubgraphNode> subgraphResolutionByNodeId,
  }) {
    final definition = _catalog.definitionById(node.definitionId);
    if (definition.compileMetadata.kind != MathNodeKind.subgraph) {
      return definition;
    }
    final resolution = _resolveSubgraphNode(
      node,
      baseDefinition: definition,
      options: options,
    );
    subgraphResolutionByNodeId[node.id] = resolution;
    diagnostics.addAll(resolution.diagnostics);
    return resolution.definition;
  }

  _ResolvedSubgraphNode _resolveSubgraphNode(
    GraphNodeDocument node, {
    required MathNodeDefinition baseDefinition,
    required MathGraphCompileOptions options,
  }) {
    final resourceProperty = node.propertyByDefinitionKey(
      mathSubgraphResourcePropertyKey,
    );
    final resourceId = resourceProperty?.value.asWorkspaceResource() ?? '';
    if (resourceId.isEmpty) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: const <MathCompileDiagnostic>[
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'missing_subgraph_resource',
            message: 'Select a math graph for this subgraph node.',
          ),
        ],
      );
    }
    if (resourceId == options.resourceId ||
        options.resourceReferenceChain.contains(resourceId)) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: [
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'recursive_subgraph_reference',
            message: 'Recursive math subgraph references are not supported.',
            nodeId: node.id,
            propertyId: resourceProperty?.id,
          ),
        ],
      );
    }

    final workspaceController = _workspaceController;
    if (workspaceController == null || !workspaceController.isInitialized) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: [
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'subgraph_workspace_unavailable',
            message: 'Workspace math graph resolution is unavailable.',
            nodeId: node.id,
            propertyId: resourceProperty?.id,
          ),
        ],
      );
    }

    final resource = workspaceController.resourceById(resourceId);
    if (resource == null || resource.kind != WorkspaceResourceKind.mathGraph) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: [
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'invalid_subgraph_resource',
            message: 'Selected resource `$resourceId` is not a math graph.',
            nodeId: node.id,
            propertyId: resourceProperty?.id,
          ),
        ],
      );
    }

    final document = workspaceController.workspace.mathGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
    if (document == null) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: [
          MathCompileDiagnostic(
            severity: MathCompileDiagnosticSeverity.error,
            code: 'missing_subgraph_document',
            message:
                'Math graph document for `${resource.name}` could not be found.',
            nodeId: node.id,
            propertyId: resourceProperty?.id,
          ),
        ],
      );
    }

    final nestedResult = compile(
      document.graph,
      options: MathGraphCompileOptions(
        functionName:
            '${options.functionName ?? document.graph.name}_${node.id}',
        target: options.target,
        resourceId: resource.id,
        resourceReferenceChain: <String>[
          ...options.resourceReferenceChain,
          if (options.resourceId != null) options.resourceId!,
        ],
      ),
    );
    final nestedDiagnostics = [
      for (final diagnostic in nestedResult.diagnostics)
        MathCompileDiagnostic(
          severity: diagnostic.severity,
          code: diagnostic.code,
          message: diagnostic.message,
          nodeId: diagnostic.nodeId ?? node.id,
          propertyId: diagnostic.propertyId ?? resourceProperty?.id,
        ),
    ];
    final compiledFunction = nestedResult.compiledFunction;
    if (compiledFunction == null) {
      return _ResolvedSubgraphNode(
        definition: baseDefinition,
        diagnostics: nestedDiagnostics,
      );
    }

    final signatureDiagnostics = <MathCompileDiagnostic>[];
    final resolvedDefinition = MathNodeDefinition(
      schema: GraphNodeSchema(
        id: baseDefinition.schema.id,
        label: baseDefinition.schema.label,
        description: baseDefinition.schema.description,
        properties: _subgraphPropertiesForFunction(
          baseDefinition,
          compiledFunction,
          nodeId: node.id,
          diagnostics: signatureDiagnostics,
        ),
      ),
      compileMetadata: baseDefinition.compileMetadata,
    );
    return _ResolvedSubgraphNode(
      definition: resolvedDefinition,
      compiledFunction: compiledFunction,
      diagnostics: [...nestedDiagnostics, ...signatureDiagnostics],
    );
  }

  void _compileNode(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    switch (definition.compileMetadata.kind) {
      case MathNodeKind.constant:
        _compileConstant(node, definition, state);
      case MathNodeKind.inputParameter:
        _compileInputParameter(node, definition, state);
      case MathNodeKind.builtin:
        _compileBuiltin(node, definition, state);
      case MathNodeKind.sampler:
        _compileSampler(node, definition, state);
      case MathNodeKind.subgraph:
        _compileSubgraph(node, definition, state);
      case MathNodeKind.operation:
      case MathNodeKind.control:
        _compileOperation(node, definition, state);
      case MathNodeKind.variableSet:
        _compileVariableSet(node, definition, state);
      case MathNodeKind.variableGet:
        _compileVariableGet(node, definition, state);
      case MathNodeKind.graphOutput:
        _compileGraphOutput(node, definition, state);
    }
  }

  void _compileSubgraph(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final resolution = state.subgraphResolutionByNodeId[node.id];
    if (resolution == null) {
      state.error(
        code: 'invalid_subgraph_node',
        message: 'Subgraph node `${definition.id}` could not be resolved.',
        nodeId: node.id,
      );
      return;
    }

    final compiledFunction = resolution.compiledFunction;
    if (compiledFunction == null) {
      return;
    }

    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    if (outputDefinition == null || outputProperty == null) {
      state.error(
        code: 'invalid_subgraph_output',
        message: 'Subgraph node `${definition.id}` is missing its output.',
        nodeId: node.id,
      );
      return;
    }

    final arguments = <MathIrExpression>[];
    for (final parameter in compiledFunction.parameters) {
      switch (parameter.kind) {
        case MathFunctionParameterKind.inputValue:
          final input = state.resolveInput(
            node,
            definition,
            key: parameter.name,
          );
          if (input == null) {
            return;
          }
          arguments.add(input.expression);
        case MathFunctionParameterKind.builtinValue:
          final valueType = parameter.valueType;
          final builtinIdentifier = parameter.rawIdentifier;
          if (valueType == null || builtinIdentifier == null) {
            state.error(
              code: 'invalid_subgraph_builtin',
              message:
                  'Subgraph `${definition.id}` exposes an incomplete builtin parameter.',
              nodeId: node.id,
            );
            return;
          }
          final builtin = state.useBuiltinParameter(
            identifier: builtinIdentifier,
            valueType: valueType,
          );
          arguments.add(
            MathIrReferenceExpression(
              valueType: valueType,
              identifier: builtin.name,
            ),
          );
        case MathFunctionParameterKind.sampler2D:
          state.error(
            code: 'unsupported_subgraph_sampler',
            message:
                'Referenced math graphs that sample textures are not supported inside math subgraphs yet.',
            nodeId: node.id,
          );
          return;
      }
    }

    state.addHelperFunctionSource(compiledFunction.source);
    state.bindNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrFunctionCallExpression(
        valueType: outputDefinition.valueType,
        functionName: compiledFunction.functionName,
        arguments: arguments,
      ),
    );
  }

  void _compileConstant(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final property = node.propertyByDefinitionKey('value');
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    if (property == null ||
        outputDefinition == null ||
        outputProperty == null) {
      state.error(
        code: 'invalid_constant_node',
        message:
            'Constant node `${definition.id}` is missing required properties.',
        nodeId: node.id,
      );
      return;
    }
    final expression = MathIrLiteralExpression(
      valueType: outputDefinition.valueType,
      value: property.value.deepCopy(),
    );
    state.bindNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      expression,
    );
  }

  void _compileInputParameter(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      mathInputNodePropertyKeys.output,
    );
    final identifier = _readIdentifier(node, definition, state);
    if (outputDefinition == null ||
        outputProperty == null ||
        identifier == null) {
      return;
    }
    final metadata = _readInputMetadata(node, outputDefinition.valueType);
    final parameter = state.useInputParameter(
      identifier: identifier,
      valueType: outputDefinition.valueType,
      nodeId: node.id,
      defaultValue: metadata.defaultValue,
      minValue: metadata.minValue,
      maxValue: metadata.maxValue,
      step: metadata.step,
      valueUnit: metadata.valueUnit,
    );
    if (parameter == null) {
      return;
    }
    state.storeNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrReferenceExpression(
        valueType: outputDefinition.valueType,
        identifier: parameter.name,
      ),
    );
  }

  void _compileBuiltin(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    final builtinIdentifier = definition.compileMetadata.builtinIdentifier;
    if (outputDefinition == null ||
        outputProperty == null ||
        builtinIdentifier == null) {
      state.error(
        code: 'invalid_builtin_node',
        message: 'Builtin node `${definition.id}` is misconfigured.',
        nodeId: node.id,
      );
      return;
    }
    final parameter = state.useBuiltinParameter(
      identifier: builtinIdentifier,
      valueType: outputDefinition.valueType,
    );
    state.storeNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrReferenceExpression(
        valueType: outputDefinition.valueType,
        identifier: parameter.name,
      ),
    );
  }

  void _compileSampler(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    final samplerKey = definition.compileMetadata.samplerIndexPropertyKey;
    if (outputDefinition == null ||
        outputProperty == null ||
        samplerKey == null) {
      state.error(
        code: 'invalid_sampler_node',
        message: 'Sampler node `${definition.id}` is misconfigured.',
        nodeId: node.id,
      );
      return;
    }
    final uv = state.resolveInput(node, definition, key: 'uv');
    final sourceIndexProperty = node.propertyByDefinitionKey(samplerKey);
    if (uv == null || sourceIndexProperty == null) {
      state.error(
        code: 'invalid_sampler_input',
        message:
            'Sampler node `${definition.id}` is missing its UV or source index.',
        nodeId: node.id,
      );
      return;
    }
    final sourceIndex = sourceIndexProperty.value.integerValue ?? 0;
    final sampler = state.useSamplerParameter(sourceIndex);
    state.bindNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrTextureSampleExpression(
        valueType: outputDefinition.valueType,
        sampler: MathIrReferenceExpression(
          valueType: GraphValueType.workspaceResource,
          identifier: sampler.name,
        ),
        uv: uv.expression,
        greyscale: outputDefinition.valueType == GraphValueType.float,
      ),
    );
  }

  void _compileOperation(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final operation = definition.compileMetadata.operation;
    if (operation == null) {
      state.error(
        code: 'invalid_operation_node',
        message: 'Operation node `${definition.id}` is misconfigured.',
        nodeId: node.id,
      );
      return;
    }

    if (operation == MathNodeOperation.breakout) {
      final input = state.resolveInput(node, definition, key: 'input');
      if (input == null) {
        return;
      }
      for (final property in definition.properties.where(
        (property) => property.propertyType == GraphPropertyType.output,
      )) {
        final outputProperty = node.propertyByDefinitionKey(property.key);
        if (outputProperty == null) {
          continue;
        }
        state.storeNodeValue(
          outputProperty.id,
          property.valueType,
          MathIrSwizzleExpression(
            valueType: property.valueType,
            input: input.expression,
            components: property.key,
          ),
        );
      }
      return;
    }

    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    if (outputDefinition == null || outputProperty == null) {
      state.error(
        code: 'invalid_operation_node',
        message: 'Operation node `${definition.id}` is misconfigured.',
        nodeId: node.id,
      );
      return;
    }

    MathIrExpression? expression;
    switch (operation) {
      case MathNodeOperation.add:
      case MathNodeOperation.subtract:
      case MathNodeOperation.multiply:
      case MathNodeOperation.divide:
      case MathNodeOperation.modulo:
      case MathNodeOperation.and:
      case MathNodeOperation.or:
      case MathNodeOperation.equal:
      case MathNodeOperation.notEqual:
      case MathNodeOperation.greater:
      case MathNodeOperation.greaterOrEqual:
      case MathNodeOperation.lower:
      case MathNodeOperation.lowerOrEqual:
      case MathNodeOperation.scalarMultiply:
        final left = state.resolveInput(node, definition, key: 'a');
        final right = state.resolveInput(node, definition, key: 'b');
        if (left == null || right == null) {
          return;
        }
        expression = MathIrBinaryExpression(
          valueType: outputDefinition.valueType,
          left: left.expression,
          operatorSymbol: _binaryOperator(operation),
          right: right.expression,
        );
      case MathNodeOperation.negate:
      case MathNodeOperation.not:
        final value = state.resolveInput(node, definition, key: 'value');
        if (value == null) {
          return;
        }
        expression = MathIrUnaryExpression(
          valueType: outputDefinition.valueType,
          operatorSymbol: operation == MathNodeOperation.not ? '!' : '-',
          operand: value.expression,
        );
      case MathNodeOperation.absolute:
      case MathNodeOperation.floor:
      case MathNodeOperation.ceil:
      case MathNodeOperation.sqrt:
      case MathNodeOperation.log:
      case MathNodeOperation.exp:
      case MathNodeOperation.sin:
      case MathNodeOperation.cos:
      case MathNodeOperation.tan:
        final value = state.resolveInput(node, definition, key: 'value');
        if (value == null) {
          return;
        }
        expression = MathIrFunctionCallExpression(
          valueType: outputDefinition.valueType,
          functionName: _functionName(operation),
          arguments: [value.expression],
        );
      case MathNodeOperation.minimum:
      case MathNodeOperation.maximum:
      case MathNodeOperation.pow:
      case MathNodeOperation.dot:
        final left = state.resolveInput(node, definition, key: 'a');
        final right = state.resolveInput(node, definition, key: 'b');
        if (left == null || right == null) {
          return;
        }
        expression = MathIrFunctionCallExpression(
          valueType: outputDefinition.valueType,
          functionName: _functionName(operation),
          arguments: [left.expression, right.expression],
        );
      case MathNodeOperation.lerp:
        final a = state.resolveInput(node, definition, key: 'a');
        final b = state.resolveInput(node, definition, key: 'b');
        final x = state.resolveInput(node, definition, key: 'x');
        if (a == null || b == null || x == null) {
          return;
        }
        expression = MathIrFunctionCallExpression(
          valueType: outputDefinition.valueType,
          functionName: 'mix',
          arguments: [a.expression, b.expression, x.expression],
        );
      case MathNodeOperation.compose:
        final arguments = <MathIrExpression>[];
        for (var index = 0; ; index += 1) {
          final key = 'in$index';
          if (_propertyDefinitionForNode(definition, key) == null) {
            break;
          }
          final input = state.resolveInput(node, definition, key: key);
          if (input == null) {
            return;
          }
          arguments.add(input.expression);
        }
        expression = MathIrConstructorExpression(
          valueType: outputDefinition.valueType,
          arguments: arguments,
        );
      case MathNodeOperation.swizzle:
        final input = state.resolveInput(node, definition, key: 'input');
        final componentProperty = node.propertyByDefinitionKey('components');
        if (input == null || componentProperty == null) {
          return;
        }
        final components = _normalizedSwizzleMask(
          componentProperty.value.stringValue ?? '',
        );
        if (!_isValidSwizzleMask(
          components,
          _componentCountForType(outputDefinition.valueType),
        )) {
          state.error(
            code: 'invalid_swizzle_mask',
            message:
                'Swizzle mask `$components` is invalid for `${definition.id}`.',
            nodeId: node.id,
            propertyId: componentProperty.id,
          );
          return;
        }
        expression = MathIrSwizzleExpression(
          valueType: outputDefinition.valueType,
          input: input.expression,
          components: components,
        );
      case MathNodeOperation.cast:
        final value = state.resolveInput(node, definition, key: 'value');
        if (value == null) {
          return;
        }
        expression = MathIrFunctionCallExpression(
          valueType: outputDefinition.valueType,
          functionName: _glslType(outputDefinition.valueType),
          arguments: [value.expression],
        );
      case MathNodeOperation.ifElse:
        final condition = state.resolveInput(
          node,
          definition,
          key: 'condition',
        );
        final whenTrue = state.resolveInput(node, definition, key: 'a');
        final whenFalse = state.resolveInput(node, definition, key: 'b');
        if (condition == null || whenTrue == null || whenFalse == null) {
          return;
        }
        expression = MathIrConditionalExpression(
          valueType: outputDefinition.valueType,
          condition: condition.expression,
          whenTrue: whenTrue.expression,
          whenFalse: whenFalse.expression,
        );
      case MathNodeOperation.sequence:
        final first = state.resolveInput(node, definition, key: 'first');
        final second = state.resolveInput(node, definition, key: 'second');
        if (first == null || second == null) {
          return;
        }
        expression = second.expression;
      case MathNodeOperation.breakout:
        return;
    }

    state.bindNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      expression,
    );
  }

  void _compileVariableSet(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final identifier = _readIdentifier(node, definition, state);
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    final value = state.resolveInput(node, definition, key: 'value');
    if (identifier == null ||
        outputDefinition == null ||
        outputProperty == null ||
        value == null) {
      return;
    }
    final variable = state.setVariable(
      identifier: identifier,
      valueType: outputDefinition.valueType,
      expression: value.expression,
      nodeId: node.id,
    );
    if (variable == null) {
      return;
    }
    state.storeNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrReferenceExpression(
        valueType: outputDefinition.valueType,
        identifier: variable.name,
      ),
    );
  }

  void _compileVariableGet(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final identifier = _readIdentifier(node, definition, state);
    final outputDefinition = definition.outputDefinition;
    final outputProperty = node.propertyByDefinitionKey(
      definition.compileMetadata.outputPropertyKey,
    );
    if (identifier == null ||
        outputDefinition == null ||
        outputProperty == null) {
      return;
    }
    final variable = state.getVariable(
      identifier: identifier,
      expectedType: outputDefinition.valueType,
      nodeId: node.id,
    );
    if (variable == null) {
      return;
    }
    state.storeNodeValue(
      outputProperty.id,
      outputDefinition.valueType,
      MathIrReferenceExpression(
        valueType: outputDefinition.valueType,
        identifier: variable.name,
      ),
    );
  }

  void _compileGraphOutput(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final value = state.resolveInput(node, definition, key: 'value');
    final valueDefinition = _propertyDefinitionForNode(definition, 'value');
    if (value == null || valueDefinition == null) {
      state.error(
        code: 'invalid_graph_output',
        message: 'Output node `${definition.id}` is missing its value input.',
        nodeId: node.id,
      );
      return;
    }
    state.returnExpression = value.expression;
    state.returnType = valueDefinition.valueType;
  }

  String? _readIdentifier(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final key = definition.compileMetadata.externalIdentifierPropertyKey;
    if (key == null) {
      return null;
    }
    final property = node.propertyByDefinitionKey(key);
    if (property == null) {
      state.error(
        code: 'missing_identifier_property',
        message: 'Node `${definition.id}` is missing its identifier property.',
        nodeId: node.id,
      );
      return null;
    }
    final identifier = (property.value.stringValue ?? '').trim();
    if (identifier.isEmpty) {
      state.error(
        code: 'empty_identifier',
        message: 'Identifiers must not be empty.',
        nodeId: node.id,
        propertyId: property.id,
      );
      return null;
    }
    return identifier;
  }

  _InputParameterMetadata _readInputMetadata(
    GraphNodeDocument node,
    GraphValueType valueType,
  ) {
    final defaultValue = node
        .propertyByDefinitionKey(mathInputNodePropertyKeys.defaultValue)
        ?.value;
    final unitValue = node
        .propertyByDefinitionKey(mathInputNodePropertyKeys.unit)
        ?.value
        .enumValue;
    final normalizedUnitIndex = unitValue
        ?.clamp(0, GraphValueUnit.values.length - 1)
        .toInt();
    final valueUnit = normalizedUnitIndex == null
        ? GraphValueUnit.none
        : GraphValueUnit.values[normalizedUnitIndex];
    final hasMin =
        node
            .propertyByDefinitionKey(mathInputNodePropertyKeys.hasMin)
            ?.value
            .boolValue ??
        false;
    final hasMax =
        node
            .propertyByDefinitionKey(mathInputNodePropertyKeys.hasMax)
            ?.value
            .boolValue ??
        false;
    final minValue = hasMin
        ? node.propertyByDefinitionKey(mathInputNodePropertyKeys.min)?.value
        : null;
    final maxValue = hasMax
        ? node.propertyByDefinitionKey(mathInputNodePropertyKeys.max)?.value
        : null;
    final stepValue = node
        .propertyByDefinitionKey(mathInputNodePropertyKeys.step)
        ?.value
        .floatValue;
    return _InputParameterMetadata(
      defaultValue: defaultValue != null && defaultValue.valueType == valueType
          ? defaultValue.deepCopy()
          : null,
      minValue: minValue != null && minValue.valueType == valueType
          ? minValue.deepCopy()
          : null,
      maxValue: maxValue != null && maxValue.valueType == valueType
          ? maxValue.deepCopy()
          : null,
      step: stepValue,
      valueUnit: valueUnit,
    );
  }

  List<GraphPropertyDefinition> _subgraphPropertiesForFunction(
    MathNodeDefinition baseDefinition,
    MathCompiledFunction function, {
    required String nodeId,
    required List<MathCompileDiagnostic> diagnostics,
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
              MathCompileDiagnostic(
                severity: MathCompileDiagnosticSeverity.error,
                code: 'invalid_subgraph_parameter',
                message:
                    'Input parameter `${parameter.name}` is missing a concrete value type.',
                nodeId: nodeId,
              ),
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
              MathCompileDiagnostic(
                severity: MathCompileDiagnosticSeverity.error,
                code: 'unsupported_subgraph_builtin',
                message:
                    'Unsupported builtin `${parameter.rawIdentifier ?? parameter.name}` in referenced math graph.',
                nodeId: nodeId,
              ),
            );
          }
        case MathFunctionParameterKind.sampler2D:
          diagnostics.add(
            MathCompileDiagnostic(
              severity: MathCompileDiagnosticSeverity.error,
              code: 'unsupported_subgraph_sampler',
              message:
                  'Referenced math graphs that sample textures are not supported inside math subgraphs yet.',
              nodeId: nodeId,
            ),
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

  List<String> _topologicalOrder({
    required GraphDocument graph,
    required Map<String, int> incomingCounts,
    required Map<String, List<String>> outgoingNodeIds,
    required List<MathCompileDiagnostic> diagnostics,
  }) {
    final remainingCounts = Map<String, int>.from(incomingCounts);
    final ready = graph.nodes
        .where((node) => remainingCounts[node.id] == 0)
        .map((node) => node.id)
        .toList(growable: true);
    final ordered = <String>[];

    while (ready.isNotEmpty) {
      final nodeId = ready.removeAt(0);
      ordered.add(nodeId);
      for (final childId in outgoingNodeIds[nodeId] ?? const <String>[]) {
        final nextCount = (remainingCounts[childId] ?? 1) - 1;
        remainingCounts[childId] = nextCount;
        if (nextCount == 0) {
          ready.add(childId);
        }
      }
    }

    if (ordered.length != graph.nodes.length) {
      diagnostics.add(
        const MathCompileDiagnostic(
          severity: MathCompileDiagnosticSeverity.error,
          code: 'cycle_detected',
          message: 'The math graph contains a dependency cycle.',
        ),
      );
    }
    return ordered;
  }

  GraphPropertyDefinition? _propertyDefinitionForNode(
    MathNodeDefinition definition,
    String key,
  ) {
    for (final property in definition.properties) {
      if (property.key == key) {
        return property;
      }
    }
    return null;
  }

  String _binaryOperator(MathNodeOperation operation) {
    switch (operation) {
      case MathNodeOperation.add:
        return '+';
      case MathNodeOperation.subtract:
        return '-';
      case MathNodeOperation.multiply:
      case MathNodeOperation.scalarMultiply:
        return '*';
      case MathNodeOperation.divide:
        return '/';
      case MathNodeOperation.modulo:
        return '%';
      case MathNodeOperation.and:
        return '&&';
      case MathNodeOperation.or:
        return '||';
      case MathNodeOperation.equal:
        return '==';
      case MathNodeOperation.notEqual:
        return '!=';
      case MathNodeOperation.greater:
        return '>';
      case MathNodeOperation.greaterOrEqual:
        return '>=';
      case MathNodeOperation.lower:
        return '<';
      case MathNodeOperation.lowerOrEqual:
        return '<=';
      case MathNodeOperation.negate:
      case MathNodeOperation.absolute:
      case MathNodeOperation.floor:
      case MathNodeOperation.ceil:
      case MathNodeOperation.minimum:
      case MathNodeOperation.maximum:
      case MathNodeOperation.lerp:
      case MathNodeOperation.sqrt:
      case MathNodeOperation.pow:
      case MathNodeOperation.log:
      case MathNodeOperation.exp:
      case MathNodeOperation.sin:
      case MathNodeOperation.cos:
      case MathNodeOperation.tan:
      case MathNodeOperation.dot:
      case MathNodeOperation.not:
      case MathNodeOperation.compose:
      case MathNodeOperation.breakout:
      case MathNodeOperation.swizzle:
      case MathNodeOperation.cast:
      case MathNodeOperation.ifElse:
      case MathNodeOperation.sequence:
        throw StateError('No binary operator for $operation');
    }
  }

  String _functionName(MathNodeOperation operation) {
    switch (operation) {
      case MathNodeOperation.absolute:
        return 'abs';
      case MathNodeOperation.floor:
        return 'floor';
      case MathNodeOperation.ceil:
        return 'ceil';
      case MathNodeOperation.minimum:
        return 'min';
      case MathNodeOperation.maximum:
        return 'max';
      case MathNodeOperation.sqrt:
        return 'sqrt';
      case MathNodeOperation.pow:
        return 'pow';
      case MathNodeOperation.log:
        return 'log';
      case MathNodeOperation.exp:
        return 'exp';
      case MathNodeOperation.sin:
        return 'sin';
      case MathNodeOperation.cos:
        return 'cos';
      case MathNodeOperation.tan:
        return 'tan';
      case MathNodeOperation.dot:
        return 'dot';
      case MathNodeOperation.add:
      case MathNodeOperation.subtract:
      case MathNodeOperation.multiply:
      case MathNodeOperation.scalarMultiply:
      case MathNodeOperation.divide:
      case MathNodeOperation.modulo:
      case MathNodeOperation.negate:
      case MathNodeOperation.lerp:
      case MathNodeOperation.and:
      case MathNodeOperation.or:
      case MathNodeOperation.not:
      case MathNodeOperation.equal:
      case MathNodeOperation.notEqual:
      case MathNodeOperation.greater:
      case MathNodeOperation.greaterOrEqual:
      case MathNodeOperation.lower:
      case MathNodeOperation.lowerOrEqual:
      case MathNodeOperation.compose:
      case MathNodeOperation.breakout:
      case MathNodeOperation.swizzle:
      case MathNodeOperation.cast:
      case MathNodeOperation.ifElse:
      case MathNodeOperation.sequence:
        throw StateError('No standalone function name for $operation');
    }
  }

  int _componentCountForType(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.float:
        return 1;
      case GraphValueType.float2:
        return 2;
      case GraphValueType.float3:
        return 3;
      case GraphValueType.float4:
        return 4;
      case GraphValueType.boolean:
      case GraphValueType.integer:
      case GraphValueType.integer2:
      case GraphValueType.integer3:
      case GraphValueType.integer4:
      case GraphValueType.float3x3:
      case GraphValueType.stringValue:
      case GraphValueType.workspaceResource:
      case GraphValueType.enumChoice:
      case GraphValueType.gradient:
      case GraphValueType.colorBezierCurve:
      case GraphValueType.textBlock:
        return 0;
    }
  }

  bool _isValidSwizzleMask(String value, int expectedLength) {
    if (value.length != expectedLength || value.isEmpty) {
      return false;
    }
    return RegExp(r'^[xyzw]+$').hasMatch(value);
  }

  String _normalizedSwizzleMask(String value) {
    return value
        .trim()
        .replaceAll('r', 'x')
        .replaceAll('g', 'y')
        .replaceAll('b', 'z')
        .replaceAll('a', 'w');
  }

  String _glslType(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.boolean:
        return 'bool';
      case GraphValueType.integer:
        return 'int';
      case GraphValueType.integer2:
        return 'ivec2';
      case GraphValueType.integer3:
        return 'ivec3';
      case GraphValueType.integer4:
        return 'ivec4';
      case GraphValueType.float:
        return 'float';
      case GraphValueType.float2:
        return 'vec2';
      case GraphValueType.float3:
        return 'vec3';
      case GraphValueType.float4:
        return 'vec4';
      case GraphValueType.float3x3:
        return 'mat3';
      case GraphValueType.stringValue:
      case GraphValueType.workspaceResource:
      case GraphValueType.enumChoice:
      case GraphValueType.gradient:
      case GraphValueType.colorBezierCurve:
      case GraphValueType.textBlock:
        throw StateError('Unsupported GLSL type: $valueType');
    }
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
        return const [0.0, 0.0];
      case GraphValueType.float3:
        return const [0.0, 0.0, 0.0];
      case GraphValueType.float4:
        return const [0.0, 0.0, 0.0, 0.0];
      case GraphValueType.float3x3:
        return const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      case GraphValueType.stringValue:
      case GraphValueType.workspaceResource:
        return '';
      case GraphValueType.enumChoice:
        return 0;
      case GraphValueType.gradient:
      case GraphValueType.colorBezierCurve:
      case GraphValueType.textBlock:
        throw StateError('Unsupported default value type: $valueType');
    }
  }
}

class _ResolvedNodeValue {
  const _ResolvedNodeValue({required this.expression, required this.valueType});

  final MathIrExpression expression;
  final GraphValueType valueType;
}

class _ResolvedSubgraphNode {
  const _ResolvedSubgraphNode({
    required this.definition,
    this.compiledFunction,
    this.diagnostics = const <MathCompileDiagnostic>[],
  });

  final MathNodeDefinition definition;
  final MathCompiledFunction? compiledFunction;
  final List<MathCompileDiagnostic> diagnostics;
}

class _InputParameterMetadata {
  const _InputParameterMetadata({
    this.defaultValue,
    this.minValue,
    this.maxValue,
    this.step,
    this.valueUnit = GraphValueUnit.none,
  });

  final GraphValueData? defaultValue;
  final GraphValueData? minValue;
  final GraphValueData? maxValue;
  final double? step;
  final GraphValueUnit valueUnit;
}

class _VariableBinding {
  const _VariableBinding({
    required this.name,
    required this.valueType,
    required this.identifier,
    required this.initialized,
  });

  final String name;
  final GraphValueType valueType;
  final String identifier;
  final bool initialized;

  _VariableBinding copyWith({
    String? name,
    GraphValueType? valueType,
    String? identifier,
    bool? initialized,
  }) {
    return _VariableBinding(
      name: name ?? this.name,
      valueType: valueType ?? this.valueType,
      identifier: identifier ?? this.identifier,
      initialized: initialized ?? this.initialized,
    );
  }
}

class _CompilerState {
  _CompilerState({
    required this.graph,
    required this.options,
    required this.diagnostics,
    required this.nodesById,
    required this.definitionsByNodeId,
    required this.propertyById,
    required this.propertyDefinitionById,
    required this.linkByInputPropertyId,
    required this.subgraphResolutionByNodeId,
    required this.emitter,
  }) : functionName = _sanitizeFunctionName(
         options.functionName?.trim().isNotEmpty == true
             ? options.functionName!.trim()
             : graph.name,
       );

  final GraphDocument graph;
  final MathGraphCompileOptions options;
  final List<MathCompileDiagnostic> diagnostics;
  final Map<String, GraphNodeDocument> nodesById;
  final Map<String, MathNodeDefinition> definitionsByNodeId;
  final Map<String, GraphNodePropertyData> propertyById;
  final Map<String, GraphPropertyDefinition> propertyDefinitionById;
  final Map<String, GraphLinkDocument> linkByInputPropertyId;
  final Map<String, _ResolvedSubgraphNode> subgraphResolutionByNodeId;
  final MathGlslEmitter emitter;
  final String functionName;

  final List<MathFunctionParameter> parameters = <MathFunctionParameter>[];
  final List<MathIrStatement> statements = <MathIrStatement>[];
  final List<String> helperFunctionSources = <String>[];
  final Map<String, _ResolvedNodeValue> nodeValuesByPropertyId =
      <String, _ResolvedNodeValue>{};
  final Map<String, MathFunctionParameter> inputParameterByLogicalKey =
      <String, MathFunctionParameter>{};
  final Map<String, MathFunctionParameter> builtinParameterByLogicalKey =
      <String, MathFunctionParameter>{};
  final Map<int, MathFunctionParameter> samplerParameterByIndex =
      <int, MathFunctionParameter>{};
  final Map<String, _VariableBinding> variableByIdentifier =
      <String, _VariableBinding>{};
  final Set<String> usedIdentifiers = <String>{};
  int _temporaryIndex = 0;

  MathIrExpression? returnExpression;
  GraphValueType? returnType;

  void error({
    required String code,
    required String message,
    String? nodeId,
    String? propertyId,
  }) {
    diagnostics.add(
      MathCompileDiagnostic(
        severity: MathCompileDiagnosticSeverity.error,
        code: code,
        message: message,
        nodeId: nodeId,
        propertyId: propertyId,
      ),
    );
  }

  _ResolvedNodeValue? resolveInput(
    GraphNodeDocument node,
    MathNodeDefinition definition, {
    required String key,
  }) {
    final property = node.propertyByDefinitionKey(key);
    final propertyDefinition = _propertyDefinition(node.id, key);
    if (property == null || propertyDefinition == null) {
      error(
        code: 'missing_input_property',
        message:
            'Node `${definition.id}` is missing input property `$key` required for compilation.',
        nodeId: node.id,
      );
      return null;
    }
    final link = linkByInputPropertyId[property.id];
    if (link != null) {
      final upstream = nodeValuesByPropertyId[link.fromPropertyId];
      if (upstream == null) {
        error(
          code: 'missing_upstream_value',
          message:
              'Upstream property `${link.fromPropertyId}` did not produce a compiled value before `$key` was read.',
          nodeId: node.id,
          propertyId: property.id,
        );
        return null;
      }
      if (upstream.valueType != propertyDefinition.valueType) {
        error(
          code: 'resolved_type_mismatch',
          message:
              'Input `$key` expects `${propertyDefinition.valueType}` but received `${upstream.valueType}`.',
          nodeId: node.id,
          propertyId: property.id,
        );
        return null;
      }
      return upstream;
    }
    return _ResolvedNodeValue(
      expression: MathIrLiteralExpression(
        valueType: propertyDefinition.valueType,
        value: property.value.deepCopy(),
      ),
      valueType: propertyDefinition.valueType,
    );
  }

  void bindNodeValue(
    String propertyId,
    GraphValueType valueType,
    MathIrExpression expression,
  ) {
    final tempName = nextTemporaryName();
    statements.add(
      MathIrDeclareStatement(
        name: tempName,
        valueType: valueType,
        expression: expression,
      ),
    );
    nodeValuesByPropertyId[propertyId] = _ResolvedNodeValue(
      expression: MathIrReferenceExpression(
        valueType: valueType,
        identifier: tempName,
      ),
      valueType: valueType,
    );
  }

  void storeNodeValue(
    String propertyId,
    GraphValueType valueType,
    MathIrExpression expression,
  ) {
    nodeValuesByPropertyId[propertyId] = _ResolvedNodeValue(
      expression: expression,
      valueType: valueType,
    );
  }

  MathFunctionParameter? useInputParameter({
    required String identifier,
    required GraphValueType valueType,
    required String nodeId,
    GraphValueData? defaultValue,
    GraphValueData? minValue,
    GraphValueData? maxValue,
    double? step,
    GraphValueUnit valueUnit = GraphValueUnit.none,
  }) {
    final logicalKey = 'input:$identifier';
    final existing = inputParameterByLogicalKey[logicalKey];
    if (existing != null) {
      if (existing.valueType != valueType) {
        error(
          code: 'parameter_type_conflict',
          message:
              'Input `$identifier` is used with conflicting types `${existing.valueType}` and `$valueType`.',
          nodeId: nodeId,
        );
        return null;
      }
      return existing;
    }
    final parameter = MathFunctionParameter(
      kind: MathFunctionParameterKind.inputValue,
      name: uniqueIdentifier('in_${_sanitizeIdentifier(identifier)}'),
      valueType: valueType,
      rawIdentifier: identifier,
      defaultValue: defaultValue,
      minValue: minValue,
      maxValue: maxValue,
      step: step,
      valueUnit: valueUnit,
    );
    inputParameterByLogicalKey[logicalKey] = parameter;
    parameters.add(parameter);
    return parameter;
  }

  MathFunctionParameter useBuiltinParameter({
    required String identifier,
    required GraphValueType valueType,
  }) {
    final logicalKey = 'builtin:$identifier';
    final existing = builtinParameterByLogicalKey[logicalKey];
    if (existing != null) {
      return existing;
    }
    final parameter = MathFunctionParameter(
      kind: MathFunctionParameterKind.builtinValue,
      name: uniqueIdentifier(identifier),
      valueType: valueType,
      rawIdentifier: identifier,
    );
    builtinParameterByLogicalKey[logicalKey] = parameter;
    parameters.add(parameter);
    return parameter;
  }

  MathFunctionParameter useSamplerParameter(int index) {
    final existing = samplerParameterByIndex[index];
    if (existing != null) {
      return existing;
    }
    final parameter = MathFunctionParameter(
      kind: MathFunctionParameterKind.sampler2D,
      name: uniqueIdentifier('sampler_$index'),
      sourceIndex: index,
    );
    samplerParameterByIndex[index] = parameter;
    parameters.add(parameter);
    return parameter;
  }

  _VariableBinding? setVariable({
    required String identifier,
    required GraphValueType valueType,
    required MathIrExpression expression,
    required String nodeId,
  }) {
    final existing = variableByIdentifier[identifier];
    if (existing == null) {
      final created = _VariableBinding(
        name: uniqueIdentifier('var_${_sanitizeIdentifier(identifier)}'),
        valueType: valueType,
        identifier: identifier,
        initialized: true,
      );
      variableByIdentifier[identifier] = created;
      statements.add(
        MathIrDeclareStatement(
          name: created.name,
          valueType: valueType,
          expression: expression,
          mutable: true,
        ),
      );
      return created;
    }
    if (existing.valueType != valueType) {
      error(
        code: 'variable_type_conflict',
        message:
            'Variable `$identifier` is used with conflicting types `${existing.valueType}` and `$valueType`.',
        nodeId: nodeId,
      );
      return null;
    }
    if (!existing.initialized) {
      statements.add(
        MathIrDeclareStatement(
          name: existing.name,
          valueType: valueType,
          expression: expression,
          mutable: true,
        ),
      );
    } else {
      statements.add(
        MathIrAssignStatement(name: existing.name, expression: expression),
      );
    }
    final updated = existing.copyWith(initialized: true);
    variableByIdentifier[identifier] = updated;
    return updated;
  }

  _VariableBinding? getVariable({
    required String identifier,
    required GraphValueType expectedType,
    required String nodeId,
  }) {
    final variable =
        variableByIdentifier[identifier] ??
        _VariableBinding(
          name: uniqueIdentifier('var_${_sanitizeIdentifier(identifier)}'),
          valueType: expectedType,
          identifier: identifier,
          initialized: false,
        );
    variableByIdentifier[identifier] = variable;
    if (variable.valueType != expectedType) {
      error(
        code: 'variable_read_type_mismatch',
        message:
            'Variable `$identifier` has type `${variable.valueType}` but was read as `$expectedType`.',
        nodeId: nodeId,
      );
      return null;
    }
    return variable;
  }

  void validateVariables() {
    for (final variable in variableByIdentifier.values) {
      if (!variable.initialized) {
        error(
          code: 'unknown_variable',
          message:
              'Variable `${variable.identifier}` must be set before compilation completes.',
        );
      }
    }
  }

  void addHelperFunctionSource(String source) {
    if (helperFunctionSources.contains(source)) {
      return;
    }
    helperFunctionSources.add(source);
  }

  String nextTemporaryName() => 't${_temporaryIndex++}';

  String uniqueIdentifier(String base) {
    var normalized = _sanitizeIdentifier(base);
    if (normalized.isEmpty) {
      normalized = 'value';
    }
    if (!usedIdentifiers.contains(normalized)) {
      usedIdentifiers.add(normalized);
      return normalized;
    }
    var counter = 1;
    while (usedIdentifiers.contains('${normalized}_$counter')) {
      counter += 1;
    }
    final unique = '${normalized}_$counter';
    usedIdentifiers.add(unique);
    return unique;
  }

  GraphPropertyDefinition? _propertyDefinition(String nodeId, String key) {
    final definition = definitionsByNodeId[nodeId];
    if (definition == null) {
      return null;
    }
    for (final property in definition.properties) {
      if (property.key == key) {
        return property;
      }
    }
    return null;
  }

  static String _sanitizeFunctionName(String value) {
    final sanitized = _sanitizeIdentifier(value);
    if (sanitized.isEmpty) {
      return 'mathGraphFunction';
    }
    return sanitized;
  }

  static String _sanitizeIdentifier(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isAlphaNumeric =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122) ||
          codeUnit == 95;
      if (isAlphaNumeric) {
        buffer.write(char);
      } else {
        buffer.write('_');
      }
    }
    var result = buffer.toString().replaceAll(RegExp(r'_+'), '_');
    result = result.replaceAll(RegExp(r'^_+|_+$'), '');
    if (result.isEmpty) {
      return 'value';
    }
    if (RegExp(r'^[0-9]').hasMatch(result)) {
      result = 'v_$result';
    }
    return result;
  }
}
