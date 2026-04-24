import 'package:collection/collection.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../../math_graph/math_node_definition.dart';
import '../../math_graph/runtime/math_graph_compiler.dart';
import '../../math_graph/runtime/math_graph_ir.dart';
import '../../workspace/models/workspace_models.dart';
import '../../workspace/workspace_controller.dart';
import '../material_graph_catalog.dart';
import '../material_node_definition.dart';
import 'material_execution_ir.dart';

class MaterialGraphBackedNodeResolution {
  const MaterialGraphBackedNodeResolution({
    required this.definition,
    this.program,
    this.diagnostics = const <String>[],
  });

  final MaterialNodeDefinition definition;
  final MaterialCompiledProgram? program;
  final List<String> diagnostics;
}

class MaterialGraphBackedNodeResolver {
  const MaterialGraphBackedNodeResolver({
    required MaterialGraphCatalog catalog,
    WorkspaceController? workspaceController,
    MathGraphCompiler? mathGraphCompiler,
  }) : _catalog = catalog,
       _workspaceController = workspaceController,
       _mathGraphCompiler = mathGraphCompiler;

  final MaterialGraphCatalog _catalog;
  final WorkspaceController? _workspaceController;
  final MathGraphCompiler? _mathGraphCompiler;

  MaterialGraphBackedNodeResolution resolveNode(GraphNodeDocument node) {
    final baseDefinition = _catalog.definitionById(node.definitionId);
    if (node.definitionId != materialTexelGraphNodeDefinitionId) {
      return MaterialGraphBackedNodeResolution(definition: baseDefinition);
    }
    return _resolveTexelGraphNode(node: node, baseDefinition: baseDefinition);
  }

  MaterialGraphBackedNodeResolution _resolveTexelGraphNode({
    required GraphNodeDocument node,
    required MaterialNodeDefinition baseDefinition,
  }) {
    final resourceId =
        node
            .propertyByDefinitionKey(materialTexelGraphResourcePropertyKey)
            ?.value
            .asWorkspaceResource() ??
        '';
    if (resourceId.isEmpty) {
      return MaterialGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: const <String>[
          'Select a math graph to configure this node.',
        ],
      );
    }

