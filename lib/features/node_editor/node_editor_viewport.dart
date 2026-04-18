import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class NodeEditorViewport {
  const NodeEditorViewport({
    required this.scale,
    required this.translation,
  });

  final double scale;
  final Offset translation;

  Offset sceneToScreen(Offset scenePoint) {
    return Offset(
      (scenePoint.dx * scale) + translation.dx,
      (scenePoint.dy * scale) + translation.dy,
    );
  }

  Offset screenToScene(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - translation.dx) / scale,
      (screenPoint.dy - translation.dy) / scale,
    );
  }

  Rect visibleSceneRect(Size viewportSize) {
    return Rect.fromPoints(
      screenToScene(Offset.zero),
      screenToScene(Offset(viewportSize.width, viewportSize.height)),
    );
  }

  NodeEditorViewport copyWith({
    double? scale,
    Offset? translation,
  }) {
    return NodeEditorViewport(
      scale: scale ?? this.scale,
      translation: translation ?? this.translation,
    );
  }
}

class NodeEditorViewportController extends ChangeNotifier {
  NodeEditorViewportController({
    double initialScale = 1,
    Offset initialTranslation = Offset.zero,
    this.minScale = 0.25,
    this.maxScale = 2.5,
  }) : _viewport = NodeEditorViewport(
         scale: initialScale,
         translation: initialTranslation,
       );

  final double minScale;
  final double maxScale;

  NodeEditorViewport _viewport;

  NodeEditorViewport get viewport => _viewport;

  double get scale => _viewport.scale;

  Offset get translation => _viewport.translation;

  Offset sceneToScreen(Offset scenePoint) => _viewport.sceneToScreen(scenePoint);

  Offset screenToScene(Offset screenPoint) => _viewport.screenToScene(screenPoint);

  Rect visibleSceneRect(Size viewportSize) =>
      _viewport.visibleSceneRect(viewportSize);

  void jumpTo({
    double? scale,
    Offset? translation,
  }) {
    final nextScale = (scale ?? _viewport.scale).clamp(minScale, maxScale).toDouble();
    _viewport = _viewport.copyWith(
      scale: nextScale,
      translation: translation,
    );
    notifyListeners();
  }

  void centerScenePoint({
    required Offset scenePoint,
    required Size viewportSize,
    double? scale,
  }) {
    final nextScale = (scale ?? _viewport.scale).clamp(minScale, maxScale).toDouble();
    final nextTranslation = Offset(
      (viewportSize.width / 2) - (scenePoint.dx * nextScale),
      (viewportSize.height / 2) - (scenePoint.dy * nextScale),
    );
    jumpTo(scale: nextScale, translation: nextTranslation);
  }

  void focusSceneRect({
    required Rect sceneRect,
    required Size viewportSize,
    double padding = 36,
  }) {
    if (sceneRect.isEmpty) {
      centerScenePoint(
        scenePoint: sceneRect.center,
        viewportSize: viewportSize,
      );
      return;
    }

    final safeWidth = (viewportSize.width - (padding * 2)).clamp(1.0, double.infinity);
    final safeHeight = (viewportSize.height - (padding * 2)).clamp(1.0, double.infinity);
    final targetScale = sceneRect.width <= 0 || sceneRect.height <= 0
        ? _viewport.scale
        : (safeWidth / sceneRect.width)
            .clamp(
              minScale,
              (safeHeight / sceneRect.height).clamp(minScale, maxScale).toDouble(),
            )
            .toDouble();

    centerScenePoint(
      scenePoint: sceneRect.center,
      viewportSize: viewportSize,
      scale: targetScale,
    );
  }

  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) {
      return;
    }

    _viewport = _viewport.copyWith(
      translation: _viewport.translation + screenDelta,
    );
    notifyListeners();
  }

  void zoomAtScreenPoint({
    required Offset focalPoint,
    required double scaleDelta,
  }) {
    if (scaleDelta == 1) {
      return;
    }

    final focalScenePoint = screenToScene(focalPoint);
    final nextScale =
        (_viewport.scale * scaleDelta).clamp(minScale, maxScale).toDouble();
    final nextTranslation = Offset(
      focalPoint.dx - (focalScenePoint.dx * nextScale),
      focalPoint.dy - (focalScenePoint.dy * nextScale),
    );

    _viewport = NodeEditorViewport(
      scale: nextScale,
      translation: nextTranslation,
    );
    notifyListeners();
  }
}
