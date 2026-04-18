import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../graph/models/graph_schema.dart';

class ColorBezierCurveEditor extends StatefulWidget {
  const ColorBezierCurveEditor({
    super.key,
    required this.curve,
    required this.onChanged,
  });

  final GraphColorCurveData curve;
  final ValueChanged<GraphColorCurveData> onChanged;

  @override
  State<ColorBezierCurveEditor> createState() => _ColorBezierCurveEditorState();
}

class _ColorBezierCurveEditorState extends State<ColorBezierCurveEditor> {
  GraphCurveChannel _activeChannel = GraphCurveChannel.luminance;
  _CurveHandleTarget? _dragTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spline = widget.curve.splineFor(_activeChannel).validated();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<GraphCurveChannel>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
            segments: GraphCurveChannel.values
                .map(
                  (channel) => ButtonSegment<GraphCurveChannel>(
                    value: channel,
                    label: Text(_channelLabel(channel)),
                  ),
                )
                .toList(growable: false),
            selected: {_activeChannel},
            onSelectionChanged: (selection) {
              setState(() {
                _activeChannel = selection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (details) =>
                    _insertPoint(details.localPosition, size),
                onPanStart: (details) =>
                    _beginDrag(details.localPosition, size),
                onPanUpdate: (details) =>
                    _updateDrag(details.localPosition, size),
                onPanEnd: (_) => _endDrag(),
                onPanCancel: _endDrag,
                child: CustomPaint(
                  painter: _CurveEditorPainter(
                    theme: theme,
                    spline: spline,
                    channel: _activeChannel,
                    activeTarget: _dragTarget,
                  ),
                  child: spline.hasEditableInteriorPoints
                      ? null
                      : Center(
                          child: Text(
                            'Double-click to add a point',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Edit one channel at a time. Interior anchors move both tangents.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _insertPoint(Offset localPosition, Size size) {
    final x = _canvasToCurve(localPosition, size).x;
    final nextSpline = widget.curve.splineFor(_activeChannel).splitAt(x);
    _commitSpline(nextSpline);
  }

  void _beginDrag(Offset localPosition, Size size) {
    final spline = widget.curve.splineFor(_activeChannel).validated();
    final target = _hitTest(localPosition, size, spline);
    if (target == null) {
      return;
    }

    setState(() {
      _dragTarget = target;
    });
  }

  void _updateDrag(Offset localPosition, Size size) {
    final target = _dragTarget;
    if (target == null) {
      return;
    }

    final curvePosition = _canvasToCurve(localPosition, size);
    final spline = widget.curve.splineFor(_activeChannel).validated();
    final nextSpline = switch (target.kind) {
      _CurveHandleKind.anchor => spline.moveAnchor(target.index, curvePosition),
      _CurveHandleKind.incoming => spline.moveIncomingTangent(
        target.index,
        curvePosition,
      ),
      _CurveHandleKind.outgoing => spline.moveOutgoingTangent(
        target.index,
        curvePosition,
      ),
    };
    _commitSpline(nextSpline);
  }

  void _endDrag() {
    if (_dragTarget == null) {
      return;
    }

    setState(() {
      _dragTarget = null;
    });
  }

  void _commitSpline(GraphBezierSpline spline) {
    widget.onChanged(
      widget.curve.copyWithSpline(_activeChannel, spline.validated()),
    );
  }

  _CurveHandleTarget? _hitTest(
    Offset localPosition,
    Size size,
    GraphBezierSpline spline,
  ) {
    const hitRadius = 16.0;
    final interiorIndices = List<int>.generate(
      math.max(0, spline.points.length - 2),
      (index) => index + 1,
      growable: false,
    );

    for (final index in interiorIndices) {
      final point = spline.points[index];
      if ((_curveToCanvas(point.pos, size) - localPosition).distance <=
          hitRadius) {
        return _CurveHandleTarget(index: index, kind: _CurveHandleKind.anchor);
      }
    }

    for (final index in interiorIndices) {
      final point = spline.points[index];
      if ((_curveToCanvas(point.t1, size) - localPosition).distance <=
          hitRadius) {
        return _CurveHandleTarget(
          index: index,
          kind: _CurveHandleKind.incoming,
        );
      }
      if ((_curveToCanvas(point.t2, size) - localPosition).distance <=
          hitRadius) {
        return _CurveHandleTarget(
          index: index,
          kind: _CurveHandleKind.outgoing,
        );
      }
    }

    return null;
  }
}

enum _CurveHandleKind { anchor, incoming, outgoing }

class _CurveHandleTarget {
  const _CurveHandleTarget({required this.index, required this.kind});

  final int index;
  final _CurveHandleKind kind;
}

class _CurveEditorPainter extends CustomPainter {
  const _CurveEditorPainter({
    required this.theme,
    required this.spline,
    required this.channel,
    required this.activeTarget,
  });

  final ThemeData theme;
  final GraphBezierSpline spline;
  final GraphCurveChannel channel;
  final _CurveHandleTarget? activeTarget;

  static const double _plotPadding = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      _plotPadding,
      _plotPadding,
      size.width - (_plotPadding * 2),
      size.height - (_plotPadding * 2),
    );
    final channelColor = _channelColor(channel, theme);
    final borderPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke;
    final surfacePaint = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.08,
      )
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
      ..strokeWidth = 1.2;
    final curvePaint = Paint()
      ..color = channelColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final borderPath = Path()
      ..addRRect(RRect.fromRectAndRadius(plotRect, const Radius.circular(10)));
    canvas.drawPath(borderPath, surfacePaint);
    canvas.drawPath(borderPath, borderPaint);

    for (var index = 1; index < 10; index += 1) {
      final dx = plotRect.left + (plotRect.width * index / 10);
      final dy = plotRect.top + (plotRect.height * index / 10);
      canvas.drawLine(
        Offset(dx, plotRect.top),
        Offset(dx, plotRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(plotRect.left, dy),
        Offset(plotRect.right, dy),
        gridPaint,
      );
    }

    final samplePoints = spline.samplePoints();
    final curvePath = Path();
    for (var index = 0; index < samplePoints.length; index += 1) {
      final point = _curveToCanvas(
        samplePoints[index],
        size,
        plotRect: plotRect,
      );
      if (index == 0) {
        curvePath.moveTo(point.dx, point.dy);
      } else {
        curvePath.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(curvePath, curvePaint);

    for (var index = 1; index < spline.points.length - 1; index += 1) {
      final point = spline.points[index];
      final anchor = _curveToCanvas(point.pos, size, plotRect: plotRect);
      final incoming = _curveToCanvas(point.t1, size, plotRect: plotRect);
      final outgoing = _curveToCanvas(point.t2, size, plotRect: plotRect);

      canvas.drawLine(anchor, incoming, linePaint);
      canvas.drawLine(anchor, outgoing, linePaint);
      _paintHandle(
        canvas,
        anchor,
        radius: 5.5,
        fillColor: channelColor,
        strokeColor: theme.colorScheme.surface,
        active:
            activeTarget?.index == index &&
            activeTarget?.kind == _CurveHandleKind.anchor,
      );
      _paintHandle(
        canvas,
        incoming,
        radius: 4.5,
        fillColor: theme.colorScheme.surfaceContainerLow,
        strokeColor: channelColor,
        active:
            activeTarget?.index == index &&
            activeTarget?.kind == _CurveHandleKind.incoming,
      );
      _paintHandle(
        canvas,
        outgoing,
        radius: 4.5,
        fillColor: theme.colorScheme.surfaceContainerLow,
        strokeColor: channelColor,
        active:
            activeTarget?.index == index &&
            activeTarget?.kind == _CurveHandleKind.outgoing,
      );
    }

    final endpoints = [spline.points.first.pos, spline.points.last.pos];
    for (final endpoint in endpoints) {
      _paintHandle(
        canvas,
        _curveToCanvas(endpoint, size, plotRect: plotRect),
        radius: 3.5,
        fillColor: channelColor.withValues(alpha: 0.8),
        strokeColor: theme.colorScheme.surface,
        active: false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurveEditorPainter oldDelegate) {
    return oldDelegate.spline.toJson().toString() !=
            spline.toJson().toString() ||
        oldDelegate.channel != channel ||
        oldDelegate.activeTarget?.index != activeTarget?.index ||
        oldDelegate.activeTarget?.kind != activeTarget?.kind ||
        oldDelegate.theme.colorScheme != theme.colorScheme;
  }

  void _paintHandle(
    Canvas canvas,
    Offset center, {
    required double radius,
    required Color fillColor,
    required Color strokeColor,
    required bool active,
  }) {
    canvas.drawCircle(
      center,
      active ? radius + 1.8 : radius,
      Paint()..color = strokeColor,
    );
    canvas.drawCircle(
      center,
      active ? radius + 0.4 : radius - 1,
      Paint()..color = fillColor,
    );
  }
}

String _channelLabel(GraphCurveChannel channel) {
  return switch (channel) {
    GraphCurveChannel.luminance => 'L',
    GraphCurveChannel.red => 'R',
    GraphCurveChannel.green => 'G',
    GraphCurveChannel.blue => 'B',
    GraphCurveChannel.alpha => 'A',
  };
}

Color _channelColor(GraphCurveChannel channel, ThemeData theme) {
  return switch (channel) {
    GraphCurveChannel.luminance => Colors.white,
    GraphCurveChannel.red => const Color(0xFFFF6B6B),
    GraphCurveChannel.green => const Color(0xFF6BFF9A),
    GraphCurveChannel.blue => const Color(0xFF62A8FF),
    GraphCurveChannel.alpha => theme.colorScheme.primary,
  };
}

Offset _curveToCanvas(Vector2 point, Size size, {Rect? plotRect}) {
  final rect =
      plotRect ??
      Rect.fromLTWH(
        _CurveEditorPainter._plotPadding,
        _CurveEditorPainter._plotPadding,
        size.width - (_CurveEditorPainter._plotPadding * 2),
        size.height - (_CurveEditorPainter._plotPadding * 2),
      );
  return Offset(
    rect.left + (point.x.clamp(0, 1) * rect.width),
    rect.bottom - (point.y.clamp(0, 1) * rect.height),
  );
}

Vector2 _canvasToCurve(Offset offset, Size size) {
  final rect = Rect.fromLTWH(
    _CurveEditorPainter._plotPadding,
    _CurveEditorPainter._plotPadding,
    size.width - (_CurveEditorPainter._plotPadding * 2),
    size.height - (_CurveEditorPainter._plotPadding * 2),
  );
  final x = ((offset.dx - rect.left) / rect.width).clamp(0, 1);
  final y = (1 - ((offset.dy - rect.top) / rect.height)).clamp(0, 1);
  return Vector2(x.toDouble(), y.toDouble());
}
