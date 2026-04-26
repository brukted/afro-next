import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/graph/models/graph_schema.dart';
import 'package:afro/features/math_graph/math_node_definition.dart';
import 'package:afro/features/math_graph/runtime/math_glsl_emitter.dart';
import 'package:afro/features/math_graph/runtime/math_graph_ir.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emitter formats typed math IR into GLSL source', () {
    const ir = MathIrGraph(
      graphId: 'graph-1',
      functionName: 'emitGraph',
      target: MathGraphTarget.valueProcessor,
      returnType: GraphValueType.float,
      parameters: [
        MathFunctionParameter(
          kind: MathFunctionParameterKind.inputValue,
          name: 'in_value',
          valueType: GraphValueType.float,
        ),
        MathFunctionParameter(
          kind: MathFunctionParameterKind.sampler2D,
          name: 'sampler_0',
          sourceIndex: 0,
        ),
      ],
      statements: [
        MathIrDeclareStatement(
          name: 't0',
          valueType: GraphValueType.float,
          expression: MathIrLiteralExpression(
            valueType: GraphValueType.float,
            value: GraphValueData.float(1.25),
          ),
        ),
        MathIrDeclareStatement(
          name: 't1',
          valueType: GraphValueType.float,
          expression: MathIrTextureSampleExpression(
            valueType: GraphValueType.float,
            sampler: MathIrReferenceExpression(
              valueType: GraphValueType.workspaceResource,
              identifier: 'sampler_0',
            ),
            uv: MathIrConstructorExpression(
              valueType: GraphValueType.float2,
              arguments: [
                MathIrReferenceExpression(
                  valueType: GraphValueType.float,
                  identifier: 'in_value',
                ),
                MathIrLiteralExpression(
                  valueType: GraphValueType.float,
                  value: GraphValueData.float(0.5),
                ),
              ],
            ),
            greyscale: true,
          ),
        ),
      ],
      returnExpression: MathIrBinaryExpression(
        valueType: GraphValueType.float,
        left: MathIrReferenceExpression(
          valueType: GraphValueType.float,
          identifier: 't0',
        ),
        operatorSymbol: '+',
        right: MathIrReferenceExpression(
          valueType: GraphValueType.float,
          identifier: 't1',
        ),
      ),
      topologicalNodeIds: ['n0', 'n1'],
    );

    final compiled = const MathGlslEmitter().emit(ir);

    expect(
      compiled.source,
      '''
float emitGraph(float in_value, sampler2D sampler_0)
{
  float t0 = 1.25;
  float t1 = dot(texture(sampler_0, vec2(in_value, 0.5)).rgb, vec3(0.299, 0.587, 0.114));
  return (t0 + t1);
}''',
    );
  });
}
