import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../math_graph_catalog.dart';
import '../math_node_definition.dart';
import 'math_glsl_emitter.dart';
import 'math_graph_ir.dart';

class MathGraphCompileOptions {
  const MathGraphCompileOptions({
    this.functionName,
    this.target = MathGraphTarget.generic,
  });

  final String? functionName;
  final MathGraphTarget target;
}

class MathGraphCompiler {
  const MathGraphCompiler({
    required MathGraphCatalog catalog,
    MathGlslEmitter emitter = const MathGlslEmitter(),
  }) : _catalog = catalog,
       _emitter = emitter;

  final MathGraphCatalog _catalog;
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

    for (final node in graph.nodes) {
      MathNodeDefinition? definition;
      try {
        definition = _catalog.definitionById(node.definitionId);
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
    );
    final compiledFunction = _emitter.emit(ir);

    return MathCompileResult(
      diagnostics: List<MathCompileDiagnostic>.unmodifiable(diagnostics),
      ir: ir,
      compiledFunction: compiledFunction,
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

  void _compileConstant(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final property = node.propertyByDefinitionKey('value');
    final outputDefinition = definition.outputDefinition;
    if (property == null || outputDefinition == null) {
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
    state.bindNodeValue(node.id, outputDefinition.valueType, expression);
  }

  void _compileInputParameter(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final outputDefinition = definition.outputDefinition;
    final identifier = _readIdentifier(node, definition, state);
    if (outputDefinition == null || identifier == null) {
      return;
    }
    final parameter = state.useInputParameter(
      identifier: identifier,
      valueType: outputDefinition.valueType,
      nodeId: node.id,
    );
    if (parameter == null) {
      return;
    }
    state.storeNodeValue(
      node.id,
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
    final builtinIdentifier = definition.compileMetadata.builtinIdentifier;
    if (outputDefinition == null || builtinIdentifier == null) {
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
      node.id,
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
    final samplerKey = definition.compileMetadata.samplerIndexPropertyKey;
    if (outputDefinition == null || samplerKey == null) {
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
      node.id,
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
    final outputDefinition = definition.outputDefinition;
    final operation = definition.compileMetadata.operation;
    if (outputDefinition == null || operation == null) {
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
    }

    if (expression != null) {
      state.bindNodeValue(node.id, outputDefinition.valueType, expression);
    }
  }

  void _compileVariableSet(
    GraphNodeDocument node,
    MathNodeDefinition definition,
    _CompilerState state,
  ) {
    final identifier = _readIdentifier(node, definition, state);
    final outputDefinition = definition.outputDefinition;
    final value = state.resolveInput(node, definition, key: 'value');
    if (identifier == null || outputDefinition == null || value == null) {
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
      node.id,
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
    if (identifier == null || outputDefinition == null) {
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
      node.id,
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
}

class _ResolvedNodeValue {
  const _ResolvedNodeValue({required this.expression, required this.valueType});

  final MathIrExpression expression;
  final GraphValueType valueType;
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
  final MathGlslEmitter emitter;
  final String functionName;

  final List<MathFunctionParameter> parameters = <MathFunctionParameter>[];
  final List<MathIrStatement> statements = <MathIrStatement>[];
  final Map<String, _ResolvedNodeValue> nodeValuesByNodeId =
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
      final upstream = nodeValuesByNodeId[link.fromNodeId];
      if (upstream == null) {
        error(
          code: 'missing_upstream_value',
          message:
              'Upstream node `${link.fromNodeId}` did not produce a compiled value before `$key` was read.',
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
    String nodeId,
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
    nodeValuesByNodeId[nodeId] = _ResolvedNodeValue(
      expression: MathIrReferenceExpression(
        valueType: valueType,
        identifier: tempName,
      ),
      valueType: valueType,
    );
  }

  void storeNodeValue(
    String nodeId,
    GraphValueType valueType,
    MathIrExpression expression,
  ) {
    nodeValuesByNodeId[nodeId] = _ResolvedNodeValue(
      expression: expression,
      valueType: valueType,
    );
  }

  MathFunctionParameter? useInputParameter({
    required String identifier,
    required GraphValueType valueType,
    required String nodeId,
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
