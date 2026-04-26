import 'package:vector_math/vector_math.dart' as vmath;

import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'math_node_definition.dart';

class MathInputNodePropertyKeys {
  const MathInputNodePropertyKeys({
    this.identifier = 'identifier',
    this.defaultValue = 'defaultValue',
    this.unit = 'unit',
    this.hasMin = 'hasMin',
    this.min = 'min',
    this.hasMax = 'hasMax',
    this.max = 'max',
    this.step = 'step',
    this.output = '_output',
  });

  final String identifier;
  final String defaultValue;
  final String unit;
  final String hasMin;
  final String min;
  final String hasMax;
  final String max;
  final String step;
  final String output;
}

const mathInputNodePropertyKeys = MathInputNodePropertyKeys();
const String mathSubgraphNodeDefinitionId = 'math_subgraph_node';
const String mathSubgraphResourcePropertyKey = 'graph';

class MathInputNodeDescriptor {
  const MathInputNodeDescriptor({
    required this.definitionId,
    required this.label,
    required this.description,
    required this.valueType,
    required this.defaultIdentifier,
  });

  final String definitionId;
  final String label;
  final String description;
  final GraphValueType valueType;
  final String defaultIdentifier;
}

class MathVectorBreakoutNodeDescriptor {
  const MathVectorBreakoutNodeDescriptor({
    required this.definitionId,
    required this.label,
    required this.description,
    required this.inputType,
    required this.outputType,
    required this.componentKeys,
  });

  final String definitionId;
  final String label;
  final String description;
  final GraphValueType inputType;
  final GraphValueType outputType;
  final List<String> componentKeys;
}

const List<MathInputNodeDescriptor> mathInputNodeDescriptors =
    <MathInputNodeDescriptor>[
      MathInputNodeDescriptor(
        definitionId: 'get_boolean_node',
        label: 'Get Boolean',
        description: 'Reads a boolean function input.',
        valueType: GraphValueType.boolean,
        defaultIdentifier: 'inputBool',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_integer1_node',
        label: 'Get Integer1',
        description: 'Reads an integer function input.',
        valueType: GraphValueType.integer,
        defaultIdentifier: 'inputInt',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_integer2_node',
        label: 'Get Integer2',
        description: 'Reads an ivec2 function input.',
        valueType: GraphValueType.integer2,
        defaultIdentifier: 'inputInt2',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_integer3_node',
        label: 'Get Integer3',
        description: 'Reads an ivec3 function input.',
        valueType: GraphValueType.integer3,
        defaultIdentifier: 'inputInt3',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_integer4_node',
        label: 'Get Integer4',
        description: 'Reads an ivec4 function input.',
        valueType: GraphValueType.integer4,
        defaultIdentifier: 'inputInt4',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_float1_node',
        label: 'Get Float1',
        description: 'Reads a float function input.',
        valueType: GraphValueType.float,
        defaultIdentifier: 'inputFloat',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_float2_node',
        label: 'Get Float2',
        description: 'Reads a vec2 function input.',
        valueType: GraphValueType.float2,
        defaultIdentifier: 'inputFloat2',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_float3_node',
        label: 'Get Float3',
        description: 'Reads a vec3 function input.',
        valueType: GraphValueType.float3,
        defaultIdentifier: 'inputFloat3',
      ),
      MathInputNodeDescriptor(
        definitionId: 'get_float4_node',
        label: 'Get Float4',
        description: 'Reads a vec4 function input.',
        valueType: GraphValueType.float4,
        defaultIdentifier: 'inputFloat4',
      ),
    ];

const List<MathVectorBreakoutNodeDescriptor> mathVectorBreakoutNodeDescriptors =
    <MathVectorBreakoutNodeDescriptor>[
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_integer2_node',
        label: 'Break Integer2',
        description: 'Breaks an ivec2 into integer components.',
        inputType: GraphValueType.integer2,
        outputType: GraphValueType.integer,
        componentKeys: <String>['x', 'y'],
      ),
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_integer3_node',
        label: 'Break Integer3',
        description: 'Breaks an ivec3 into integer components.',
        inputType: GraphValueType.integer3,
        outputType: GraphValueType.integer,
        componentKeys: <String>['x', 'y', 'z'],
      ),
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_integer4_node',
        label: 'Break Integer4',
        description: 'Breaks an ivec4 into integer components.',
        inputType: GraphValueType.integer4,
        outputType: GraphValueType.integer,
        componentKeys: <String>['x', 'y', 'z', 'w'],
      ),
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_float2_node',
        label: 'Break Float2',
        description: 'Breaks a vec2 into float components.',
        inputType: GraphValueType.float2,
        outputType: GraphValueType.float,
        componentKeys: <String>['x', 'y'],
      ),
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_float3_node',
        label: 'Break Float3',
        description: 'Breaks a vec3 into float components.',
        inputType: GraphValueType.float3,
        outputType: GraphValueType.float,
        componentKeys: <String>['x', 'y', 'z'],
      ),
      MathVectorBreakoutNodeDescriptor(
        definitionId: 'break_float4_node',
        label: 'Break Float4',
        description: 'Breaks a vec4 into float components.',
        inputType: GraphValueType.float4,
        outputType: GraphValueType.float,
        componentKeys: <String>['x', 'y', 'z', 'w'],
      ),
    ];

class MathGraphCatalog {
  MathGraphCatalog(this._idFactory);

  final IdFactory _idFactory;

  late final List<MathNodeDefinition> _definitions = <MathNodeDefinition>[
    ..._scalarConstantNodes(),
    ..._inputParameterNodes(),
    _builtinPosNode(),
    ..._vectorComposeNodes(),
    ..._vectorBreakoutNodes(),
    ..._vectorSwizzleNodes(),
    ..._castNodes(),
    ..._binaryArithmeticNodes(),
    ..._scalarMultiplyNodes(),
    ..._scalarDivisionAndModuloNodes(),
    ..._unaryArithmeticNodes(),
    ..._minMaxNodes(),
    _lerpNode(),
    ..._transcendentalNodes(),
    ..._dotNodes(),
    ..._booleanNodes(),
    ..._comparisonNodes(),
    ..._controlNodes(),
    ..._variableNodes(),
    ..._samplerNodes(),
    _subgraphNode(),
    ..._graphOutputNodes(),
  ];

