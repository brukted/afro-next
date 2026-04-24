import '../graph/models/graph_schema.dart';

enum MathGraphTarget { generic, valueProcessor, fxMap }

enum MathNodeKind {
  constant,
  inputParameter,
  builtin,
  sampler,
  operation,
  variableSet,
  variableGet,
  graphOutput,
  control,
}

enum MathNodeOperation {
  add,
  subtract,
  multiply,
  scalarMultiply,
  divide,
  modulo,
  negate,
  absolute,
  floor,
  ceil,
  minimum,
  maximum,
  lerp,
  sqrt,
  pow,
  log,
  exp,
  sin,
  cos,
  tan,
  dot,
  and,
  or,
  not,
  equal,
  notEqual,
  greater,
  greaterOrEqual,
  lower,
  lowerOrEqual,
  compose,
  swizzle,
  cast,
  ifElse,
  sequence,
}

enum MathResultTypePolicy {
  fixed,
  sameAsValueInput,
}

class MathNodeCompileMetadata {
  const MathNodeCompileMetadata({
    required this.kind,
    this.operation,
    this.resultTypePolicy = MathResultTypePolicy.fixed,
    this.supportedTargets = MathGraphTarget.values,
    this.outputPropertyKey = '_output',
    this.externalIdentifierPropertyKey,
    this.builtinIdentifier,
    this.samplerIndexPropertyKey,
    this.supportsSampling = false,
  });

  final MathNodeKind kind;
  final MathNodeOperation? operation;
  final List<MathGraphTarget> supportedTargets;
  final MathResultTypePolicy resultTypePolicy;
  final String outputPropertyKey;
  final String? externalIdentifierPropertyKey;
  final String? builtinIdentifier;
  final String? samplerIndexPropertyKey;
  final bool supportsSampling;
}

class MathNodeDefinition {
  const MathNodeDefinition({
    required this.schema,
    required this.compileMetadata,
  });

  final GraphNodeSchema schema;
  final MathNodeCompileMetadata compileMetadata;

  String get id => schema.id;

  String get label => schema.label;

  String get description => schema.description;

  List<GraphPropertyDefinition> get properties => schema.properties;

  GraphPropertyDefinition propertyDefinition(String key) {
    return schema.propertyDefinition(key);
  }

  GraphPropertyDefinition? get outputDefinition {
    for (final property in properties) {
      if (property.key == compileMetadata.outputPropertyKey) {
        return property;
      }
    }
    return null;
  }

  bool get isGraphOutput => compileMetadata.kind == MathNodeKind.graphOutput;

  bool get isInputParameter => compileMetadata.kind == MathNodeKind.inputParameter;
}
