import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../math_node_definition.dart';

enum MathCompileDiagnosticSeverity { error, warning }

class MathCompileDiagnostic {
  const MathCompileDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.nodeId,
    this.propertyId,
  });

  final MathCompileDiagnosticSeverity severity;
  final String code;
  final String message;
  final String? nodeId;
  final String? propertyId;

  bool get isError => severity == MathCompileDiagnosticSeverity.error;
}

enum MathFunctionParameterKind { inputValue, builtinValue, sampler2D }

class MathFunctionParameter {
  const MathFunctionParameter({
    required this.kind,
    required this.name,
    this.valueType,
    this.sourceIndex,
    this.rawIdentifier,
    this.defaultValue,
    this.minValue,
    this.maxValue,
    this.step,
    this.valueUnit = GraphValueUnit.none,
  });

  final MathFunctionParameterKind kind;
  final String name;
  final GraphValueType? valueType;
  final int? sourceIndex;
  final String? rawIdentifier;
  final GraphValueData? defaultValue;
  final GraphValueData? minValue;
  final GraphValueData? maxValue;
  final double? step;
  final GraphValueUnit valueUnit;
}

abstract class MathIrExpression {
  const MathIrExpression({required this.valueType});

  final GraphValueType valueType;
}

class MathIrLiteralExpression extends MathIrExpression {
  const MathIrLiteralExpression({required super.valueType, required this.value});

  final GraphValueData value;
}

class MathIrReferenceExpression extends MathIrExpression {
  const MathIrReferenceExpression({
    required super.valueType,
    required this.identifier,
  });

  final String identifier;
}

class MathIrUnaryExpression extends MathIrExpression {
  const MathIrUnaryExpression({
    required super.valueType,
    required this.operatorSymbol,
    required this.operand,
  });

  final String operatorSymbol;
  final MathIrExpression operand;
}

class MathIrBinaryExpression extends MathIrExpression {
  const MathIrBinaryExpression({
    required super.valueType,
    required this.left,
    required this.operatorSymbol,
    required this.right,
  });

  final MathIrExpression left;
  final String operatorSymbol;
  final MathIrExpression right;
}

class MathIrFunctionCallExpression extends MathIrExpression {
  const MathIrFunctionCallExpression({
    required super.valueType,
    required this.functionName,
    required this.arguments,
  });

  final String functionName;
  final List<MathIrExpression> arguments;
}

class MathIrConstructorExpression extends MathIrExpression {
  const MathIrConstructorExpression({
    required super.valueType,
    required this.arguments,
  });

  final List<MathIrExpression> arguments;
}

class MathIrSwizzleExpression extends MathIrExpression {
  const MathIrSwizzleExpression({
    required super.valueType,
    required this.input,
    required this.components,
  });

  final MathIrExpression input;
  final String components;
}

class MathIrConditionalExpression extends MathIrExpression {
  const MathIrConditionalExpression({
    required super.valueType,
    required this.condition,
    required this.whenTrue,
    required this.whenFalse,
  });

  final MathIrExpression condition;
  final MathIrExpression whenTrue;
  final MathIrExpression whenFalse;
}

class MathIrTextureSampleExpression extends MathIrExpression {
  const MathIrTextureSampleExpression({
    required super.valueType,
    required this.sampler,
    required this.uv,
    required this.greyscale,
  });

  final MathIrExpression sampler;
  final MathIrExpression uv;
  final bool greyscale;
}

abstract class MathIrStatement {
  const MathIrStatement();
}

class MathIrDeclareStatement extends MathIrStatement {
  const MathIrDeclareStatement({
    required this.name,
    required this.valueType,
    required this.expression,
    this.mutable = false,
  });

  final String name;
  final GraphValueType valueType;
  final MathIrExpression expression;
  final bool mutable;
}

class MathIrAssignStatement extends MathIrStatement {
  const MathIrAssignStatement({
    required this.name,
    required this.expression,
  });

  final String name;
  final MathIrExpression expression;
}

class MathIrGraph {
  const MathIrGraph({
    required this.graphId,
    required this.functionName,
    required this.target,
    required this.returnType,
    required this.parameters,
    required this.statements,
    required this.returnExpression,
    required this.topologicalNodeIds,
  });

  final String graphId;
  final String functionName;
  final MathGraphTarget target;
  final GraphValueType returnType;
  final List<MathFunctionParameter> parameters;
  final List<MathIrStatement> statements;
  final MathIrExpression returnExpression;
  final List<String> topologicalNodeIds;
}

class MathCompiledFunction {
  const MathCompiledFunction({
    required this.graphId,
    required this.functionName,
    required this.target,
    required this.returnType,
    required this.parameters,
    required this.topologicalNodeIds,
    required this.source,
  });

  final String graphId;
  final String functionName;
  final MathGraphTarget target;
  final GraphValueType returnType;
  final List<MathFunctionParameter> parameters;
  final List<String> topologicalNodeIds;
  final String source;
}

class MathCompileResult {
  const MathCompileResult({
    required this.diagnostics,
    this.ir,
    this.compiledFunction,
  });

  final List<MathCompileDiagnostic> diagnostics;
  final MathIrGraph? ir;
  final MathCompiledFunction? compiledFunction;

  bool get hasErrors => diagnostics.any((diagnostic) => diagnostic.isError);
}