  List<MathNodeDefinition> get definitions =>
      List<MathNodeDefinition>.unmodifiable(_definitions);

  MathNodeDefinition definitionById(String id) {
    return _definitions.firstWhere((definition) => definition.id == id);
  }

  GraphNodeDocument instantiateNode({
    required String definitionId,
    vmath.Vector2? position,
    String? name,
  }) {
    final definition = definitionById(definitionId);
    return GraphNodeDocument(
      id: _idFactory.next(),
      definitionId: definition.id,
      name: name ?? definition.label,
      position: position?.clone() ?? vmath.Vector2.zero(),
      properties: definition.properties
          .map(
            (property) => GraphNodePropertyData(
              id: _idFactory.next(),
              definitionKey: property.key,
              value: defaultValueForProperty(property),
            ),
          )
          .toList(growable: false),
    );
  }

  GraphValueData defaultValueForProperty(GraphPropertyDefinition definition) {
    switch (definition.valueType) {
      case GraphValueType.integer:
        return GraphValueData.integer((definition.defaultValue as num).toInt());
      case GraphValueType.integer2:
        return GraphValueData.integer2(asIntVector(definition.defaultValue));
      case GraphValueType.integer3:
        return GraphValueData.integer3(asIntVector(definition.defaultValue));
      case GraphValueType.integer4:
        return GraphValueData.integer4(asIntVector(definition.defaultValue));
      case GraphValueType.float:
        return GraphValueData.float(
          (definition.defaultValue as num).toDouble(),
        );
      case GraphValueType.float2:
        return GraphValueData.float2(asVector2(definition.defaultValue));
      case GraphValueType.float3:
        return GraphValueData.float3(asVector3(definition.defaultValue));
      case GraphValueType.float4:
        return GraphValueData.float4(asVector4(definition.defaultValue));
      case GraphValueType.float3x3:
        return GraphValueData.float3x3(asFloat3x3(definition.defaultValue));
      case GraphValueType.stringValue:
        return GraphValueData.stringValue(definition.defaultValue as String);
      case GraphValueType.workspaceResource:
        return GraphValueData.workspaceResource(
          asResourceId(definition.defaultValue),
        );
      case GraphValueType.boolean:
        return GraphValueData.boolean(definition.defaultValue as bool);
      case GraphValueType.enumChoice:
        return GraphValueData.enumChoice(definition.defaultValue as int);
      case GraphValueType.gradient:
        return GraphValueData.gradient(asGradient(definition.defaultValue));
      case GraphValueType.colorBezierCurve:
        return GraphValueData.colorCurve(asColorCurve(definition.defaultValue));
      case GraphValueType.textBlock:
        return GraphValueData.textBlock(asTextData(definition.defaultValue));
    }
  }

  List<MathNodeDefinition> _scalarConstantNodes() {
    return <MathNodeDefinition>[
      _constantNode(
        id: 'boolean_constant_node',
        label: 'Boolean',
        description: 'Produces a constant boolean value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.boolean,
        defaultValue: false,
      ),
      _constantNode(
        id: 'integer_constant_node',
        label: 'Integer',
        description: 'Produces a constant integer value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.integer,
        defaultValue: 0,
      ),
      _constantNode(
        id: 'integer2_constant_node',
        label: 'Integer2',
        description: 'Produces a constant ivec2 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.integer2,
        defaultValue: const <int>[0, 0],
      ),
      _constantNode(
        id: 'integer3_constant_node',
        label: 'Integer3',
        description: 'Produces a constant ivec3 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.integer3,
        defaultValue: const <int>[0, 0, 0],
      ),
      _constantNode(
        id: 'integer4_constant_node',
        label: 'Integer4',
        description: 'Produces a constant ivec4 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.integer4,
        defaultValue: const <int>[0, 0, 0, 0],
      ),
      _constantNode(
        id: 'float_constant_node',
        label: 'Float',
        description: 'Produces a constant float value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.float,
        defaultValue: 0.0,
      ),
      _constantNode(
        id: 'float2_constant_node',
        label: 'Float2',
        description: 'Produces a constant vec2 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.float2,
        defaultValue: vmath.Vector2.zero(),
      ),
      _constantNode(
        id: 'float3_constant_node',
        label: 'Float3',
        description: 'Produces a constant vec3 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.float3,
        defaultValue: vmath.Vector3.zero(),
      ),
      _constantNode(
        id: 'float4_constant_node',
        label: 'Float4',
        description: 'Produces a constant vec4 value.',
        propertyLabel: 'Value',
        valueType: GraphValueType.float4,
        defaultValue: vmath.Vector4.zero(),
      ),
    ];
  }

  List<MathNodeDefinition> _inputParameterNodes() {
    return mathInputNodeDescriptors
        .map((descriptor) => _inputNode(descriptor: descriptor))
        .toList(growable: false);
  }