    final workspaceController = _workspaceController;
    final mathGraphCompiler = _mathGraphCompiler;
    if (workspaceController == null ||
        mathGraphCompiler == null ||
        !workspaceController.isInitialized) {
      return MaterialGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: const <String>[
          'Workspace math graph resolution is unavailable.',
        ],
      );
    }

    final resource = workspaceController.resourceById(resourceId);
    if (resource == null || resource.kind != WorkspaceResourceKind.mathGraph) {
      return MaterialGraphBackedNodeResolution(
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
      return MaterialGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: <String>[
          'Math graph document for `${resource.name}` could not be found.',
        ],
      );
    }

    final compileResult = mathGraphCompiler.compile(
      document.graph,
      options: MathGraphCompileOptions(
        functionName: _materialFunctionName(resource.name),
        target: MathGraphTarget.generic,
      ),
    );
    final diagnostics = <String>[
      for (final diagnostic in compileResult.diagnostics)
        '${diagnostic.severity.name}: ${diagnostic.message}',
    ];
    final compiledFunction = compileResult.compiledFunction;
    if (compiledFunction == null) {
      return MaterialGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: diagnostics.isEmpty
            ? const <String>['Failed to compile the selected math graph.']
            : diagnostics,
      );
    }

    if (compiledFunction.returnType != GraphValueType.float &&
        compiledFunction.returnType != GraphValueType.float4) {
      return MaterialGraphBackedNodeResolution(
        definition: baseDefinition,
        diagnostics: <String>[
          ...diagnostics,
          'Texel Graph only supports math graphs returning float or float4.',
        ],
      );
    }

    final signatureDiagnostics = <String>[];
    final dynamicProperties = _dynamicPropertiesForMathFunction(
      compiledFunction,
      diagnostics: signatureDiagnostics,
    );
    final resolvedDefinition = baseDefinition.copyWith(
      schema: GraphNodeSchema(
        id: baseDefinition.schema.id,
        label: baseDefinition.schema.label,
        description: baseDefinition.schema.description,
        properties: _mergeDynamicProperties(
          baseDefinition.properties,
          dynamicProperties,
        ),
      ),
    );

    if (signatureDiagnostics.isNotEmpty) {
      return MaterialGraphBackedNodeResolution(
        definition: resolvedDefinition,
        diagnostics: [...diagnostics, ...signatureDiagnostics],
      );
    }

    final fragmentSource = _buildMathGraphFragmentWrapper(
      function: compiledFunction,
      valueParameters: dynamicProperties
          .where(
            (property) =>
                property.socketTransport == GraphSocketTransport.value,
          )
          .toList(growable: false),
    );
    return MaterialGraphBackedNodeResolution(
      definition: resolvedDefinition,
      diagnostics: diagnostics,
      program: MaterialCompiledProgram.generatedFragment(
        source: fragmentSource,
        cacheKey: 'texel_graph:${resource.documentId}:${_stableHash(fragmentSource)}',
      ),
    );
  }

  List<GraphPropertyDefinition> _dynamicPropertiesForMathFunction(
    MathCompiledFunction function, {
    required List<String> diagnostics,
  }) {
    final properties = <GraphPropertyDefinition>[];
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
              valueUnit: GraphValueUnit.none,
              defaultValue: _defaultValueForType(valueType),
              socketTransport: GraphSocketTransport.value,
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
          final samplerIndex = parameter.sourceIndex ?? 0;
          properties.add(
            GraphPropertyDefinition(
              key: parameter.name,
              label: 'Sampler $samplerIndex',
              description:
                  'Texture input sampled by the referenced math graph.',
              propertyType: GraphPropertyType.input,
              socket: true,
              valueType: GraphValueType.float4,
              valueUnit: GraphValueUnit.color,
              defaultValue: vmath.Vector4.zero(),
              socketTransport: GraphSocketTransport.texture,
            ),
          );
      }
    }
    return properties;
  }

  List<GraphPropertyDefinition> _mergeDynamicProperties(
    List<GraphPropertyDefinition> baseProperties,
    List<GraphPropertyDefinition> dynamicProperties,
  ) {
    final outputIndex = baseProperties.indexWhere(
      (property) => property.propertyType == GraphPropertyType.output,
    );
    if (outputIndex == -1 || dynamicProperties.isEmpty) {
      return baseProperties;
    }
    return <GraphPropertyDefinition>[
      ...baseProperties.take(outputIndex),
      ...dynamicProperties,
      ...baseProperties.skip(outputIndex),
    ];
  }

  String _buildMathGraphFragmentWrapper({
    required MathCompiledFunction function,
    required List<GraphPropertyDefinition> valueParameters,
  }) {
    final buffer = StringBuffer()
      ..writeln('#version 450')
      ..writeln('layout(location = 0) out vec4 outColor;')
      ..writeln('layout(set = 0, binding = 1) uniform sampler LinearClampSampler;');

    var sampledImageBinding = 2;
    for (final parameter in function.parameters.where(
      (parameter) => parameter.kind == MathFunctionParameterKind.sampler2D,
    )) {
      buffer.writeln(
        'layout(set = 0, binding = $sampledImageBinding) uniform texture2D ${parameter.name};',
      );
      sampledImageBinding += 1;
    }

    if (valueParameters.isNotEmpty) {
      buffer.writeln('layout(set = 0, binding = 0) uniform MaterialPassUniforms {');
      buffer.writeln('  vec4 _materialContext;');
      for (final property in valueParameters) {
        buffer.writeln('  ${_glslType(property.valueType)} ${property.key};');
      }
      buffer.writeln('} params;');
    } else {
      buffer.writeln('layout(set = 0, binding = 0) uniform MaterialPassUniforms {');
      buffer.writeln('  vec4 _materialContext;');
      buffer.writeln('} params;');
    }

    buffer
      ..writeln()
      ..writeln(function.source)
      ..writeln()
      ..writeln('void main() {')
      ..writeln(
        '  vec2 uv = gl_FragCoord.xy / max(params._materialContext.xy, vec2(1.0));',
      )
      ..write('  ${_glslType(function.returnType)} result = ');

    final callArguments = function.parameters.map((parameter) {
      return switch (parameter.kind) {
        MathFunctionParameterKind.inputValue => 'params.${parameter.name}',
        MathFunctionParameterKind.builtinValue => 'uv',
        MathFunctionParameterKind.sampler2D =>
          'sampler2D(${parameter.name}, LinearClampSampler)',
      };
    }).join(', ');
    buffer.writeln('${function.functionName}($callArguments);');
    if (function.returnType == GraphValueType.float) {
      buffer.writeln('  outColor = vec4(result, result, result, 1.0);');
    } else {
      buffer.writeln('  outColor = result;');
    }
    buffer.writeln('}');
    return buffer.toString().trimRight();
  }

  static String _materialFunctionName(String resourceName) {
    final sanitized = resourceName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'texel_graph' : 'texel_$sanitized';
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static String _glslType(GraphValueType valueType) {
    return switch (valueType) {
      GraphValueType.boolean => 'bool',
      GraphValueType.integer => 'int',
      GraphValueType.integer2 => 'ivec2',
      GraphValueType.integer3 => 'ivec3',
      GraphValueType.integer4 => 'ivec4',
      GraphValueType.float => 'float',
      GraphValueType.float2 => 'vec2',
      GraphValueType.float3 => 'vec3',
      GraphValueType.float4 => 'vec4',
      GraphValueType.float3x3 => 'mat3',
      _ => throw StateError('Unsupported generated GLSL type: $valueType'),
    };
  }

  static Object _defaultValueForType(GraphValueType valueType) {
    return switch (valueType) {
      GraphValueType.boolean => false,
      GraphValueType.integer => 0,
      GraphValueType.integer2 => const <int>[0, 0],
      GraphValueType.integer3 => const <int>[0, 0, 0],
      GraphValueType.integer4 => const <int>[0, 0, 0, 0],
      GraphValueType.float => 0.0,
      GraphValueType.float2 => vmath.Vector2.zero(),
      GraphValueType.float3 => vmath.Vector3.zero(),
      GraphValueType.float4 => vmath.Vector4.zero(),
      GraphValueType.float3x3 => const <double>[
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ],
      _ => throw StateError('Unsupported dynamic default type: $valueType'),
    };
  }
}
