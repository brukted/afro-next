import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import 'math_graph_ir.dart';

class MathGlslEmitter {
  const MathGlslEmitter();

  MathCompiledFunction emit(MathIrGraph ir) {
    final buffer = StringBuffer()
      ..writeln(_signature(ir))
      ..writeln('{');
    for (final statement in ir.statements) {
      buffer.writeln('  ${_emitStatement(statement)}');
    }
    buffer.writeln('  return ${_emitExpression(ir.returnExpression)};');
    buffer.writeln('}');

    return MathCompiledFunction(
      graphId: ir.graphId,
      functionName: ir.functionName,
      target: ir.target,
      returnType: ir.returnType,
      parameters: List<MathFunctionParameter>.unmodifiable(ir.parameters),
      topologicalNodeIds: List<String>.unmodifiable(ir.topologicalNodeIds),
      source: buffer.toString().trimRight(),
    );
  }

  String _signature(MathIrGraph ir) {
    final parameters = ir.parameters
        .map((parameter) => _emitParameter(parameter))
        .join(', ');
    return '${_glslType(ir.returnType)} ${ir.functionName}($parameters)';
  }

  String _emitParameter(MathFunctionParameter parameter) {
    if (parameter.kind == MathFunctionParameterKind.sampler2D) {
      return 'sampler2D ${parameter.name}';
    }
    return '${_glslType(parameter.valueType!)} ${parameter.name}';
  }

  String _emitStatement(MathIrStatement statement) {
    if (statement is MathIrDeclareStatement) {
      return '${_glslType(statement.valueType)} ${statement.name} = ${_emitExpression(statement.expression)};';
    }
    if (statement is MathIrAssignStatement) {
      return '${statement.name} = ${_emitExpression(statement.expression)};';
    }
    throw StateError('Unsupported IR statement: $statement');
  }

  String _emitExpression(MathIrExpression expression) {
    if (expression is MathIrLiteralExpression) {
      return _emitLiteral(expression.value);
    }
    if (expression is MathIrReferenceExpression) {
      return expression.identifier;
    }
    if (expression is MathIrUnaryExpression) {
      return '(${expression.operatorSymbol}${_emitExpression(expression.operand)})';
    }
    if (expression is MathIrBinaryExpression) {
      return '(${_emitExpression(expression.left)} ${expression.operatorSymbol} ${_emitExpression(expression.right)})';
    }
    if (expression is MathIrFunctionCallExpression) {
      final args = expression.arguments.map(_emitExpression).join(', ');
      return '${expression.functionName}($args)';
    }
    if (expression is MathIrConstructorExpression) {
      final args = expression.arguments.map(_emitExpression).join(', ');
      return '${_glslType(expression.valueType)}($args)';
    }
    if (expression is MathIrSwizzleExpression) {
      return '${_emitExpression(expression.input)}.${expression.components}';
    }
    if (expression is MathIrConditionalExpression) {
      return '(${_emitExpression(expression.condition)} ? ${_emitExpression(expression.whenTrue)} : ${_emitExpression(expression.whenFalse)})';
    }
    if (expression is MathIrTextureSampleExpression) {
      final sample = 'texture(${_emitExpression(expression.sampler)}, ${_emitExpression(expression.uv)})';
      if (!expression.greyscale) {
        return sample;
      }
      return 'dot($sample.rgb, vec3(0.299, 0.587, 0.114))';
    }
    throw StateError('Unsupported IR expression: $expression');
  }

  String _emitLiteral(GraphValueData value) {
    switch (value.valueType) {
      case GraphValueType.boolean:
        return (value.boolValue ?? false) ? 'true' : 'false';
      case GraphValueType.integer:
        return '${value.integerValue ?? 0}';
      case GraphValueType.integer2:
        return _emitIntVector('ivec2', value.integerValues, 2);
      case GraphValueType.integer3:
        return _emitIntVector('ivec3', value.integerValues, 3);
      case GraphValueType.integer4:
        return _emitIntVector('ivec4', value.integerValues, 4);
      case GraphValueType.float:
        return _formatFloat(value.floatValue ?? 0);
      case GraphValueType.float2:
        return _emitFloatVector('vec2', value.floatValues, 2);
      case GraphValueType.float3:
        return _emitFloatVector('vec3', value.floatValues, 3);
      case GraphValueType.float4:
        return _emitFloatVector('vec4', value.floatValues, 4);
      case GraphValueType.float3x3:
        final values = value.asFloat3x3().map(_formatFloat).join(', ');
        return 'mat3($values)';
      case GraphValueType.stringValue:
      case GraphValueType.workspaceResource:
      case GraphValueType.enumChoice:
      case GraphValueType.gradient:
      case GraphValueType.colorBezierCurve:
      case GraphValueType.textBlock:
        throw StateError('Unsupported literal type: ${value.valueType}');
    }
  }

  String _emitIntVector(String type, List<int>? values, int length) {
    final result = List<int>.generate(length, (index) {
      final source = values ?? const <int>[];
      return index < source.length ? source[index] : 0;
    });
    return '$type(${result.join(', ')})';
  }

  String _emitFloatVector(String type, List<double>? values, int length) {
    final result = List<double>.generate(length, (index) {
      final source = values ?? const <double>[];
      return index < source.length ? source[index] : 0;
    });
    return '$type(${result.map(_formatFloat).join(', ')})';
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

  String _formatFloat(double value) {
    if (value.isNaN || value.isInfinite) {
      return '0.0';
    }
    final rounded = value.toStringAsFixed(6);
    final trimmed = rounded
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.contains('.') ? trimmed : '$trimmed.0';
  }
}