  MathNodeDefinition _builtinPosNode() {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: 'builtin_pos_node',
        label: 'Builtin Pos',
        description: 'Reads the builtin float2 position value.',
        properties: [
          _outputSocket(
            key: '_output',
            label: 'Output',
            valueType: GraphValueType.float2,
          ),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.builtin,
        builtinIdentifier: 'pos',
      ),
    );
  }

  List<MathNodeDefinition> _vectorComposeNodes() {
    return <MathNodeDefinition>[
      _composeNode(
        id: 'vector_float2_node',
        label: 'Vector Float2',
        description: 'Constructs a vec2 from two scalar inputs.',
        outputType: GraphValueType.float2,
        inputTypes: const <GraphValueType>[
          GraphValueType.float,
          GraphValueType.float,
        ],
      ),
      _composeNode(
        id: 'vector_float3_node',
        label: 'Vector Float3',
        description: 'Constructs a vec3 from scalar inputs.',
        outputType: GraphValueType.float3,
        inputTypes: const <GraphValueType>[
          GraphValueType.float,
          GraphValueType.float,
          GraphValueType.float,
        ],
      ),
      _composeNode(
        id: 'vector_float4_node',
        label: 'Vector Float4',
        description: 'Constructs a vec4 from scalar inputs.',
        outputType: GraphValueType.float4,
        inputTypes: const <GraphValueType>[
          GraphValueType.float,
          GraphValueType.float,
          GraphValueType.float,
          GraphValueType.float,
        ],
      ),
    ];
  }

  List<MathNodeDefinition> _vectorBreakoutNodes() {
    return mathVectorBreakoutNodeDescriptors
        .map((descriptor) => _breakoutNode(descriptor: descriptor))
        .toList(growable: false);
  }

  List<MathNodeDefinition> _vectorSwizzleNodes() {
    return <MathNodeDefinition>[
      _swizzleNode(
        id: 'swizzle_float1_node',
        label: 'Swizzle Float1',
        description: 'Extracts one component from a float vector.',
        outputType: GraphValueType.float,
        defaultMask: 'x',
      ),
      _swizzleNode(
        id: 'swizzle_float2_node',
        label: 'Swizzle Float2',
        description: 'Extracts two components from a float vector.',
        outputType: GraphValueType.float2,
        defaultMask: 'xy',
      ),
      _swizzleNode(
        id: 'swizzle_float3_node',
        label: 'Swizzle Float3',
        description: 'Extracts three components from a float vector.',
        outputType: GraphValueType.float3,
        defaultMask: 'xyz',
      ),
      _swizzleNode(
        id: 'swizzle_float4_node',
        label: 'Swizzle Float4',
        description: 'Extracts four components from a float vector.',
        outputType: GraphValueType.float4,
        defaultMask: 'xyzw',
      ),
    ];
  }

  List<MathNodeDefinition> _castNodes() {
    return <MathNodeDefinition>[
      _castNode(
        id: 'to_float_node',
        label: 'To Float',
        description: 'Casts an integer to float.',
        inputType: GraphValueType.integer,
        outputType: GraphValueType.float,
      ),
      _castNode(
        id: 'to_float2_node',
        label: 'To Float2',
        description: 'Casts an ivec2 to vec2.',
        inputType: GraphValueType.integer2,
        outputType: GraphValueType.float2,
      ),
      _castNode(
        id: 'to_float3_node',
        label: 'To Float3',
        description: 'Casts an ivec3 to vec3.',
        inputType: GraphValueType.integer3,
        outputType: GraphValueType.float3,
      ),
      _castNode(
        id: 'to_float4_node',
        label: 'To Float4',
        description: 'Casts an ivec4 to vec4.',
        inputType: GraphValueType.integer4,
        outputType: GraphValueType.float4,
      ),
      _castNode(
        id: 'to_integer_node',
        label: 'To Integer',
        description: 'Casts a float to int.',
        inputType: GraphValueType.float,
        outputType: GraphValueType.integer,
      ),
      _castNode(
        id: 'to_integer2_node',
        label: 'To Integer2',
        description: 'Casts a vec2 to ivec2.',
        inputType: GraphValueType.float2,
        outputType: GraphValueType.integer2,
      ),
      _castNode(
        id: 'to_integer3_node',
        label: 'To Integer3',
        description: 'Casts a vec3 to ivec3.',
        inputType: GraphValueType.float3,
        outputType: GraphValueType.integer3,
      ),
      _castNode(
        id: 'to_integer4_node',
        label: 'To Integer4',
        description: 'Casts a vec4 to ivec4.',
        inputType: GraphValueType.float4,
        outputType: GraphValueType.integer4,
      ),
    ];
  }

  List<MathNodeDefinition> _binaryArithmeticNodes() {
    return <MathNodeDefinition>[
      ..._sameTypeBinaryNodes(
        prefix: 'add',
        label: 'Add',
        description: 'Adds two values.',
        operation: MathNodeOperation.add,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.integer2,
          GraphValueType.integer3,
          GraphValueType.integer4,
          GraphValueType.float,
          GraphValueType.float2,
          GraphValueType.float3,
          GraphValueType.float4,
        ],
      ),
      ..._sameTypeBinaryNodes(
        prefix: 'subtract',
        label: 'Subtraction',
        description: 'Subtracts two values.',
        operation: MathNodeOperation.subtract,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.integer2,
          GraphValueType.integer3,
          GraphValueType.integer4,
          GraphValueType.float,
          GraphValueType.float2,
          GraphValueType.float3,
          GraphValueType.float4,
        ],
      ),
      ..._sameTypeBinaryNodes(
        prefix: 'multiply',
        label: 'Multiplication',
        description: 'Multiplies two values.',
        operation: MathNodeOperation.multiply,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.integer2,
          GraphValueType.integer3,
          GraphValueType.integer4,
          GraphValueType.float,
          GraphValueType.float2,
          GraphValueType.float3,
          GraphValueType.float4,
        ],
      ),
    ];
  }

  List<MathNodeDefinition> _scalarMultiplyNodes() {
    return <MathNodeDefinition>[
      _binaryNode(
        id: 'scalar_multiply_float2_node',
        label: 'Scalar Multiply Float2',
        description: 'Multiplies a vec2 by a float.',
        leftType: GraphValueType.float2,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float2,
        operation: MathNodeOperation.scalarMultiply,
      ),
      _binaryNode(
        id: 'scalar_multiply_float3_node',
        label: 'Scalar Multiply Float3',
        description: 'Multiplies a vec3 by a float.',
        leftType: GraphValueType.float3,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float3,
        operation: MathNodeOperation.scalarMultiply,
      ),
      _binaryNode(
        id: 'scalar_multiply_float4_node',
        label: 'Scalar Multiply Float4',
        description: 'Multiplies a vec4 by a float.',
        leftType: GraphValueType.float4,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float4,
        operation: MathNodeOperation.scalarMultiply,
      ),
    ];
  }

  List<MathNodeDefinition> _scalarDivisionAndModuloNodes() {
    return <MathNodeDefinition>[
      _binaryNode(
        id: 'division_float_node',
        label: 'Division Float',
        description: 'Divides two floats.',
        leftType: GraphValueType.float,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.divide,
      ),
      _binaryNode(
        id: 'division_integer_node',
        label: 'Division Integer',
        description: 'Divides two integers.',
        leftType: GraphValueType.integer,
        rightType: GraphValueType.integer,
        outputType: GraphValueType.integer,
        operation: MathNodeOperation.divide,
      ),
      _binaryNode(
        id: 'modulo_float_node',
        label: 'Modulo Float',
        description: 'Returns the float modulo.',
        leftType: GraphValueType.float,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.modulo,
      ),
      _binaryNode(
        id: 'modulo_integer_node',
        label: 'Modulo Integer',
        description: 'Returns the integer modulo.',
        leftType: GraphValueType.integer,
        rightType: GraphValueType.integer,
        outputType: GraphValueType.integer,
        operation: MathNodeOperation.modulo,
      ),
    ];
  }

  List<MathNodeDefinition> _unaryArithmeticNodes() {
    return <MathNodeDefinition>[
      ..._unaryNodes(
        prefix: 'negation',
        label: 'Negation',
        description: 'Negates the input value.',
        operation: MathNodeOperation.negate,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.float,
        ],
      ),
      ..._unaryNodes(
        prefix: 'absolute',
        label: 'Absolute',
        description: 'Returns the absolute value.',
        operation: MathNodeOperation.absolute,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.float,
        ],
      ),
      ..._unaryNodes(
        prefix: 'floor',
        label: 'Floor',
        description: 'Returns floor(a).',
        operation: MathNodeOperation.floor,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'ceil',
        label: 'Ceil',
        description: 'Returns ceil(a).',
        operation: MathNodeOperation.ceil,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
    ];
  }

  List<MathNodeDefinition> _minMaxNodes() {
    return <MathNodeDefinition>[
      ..._sameTypeBinaryNodes(
        prefix: 'minimum',
        label: 'Minimum',
        description: 'Returns the minimum value.',
        operation: MathNodeOperation.minimum,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.float,
        ],
      ),
      ..._sameTypeBinaryNodes(
        prefix: 'maximum',
        label: 'Maximum',
        description: 'Returns the maximum value.',
        operation: MathNodeOperation.maximum,
        valueTypes: const <GraphValueType>[
          GraphValueType.integer,
          GraphValueType.float,
        ],
      ),
    ];
  }

  MathNodeDefinition _lerpNode() {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: 'linear_interpolation_float_node',
        label: 'Linear Interpolation',
        description: 'Returns the linear interpolation between two floats.',
        properties: [
          _inputSocket(key: 'a', label: 'A', valueType: GraphValueType.float),
          _inputSocket(key: 'b', label: 'B', valueType: GraphValueType.float),
          _inputSocket(key: 'x', label: 'X', valueType: GraphValueType.float),
          _outputSocket(
            key: '_output',
            label: 'Output',
            valueType: GraphValueType.float,
          ),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: MathNodeOperation.lerp,
      ),
    );
  }

  List<MathNodeDefinition> _transcendentalNodes() {
    return <MathNodeDefinition>[
      ..._unaryNodes(
        prefix: 'sqrt',
        label: 'Square Root',
        description: 'Returns sqrt(a).',
        operation: MathNodeOperation.sqrt,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'log',
        label: 'Logarithmic',
        description: 'Returns log(a).',
        operation: MathNodeOperation.log,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'exp',
        label: 'Exponential',
        description: 'Returns exp(a).',
        operation: MathNodeOperation.exp,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'sine',
        label: 'Sine',
        description: 'Returns sin(a).',
        operation: MathNodeOperation.sin,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'cosine',
        label: 'Cosine',
        description: 'Returns cos(a).',
        operation: MathNodeOperation.cos,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      ..._unaryNodes(
        prefix: 'tangent',
        label: 'Tangent',
        description: 'Returns tan(a).',
        operation: MathNodeOperation.tan,
        valueTypes: const <GraphValueType>[GraphValueType.float],
      ),
      _binaryNode(
        id: 'pow_float_node',
        label: 'Pow',
        description: 'Returns pow(a, b).',
        leftType: GraphValueType.float,
        rightType: GraphValueType.float,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.pow,
      ),
    ];
  }

  List<MathNodeDefinition> _dotNodes() {
    return <MathNodeDefinition>[
      _binaryNode(
        id: 'dot_float2_node',
        label: 'Dot Float2',
        description: 'Returns the vec2 dot product.',
        leftType: GraphValueType.float2,
        rightType: GraphValueType.float2,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.dot,
      ),
      _binaryNode(
        id: 'dot_float3_node',
        label: 'Dot Float3',
        description: 'Returns the vec3 dot product.',
        leftType: GraphValueType.float3,
        rightType: GraphValueType.float3,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.dot,
      ),
      _binaryNode(
        id: 'dot_float4_node',
        label: 'Dot Float4',
        description: 'Returns the vec4 dot product.',
        leftType: GraphValueType.float4,
        rightType: GraphValueType.float4,
        outputType: GraphValueType.float,
        operation: MathNodeOperation.dot,
      ),
    ];
  }

  List<MathNodeDefinition> _booleanNodes() {
    return <MathNodeDefinition>[
      _binaryNode(
        id: 'and_boolean_node',
        label: 'And',
        description: 'Returns true if both boolean values are true.',
        leftType: GraphValueType.boolean,
        rightType: GraphValueType.boolean,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.and,
      ),
      _binaryNode(
        id: 'or_boolean_node',
        label: 'Or',
        description: 'Returns true if at least one boolean value is true.',
        leftType: GraphValueType.boolean,
        rightType: GraphValueType.boolean,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.or,
      ),
      _unaryNode(
        id: 'not_boolean_node',
        label: 'Not',
        description: 'Negates the boolean input.',
        inputType: GraphValueType.boolean,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.not,
      ),
    ];
  }

  List<MathNodeDefinition> _comparisonNodes() {
    return <MathNodeDefinition>[
      ..._comparisonNodesForType(GraphValueType.float, 'float'),
      ..._comparisonNodesForType(GraphValueType.integer, 'integer'),
    ];
  }

  List<MathNodeDefinition> _comparisonNodesForType(
    GraphValueType valueType,
    String suffix,
  ) {
    return <MathNodeDefinition>[
      _binaryNode(
        id: 'equal_${suffix}_node',
        label: 'Equal ${_typeLabel(valueType)}',
        description: 'Returns true when a == b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.equal,
      ),
      _binaryNode(
        id: 'not_equal_${suffix}_node',
        label: 'Not Equal ${_typeLabel(valueType)}',
        description: 'Returns true when a != b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.notEqual,
      ),
      _binaryNode(
        id: 'greater_${suffix}_node',
        label: 'Greater ${_typeLabel(valueType)}',
        description: 'Returns true when a > b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.greater,
      ),
      _binaryNode(
        id: 'greater_or_equal_${suffix}_node',
        label: 'Greater Or Equal ${_typeLabel(valueType)}',
        description: 'Returns true when a >= b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.greaterOrEqual,
      ),
      _binaryNode(
        id: 'lower_${suffix}_node',
        label: 'Lower ${_typeLabel(valueType)}',
        description: 'Returns true when a < b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.lower,
      ),
      _binaryNode(
        id: 'lower_or_equal_${suffix}_node',
        label: 'Lower Or Equal ${_typeLabel(valueType)}',
        description: 'Returns true when a <= b.',
        leftType: valueType,
        rightType: valueType,
        outputType: GraphValueType.boolean,
        operation: MathNodeOperation.lowerOrEqual,
      ),
    ];
  }

  List<MathNodeDefinition> _controlNodes() {
    return <MathNodeDefinition>[
      ..._typedControlNodes(
        prefix: 'if_else',
        label: 'If Else',
        description: 'Returns the true branch when the condition is true.',
        operation: MathNodeOperation.ifElse,
        valueTypes: const <GraphValueType>[
          GraphValueType.boolean,
          GraphValueType.integer,
          GraphValueType.integer2,
          GraphValueType.integer3,
          GraphValueType.integer4,
          GraphValueType.float,
          GraphValueType.float2,
          GraphValueType.float3,
          GraphValueType.float4,
        ],
      ),
      ..._typedControlNodes(
        prefix: 'sequence',
        label: 'Sequence',
        description: 'Evaluates the first input before the second.',
        operation: MathNodeOperation.sequence,
        valueTypes: const <GraphValueType>[
          GraphValueType.boolean,
          GraphValueType.integer,
          GraphValueType.integer2,
          GraphValueType.integer3,
          GraphValueType.integer4,
          GraphValueType.float,
          GraphValueType.float2,
          GraphValueType.float3,
          GraphValueType.float4,
        ],
      ),
    ];
  }

  List<MathNodeDefinition> _variableNodes() {
    return <MathNodeDefinition>[
      ..._setGetNodes(GraphValueType.boolean, 'boolean'),
      ..._setGetNodes(GraphValueType.integer, 'integer'),
      ..._setGetNodes(GraphValueType.integer2, 'integer2'),
      ..._setGetNodes(GraphValueType.integer3, 'integer3'),
      ..._setGetNodes(GraphValueType.integer4, 'integer4'),
      ..._setGetNodes(GraphValueType.float, 'float'),
      ..._setGetNodes(GraphValueType.float2, 'float2'),
      ..._setGetNodes(GraphValueType.float3, 'float3'),
      ..._setGetNodes(GraphValueType.float4, 'float4'),
    ];
  }

  List<MathNodeDefinition> _samplerNodes() {
    return <MathNodeDefinition>[
      MathNodeDefinition(
        schema: GraphNodeSchema(
          id: 'sample_grey_node',
          label: 'Sample Grey',
          description: 'Samples a grayscale value from an image input.',
          properties: [
            _descriptorSourceIndex(),
            _inputSocket(
              key: 'uv',
              label: 'UV',
              valueType: GraphValueType.float2,
            ),
            _outputSocket(
              key: '_output',
              label: 'Output',
              valueType: GraphValueType.float,
            ),
          ],
        ),
        compileMetadata: const MathNodeCompileMetadata(
          kind: MathNodeKind.sampler,
          samplerIndexPropertyKey: 'sourceIndex',
          supportsSampling: true,
        ),
      ),
      MathNodeDefinition(
        schema: GraphNodeSchema(
          id: 'sample_color_node',
          label: 'Sample Color',
          description: 'Samples a color value from an image input.',
          properties: [
            _descriptorSourceIndex(),
            _inputSocket(
              key: 'uv',
              label: 'UV',
              valueType: GraphValueType.float2,
            ),
            _outputSocket(
              key: '_output',
              label: 'Output',
              valueType: GraphValueType.float4,
            ),
          ],
        ),
        compileMetadata: const MathNodeCompileMetadata(
          kind: MathNodeKind.sampler,
          samplerIndexPropertyKey: 'sourceIndex',
          supportsSampling: true,
        ),
      ),
    ];
  }

  List<MathNodeDefinition> _graphOutputNodes() {
    return <MathNodeDefinition>[
      ..._graphOutputNodesForTypes(const <GraphValueType>[
        GraphValueType.boolean,
        GraphValueType.integer,
        GraphValueType.integer2,
        GraphValueType.integer3,
        GraphValueType.integer4,
        GraphValueType.float,
        GraphValueType.float2,
        GraphValueType.float3,
        GraphValueType.float4,
      ]),
    ];
  }

  MathNodeDefinition _subgraphNode() {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: mathSubgraphNodeDefinitionId,
        label: 'Math Subgraph',
        description:
            'Runs a referenced workspace math graph and forwards its public inputs.',
        properties: [
          GraphPropertyDefinition(
            key: mathSubgraphResourcePropertyKey,
            label: 'Math Graph',
            description: 'Select a workspace math graph to invoke.',
            propertyType: GraphPropertyType.descriptor,
            socket: false,
            valueType: GraphValueType.workspaceResource,
            valueUnit: GraphValueUnit.path,
            defaultValue: '',
            resourceKinds: const [GraphResourceKind.mathGraph],
          ),
          _outputSocket(
            key: '_output',
            label: 'Output',
            valueType: GraphValueType.float,
          ),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.subgraph,
      ),
    );
  }

  List<MathNodeDefinition> _graphOutputNodesForTypes(
    List<GraphValueType> valueTypes,
  ) {
    return valueTypes
        .map(
          (valueType) => MathNodeDefinition(
            schema: GraphNodeSchema(
              id: 'output_${_typeSuffix(valueType)}_node',
              label: 'Output ${_typeLabel(valueType)}',
              description: 'Declares the final function output.',
              properties: [
                _inputSocket(
                  key: 'value',
                  label: 'Value',
                  valueType: valueType,
                ),
              ],
            ),
            compileMetadata: const MathNodeCompileMetadata(
              kind: MathNodeKind.graphOutput,
              outputPropertyKey: 'value',
            ),
          ),
        )
        .toList(growable: false);
  }

  List<MathNodeDefinition> _sameTypeBinaryNodes({
    required String prefix,
    required String label,
    required String description,
    required MathNodeOperation operation,
    required List<GraphValueType> valueTypes,
  }) {
    return valueTypes
        .map(
          (valueType) => _binaryNode(
            id: '${prefix}_${_typeSuffix(valueType)}_node',
            label: '$label ${_typeLabel(valueType)}',
            description: description,
            leftType: valueType,
            rightType: valueType,
            outputType: valueType,
            operation: operation,
          ),
        )
        .toList(growable: false);
  }

  List<MathNodeDefinition> _unaryNodes({
    required String prefix,
    required String label,
    required String description,
    required MathNodeOperation operation,
    required List<GraphValueType> valueTypes,
  }) {
    return valueTypes
        .map(
          (valueType) => _unaryNode(
            id: '${prefix}_${_typeSuffix(valueType)}_node',
            label: '$label ${_typeLabel(valueType)}',
            description: description,
            inputType: valueType,
            outputType: valueType,
            operation: operation,
          ),
        )
        .toList(growable: false);
  }

  List<MathNodeDefinition> _typedControlNodes({
    required String prefix,
    required String label,
    required String description,
    required MathNodeOperation operation,
    required List<GraphValueType> valueTypes,
  }) {
    return valueTypes
        .map(
          (valueType) => MathNodeDefinition(
            schema: GraphNodeSchema(
              id: '${prefix}_${_typeSuffix(valueType)}_node',
              label: '$label ${_typeLabel(valueType)}',
              description: description,
              properties: operation == MathNodeOperation.ifElse
                  ? [
                      _inputSocket(
                        key: 'condition',
                        label: 'Condition',
                        valueType: GraphValueType.boolean,
                      ),
                      _inputSocket(key: 'a', label: 'A', valueType: valueType),
                      _inputSocket(key: 'b', label: 'B', valueType: valueType),
                      _outputSocket(
                        key: '_output',
                        label: 'Output',
                        valueType: valueType,
                      ),
                    ]
                  : [
                      _inputSocket(
                        key: 'first',
                        label: 'First',
                        valueType: valueType,
                      ),
                      _inputSocket(
                        key: 'second',
                        label: 'Second',
                        valueType: valueType,
                      ),
                      _outputSocket(
                        key: '_output',
                        label: 'Output',
                        valueType: valueType,
                      ),
                    ],
            ),
            compileMetadata: MathNodeCompileMetadata(
              kind: MathNodeKind.control,
              operation: operation,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<MathNodeDefinition> _setGetNodes(
    GraphValueType valueType,
    String suffix,
  ) {
    return <MathNodeDefinition>[
      MathNodeDefinition(
        schema: GraphNodeSchema(
          id: 'set_${suffix}_node',
          label: 'Set ${_typeLabel(valueType)}',
          description: 'Stores a value into a local variable.',
          properties: [
            _descriptorIdentifier(defaultValue: 'var${_typeLabel(valueType)}'),
            _inputSocket(key: 'value', label: 'Value', valueType: valueType),
            _outputSocket(
              key: '_output',
              label: 'Output',
              valueType: valueType,
            ),
          ],
        ),
        compileMetadata: const MathNodeCompileMetadata(
          kind: MathNodeKind.variableSet,
          externalIdentifierPropertyKey: 'identifier',
        ),
      ),
      MathNodeDefinition(
        schema: GraphNodeSchema(
          id: 'get_${suffix}_node',
          label: 'Get ${_typeLabel(valueType)}',
          description: 'Reads a local variable value.',
          properties: [
            _descriptorIdentifier(defaultValue: 'var'),
            _outputSocket(
              key: '_output',
              label: 'Output',
              valueType: valueType,
            ),
          ],
        ),
        compileMetadata: const MathNodeCompileMetadata(
          kind: MathNodeKind.variableGet,
          externalIdentifierPropertyKey: 'identifier',
        ),
      ),
    ];
  }

  MathNodeDefinition _constantNode({
    required String id,
    required String label,
    required String description,
    required String propertyLabel,
    required GraphValueType valueType,
    required Object defaultValue,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          GraphPropertyDefinition(
            key: 'value',
            label: propertyLabel,
            description: description,
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: valueType,
            valueUnit: GraphValueUnit.none,
            defaultValue: defaultValue,
            isEditable: true,
          ),
          _outputSocket(key: '_output', label: 'Output', valueType: valueType),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.constant,
      ),
    );
  }

  MathNodeDefinition _inputNode({required MathInputNodeDescriptor descriptor}) {
    final unitOptions = _unitOptionsForValueType(descriptor.valueType);
    final supportsRange = _supportsRangeMetadata(descriptor.valueType);
    final supportsStep = _supportsStepMetadata(descriptor.valueType);
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: descriptor.definitionId,
        label: descriptor.label,
        description: descriptor.description,
        properties: [
          _descriptorIdentifier(defaultValue: descriptor.defaultIdentifier),
          GraphPropertyDefinition(
            key: mathInputNodePropertyKeys.defaultValue,
            label: 'Default',
            description:
                'Default value exposed for this graph input when no external value is provided.',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: descriptor.valueType,
            valueUnit: GraphValueUnit.none,
            defaultValue: _defaultValueForType(descriptor.valueType),
            isEditable: true,
          ),
          if (unitOptions.length > 1)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.unit,
              label: 'Unit',
              description: 'Presentation unit for this graph input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: GraphValueType.enumChoice,
              valueUnit: GraphValueUnit.none,
              defaultValue: unitOptions.first.value,
              isEditable: true,
              enumOptions: unitOptions,
            ),
          if (supportsRange)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.hasMin,
              label: 'Has Min',
              description: 'Enable a soft minimum hint for this input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: GraphValueType.boolean,
              valueUnit: GraphValueUnit.none,
              defaultValue: false,
              isEditable: true,
            ),
          if (supportsRange)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.min,
              label: 'Min',
              description: 'Soft minimum value for this input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: descriptor.valueType,
              valueUnit: GraphValueUnit.none,
              defaultValue: _defaultValueForType(descriptor.valueType),
              isEditable: true,
            ),
          if (supportsRange)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.hasMax,
              label: 'Has Max',
              description: 'Enable a soft maximum hint for this input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: GraphValueType.boolean,
              valueUnit: GraphValueUnit.none,
              defaultValue: false,
              isEditable: true,
            ),
          if (supportsRange)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.max,
              label: 'Max',
              description: 'Soft maximum value for this input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: descriptor.valueType,
              valueUnit: GraphValueUnit.none,
              defaultValue: _defaultMaxValueForType(descriptor.valueType),
              isEditable: true,
            ),
          if (supportsStep)
            GraphPropertyDefinition(
              key: mathInputNodePropertyKeys.step,
              label: 'Step',
              description: 'Suggested editor increment for this input.',
              propertyType: GraphPropertyType.input,
              socket: false,
              valueType: GraphValueType.float,
              valueUnit: GraphValueUnit.none,
              defaultValue: _defaultStepForType(descriptor.valueType),
              isEditable: true,
              min: 0.0001,
              max: 1024,
              step: 0.01,
            ),
          _outputSocket(
            key: mathInputNodePropertyKeys.output,
            label: 'Output',
            valueType: descriptor.valueType,
          ),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.inputParameter,
        externalIdentifierPropertyKey: 'identifier',
      ),
    );
  }

  MathNodeDefinition _breakoutNode({
    required MathVectorBreakoutNodeDescriptor descriptor,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: descriptor.definitionId,
        label: descriptor.label,
        description: descriptor.description,
        properties: [
          _inputSocket(
            key: 'input',
            label: 'Input',
            valueType: descriptor.inputType,
          ),
          for (final componentKey in descriptor.componentKeys)
            _outputSocket(
              key: componentKey,
              label: componentKey.toUpperCase(),
              valueType: descriptor.outputType,
            ),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: MathNodeOperation.breakout,
      ),
    );
  }

  MathNodeDefinition _composeNode({
    required String id,
    required String label,
    required String description,
    required GraphValueType outputType,
    required List<GraphValueType> inputTypes,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          for (var index = 0; index < inputTypes.length; index += 1)
            _inputSocket(
              key: 'in$index',
              label: 'In ${index + 1}',
              valueType: inputTypes[index],
            ),
          _outputSocket(key: '_output', label: 'Output', valueType: outputType),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: MathNodeOperation.compose,
      ),
    );
  }

  MathNodeDefinition _swizzleNode({
    required String id,
    required String label,
    required String description,
    required GraphValueType outputType,
    required String defaultMask,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          GraphPropertyDefinition(
            key: 'components',
            label: 'Components',
            description: 'Swizzle mask such as x, xy, xyz or xyzw.',
            propertyType: GraphPropertyType.descriptor,
            socket: false,
            valueType: GraphValueType.stringValue,
            valueUnit: GraphValueUnit.none,
            defaultValue: defaultMask,
            isEditable: true,
          ),
          _inputSocket(
            key: 'input',
            label: 'Input',
            valueType: GraphValueType.float4,
          ),
          _outputSocket(key: '_output', label: 'Output', valueType: outputType),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: MathNodeOperation.swizzle,
      ),
    );
  }

  MathNodeDefinition _castNode({
    required String id,
    required String label,
    required String description,
    required GraphValueType inputType,
    required GraphValueType outputType,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          _inputSocket(key: 'value', label: 'Value', valueType: inputType),
          _outputSocket(key: '_output', label: 'Output', valueType: outputType),
        ],
      ),
      compileMetadata: const MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: MathNodeOperation.cast,
      ),
    );
  }

  MathNodeDefinition _binaryNode({
    required String id,
    required String label,
    required String description,
    required GraphValueType leftType,
    required GraphValueType rightType,
    required GraphValueType outputType,
    required MathNodeOperation operation,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          _inputSocket(key: 'a', label: 'A', valueType: leftType),
          _inputSocket(key: 'b', label: 'B', valueType: rightType),
          _outputSocket(key: '_output', label: 'Output', valueType: outputType),
        ],
      ),
      compileMetadata: MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: operation,
      ),
    );
  }

  MathNodeDefinition _unaryNode({
    required String id,
    required String label,
    required String description,
    required GraphValueType inputType,
    required GraphValueType outputType,
    required MathNodeOperation operation,
  }) {
    return MathNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          _inputSocket(key: 'value', label: 'Value', valueType: inputType),
          _outputSocket(key: '_output', label: 'Output', valueType: outputType),
        ],
      ),
      compileMetadata: MathNodeCompileMetadata(
        kind: MathNodeKind.operation,
        operation: operation,
      ),
    );
  }

  static GraphPropertyDefinition _inputSocket({
    required String key,
    required String label,
    required GraphValueType valueType,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: label,
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: valueType,
      valueUnit: GraphValueUnit.none,
      defaultValue: _defaultValueForType(valueType),
    );
  }

  static GraphPropertyDefinition _outputSocket({
    required String key,
    required String label,
    required GraphValueType valueType,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: label,
      propertyType: GraphPropertyType.output,
      socket: true,
      valueType: valueType,
      valueUnit: GraphValueUnit.none,
      defaultValue: _defaultValueForType(valueType),
    );
  }

  static GraphPropertyDefinition _descriptorIdentifier({
    required String defaultValue,
  }) {
    return GraphPropertyDefinition(
      key: mathInputNodePropertyKeys.identifier,
      label: 'Identifier',
      description: 'Public identifier used by the generated function.',
      propertyType: GraphPropertyType.descriptor,
      socket: false,
      valueType: GraphValueType.stringValue,
      valueUnit: GraphValueUnit.none,
      defaultValue: defaultValue,
      isEditable: true,
    );
  }

  static List<EnumChoiceOption> _unitOptionsForValueType(
    GraphValueType valueType,
  ) {
    return switch (valueType) {
      GraphValueType.integer => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'power2',
          label: 'Power of Two',
          value: _unitEnumValue(GraphValueUnit.power2),
        ),
      ],
      GraphValueType.integer2 => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'position',
          label: 'Position',
          value: _unitEnumValue(GraphValueUnit.position),
        ),
        EnumChoiceOption(
          id: 'power2',
          label: 'Power of Two',
          value: _unitEnumValue(GraphValueUnit.power2),
        ),
      ],
      GraphValueType.integer3 => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'position',
          label: 'Position',
          value: _unitEnumValue(GraphValueUnit.position),
        ),
      ],
      GraphValueType.float => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'rotation',
          label: 'Rotation',
          value: _unitEnumValue(GraphValueUnit.rotation),
        ),
      ],
      GraphValueType.float2 => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'position',
          label: 'Position',
          value: _unitEnumValue(GraphValueUnit.position),
        ),
        EnumChoiceOption(
          id: 'power2',
          label: 'Power of Two',
          value: _unitEnumValue(GraphValueUnit.power2),
        ),
      ],
      GraphValueType.float3 => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'position',
          label: 'Position',
          value: _unitEnumValue(GraphValueUnit.position),
        ),
        EnumChoiceOption(
          id: 'color',
          label: 'Color',
          value: _unitEnumValue(GraphValueUnit.color),
        ),
      ],
      GraphValueType.float4 => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
        EnumChoiceOption(
          id: 'color',
          label: 'Color',
          value: _unitEnumValue(GraphValueUnit.color),
        ),
      ],
      _ => <EnumChoiceOption>[
        EnumChoiceOption(
          id: 'none',
          label: 'None',
          value: _unitEnumValue(GraphValueUnit.none),
        ),
      ],
    };
  }

  static int _unitEnumValue(GraphValueUnit unit) => unit.index;

  static bool _supportsRangeMetadata(GraphValueType valueType) {
    return switch (valueType) {
      GraphValueType.integer ||
      GraphValueType.integer2 ||
      GraphValueType.integer3 ||
      GraphValueType.integer4 ||
      GraphValueType.float ||
      GraphValueType.float2 ||
      GraphValueType.float3 ||
      GraphValueType.float4 => true,
      _ => false,
    };
  }

  static bool _supportsStepMetadata(GraphValueType valueType) {
    return switch (valueType) {
      GraphValueType.integer ||
      GraphValueType.integer2 ||
      GraphValueType.integer3 ||
      GraphValueType.integer4 ||
      GraphValueType.float ||
      GraphValueType.float2 ||
      GraphValueType.float3 ||
      GraphValueType.float4 => true,
      _ => false,
    };
  }

  static GraphPropertyDefinition _descriptorSourceIndex() {
    return GraphPropertyDefinition(
      key: 'sourceIndex',
      label: 'Source Index',
      description: 'Image input index used by the generated wrapper.',
      propertyType: GraphPropertyType.descriptor,
      socket: false,
      valueType: GraphValueType.integer,
      valueUnit: GraphValueUnit.none,
      defaultValue: 0,
      min: 0,
      isEditable: true,
    );
  }

  static Object _defaultValueForType(GraphValueType valueType) {
    switch (valueType) {
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
        return const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
      case GraphValueType.stringValue:
        return '';
      case GraphValueType.workspaceResource:
        return '';
      case GraphValueType.boolean:
        return false;
      case GraphValueType.enumChoice:
        return 0;
      case GraphValueType.gradient:
        return GraphGradientData.identity();
      case GraphValueType.colorBezierCurve:
        return GraphColorCurveData.identity();
      case GraphValueType.textBlock:
        return GraphTextData.defaults();
    }
  }

  static Object _defaultMaxValueForType(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.integer:
        return 1;
      case GraphValueType.integer2:
        return const <int>[1, 1];
      case GraphValueType.integer3:
        return const <int>[1, 1, 1];
      case GraphValueType.integer4:
        return const <int>[1, 1, 1, 1];
      case GraphValueType.float:
        return 1.0;
      case GraphValueType.float2:
        return vmath.Vector2.all(1.0);
      case GraphValueType.float3:
        return vmath.Vector3.all(1.0);
      case GraphValueType.float4:
        return vmath.Vector4.all(1.0);
      default:
        return _defaultValueForType(valueType);
    }
  }

  static double _defaultStepForType(GraphValueType valueType) {
    return switch (valueType) {
      GraphValueType.integer ||
      GraphValueType.integer2 ||
      GraphValueType.integer3 ||
      GraphValueType.integer4 => 1.0,
      _ => 0.01,
    };
  }

  static String _typeSuffix(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.integer:
        return 'integer';
      case GraphValueType.integer2:
        return 'integer2';
      case GraphValueType.integer3:
        return 'integer3';
      case GraphValueType.integer4:
        return 'integer4';
      case GraphValueType.float:
        return 'float';
      case GraphValueType.float2:
        return 'float2';
      case GraphValueType.float3:
        return 'float3';
      case GraphValueType.float4:
        return 'float4';
      case GraphValueType.float3x3:
        return 'float3x3';
      case GraphValueType.stringValue:
        return 'string';
      case GraphValueType.workspaceResource:
        return 'workspace_resource';
      case GraphValueType.boolean:
        return 'boolean';
      case GraphValueType.enumChoice:
        return 'enum';
      case GraphValueType.gradient:
        return 'gradient';
      case GraphValueType.colorBezierCurve:
        return 'curve';
      case GraphValueType.textBlock:
        return 'text';
    }
  }

  static String _typeLabel(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.integer:
        return 'Integer';
      case GraphValueType.integer2:
        return 'Integer2';
      case GraphValueType.integer3:
        return 'Integer3';
      case GraphValueType.integer4:
        return 'Integer4';
      case GraphValueType.float:
        return 'Float';
      case GraphValueType.float2:
        return 'Float2';
      case GraphValueType.float3:
        return 'Float3';
      case GraphValueType.float4:
        return 'Float4';
      case GraphValueType.float3x3:
        return 'Float3x3';
      case GraphValueType.stringValue:
        return 'String';
      case GraphValueType.workspaceResource:
        return 'Workspace Resource';
      case GraphValueType.boolean:
        return 'Boolean';
      case GraphValueType.enumChoice:
        return 'Enum';
      case GraphValueType.gradient:
        return 'Gradient';
      case GraphValueType.colorBezierCurve:
        return 'Curve';
      case GraphValueType.textBlock:
        return 'Text';
    }
  }
}
