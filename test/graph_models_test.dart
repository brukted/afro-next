import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/graph/models/graph_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('graph value data round-trips newer Afro-aligned value types', () {
    final curve = GraphColorCurveData.identity();
    final values = <GraphValueData>[
      GraphValueData.integer(7),
      GraphValueData.integer3([1, 2, 3]),
      GraphValueData.float(0.25),
      GraphValueData.float2(Vector2(2, 4)),
      GraphValueData.float3(Vector3(1, 2, 3)),
      GraphValueData.float4(Vector4(0.1, 0.2, 0.3, 0.4)),
      GraphValueData.stringValue('hello'),
      GraphValueData.boolean(true),
      GraphValueData.enumChoice(4),
      GraphValueData.colorCurve(curve),
    ];

    for (final value in values) {
      final decoded = GraphValueData.fromJson(value.toJson());
      expect(decoded.valueType, value.valueType);
      expect(decoded.toJson(), value.toJson());
    }
  });

  test('graph value data decodes legacy scalar and color payloads', () {
    final scalar = GraphValueData.fromJson({
      'valueType': 'scalar',
      'scalarValue': 0.75,
    });
    final color = GraphValueData.fromJson({
      'valueType': 'color',
      'colorValue': [0.1, 0.2, 0.3, 0.4],
    });

    expect(scalar.valueType, GraphValueType.float);
    expect(scalar.unwrap(), 0.75);

    expect(color.valueType, GraphValueType.float4);
    expect(color.asFloat4().x, closeTo(0.1, 1e-6));
    expect(color.asFloat4().y, closeTo(0.2, 1e-6));
    expect(color.asFloat4().z, closeTo(0.3, 1e-6));
    expect(color.asFloat4().w, closeTo(0.4, 1e-6));
  });

  test('bezier spline splitAt inserts a shape-preserving interior point', () {
    final spline = GraphBezierSpline.identity().splitAt(0.5);

    expect(spline.points.length, 3);
    expect(spline.points[1].pos.x, closeTo(0.5, 1e-4));
    expect(spline.points[1].pos.y, closeTo(0.5, 1e-4));
    expect(spline.valueAt(0.25), closeTo(0.25, 1e-3));
    expect(spline.valueAt(0.75), closeTo(0.75, 1e-3));
  });

  test(
    'bezier spline move helpers clamp control points to a valid monotonic range',
    () {
      final spline = GraphBezierSpline.identity().splitAt(0.5);
      final movedAnchor = spline.moveAnchor(1, Vector2(0.9, 1.4));
      final movedIncoming = movedAnchor.moveIncomingTangent(1, Vector2(-1, -1));
      final movedOutgoing = movedIncoming.moveOutgoingTangent(1, Vector2(2, 2));

      expect(movedAnchor.points[1].pos.x, inInclusiveRange(0.0, 1.0));
      expect(movedAnchor.points[1].pos.y, inInclusiveRange(0.0, 1.0));
      expect(
        movedIncoming.points[1].t1.x,
        greaterThanOrEqualTo(movedIncoming.points[0].pos.x),
      );
      expect(
        movedIncoming.points[1].t1.x,
        lessThanOrEqualTo(movedIncoming.points[1].pos.x),
      );
      expect(
        movedOutgoing.points[1].t2.x,
        greaterThanOrEqualTo(movedOutgoing.points[1].pos.x),
      );
      expect(
        movedOutgoing.points[1].t2.x,
        lessThanOrEqualTo(movedOutgoing.points[2].pos.x),
      );
    },
  );
}
