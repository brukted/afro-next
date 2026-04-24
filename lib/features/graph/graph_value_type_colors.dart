import 'package:flutter/material.dart';

import 'models/graph_schema.dart';

Color graphValueTypeSocketColor(
  GraphValueType valueType, {
  GraphValueUnit valueUnit = GraphValueUnit.none,
}) {
  if (valueUnit == GraphValueUnit.color &&
      (valueType == GraphValueType.float3 ||
          valueType == GraphValueType.float4)) {
    return const Color(0xFFFF6B6B);
  }

  return switch (valueType) {
    GraphValueType.boolean => const Color(0xFF7BD88F),
    GraphValueType.integer => const Color(0xFFFFC857),
    GraphValueType.integer2 => const Color(0xFFF7A541),
    GraphValueType.integer3 => const Color(0xFFF28C52),
    GraphValueType.integer4 => const Color(0xFFE76F51),
    GraphValueType.float => const Color(0xFF56CCF2),
    GraphValueType.float2 => const Color(0xFF4EA8DE),
    GraphValueType.float3 => const Color(0xFF3A86FF),
    GraphValueType.float4 => const Color(0xFF6C63FF),
    GraphValueType.float3x3 => const Color(0xFF9B5DE5),
    GraphValueType.stringValue => const Color(0xFFFF9F68),
    GraphValueType.workspaceResource => const Color(0xFF4DD0C8),
    GraphValueType.enumChoice => const Color(0xFFC77DFF),
    GraphValueType.gradient => const Color(0xFFFF4FA3),
    GraphValueType.colorBezierCurve => const Color(0xFFFF7D7D),
    GraphValueType.textBlock => const Color(0xFFFFB4A2),
  };
}
