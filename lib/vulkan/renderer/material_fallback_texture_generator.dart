import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' as painting;
import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:vector_math/vector_math.dart' show Vector4;

import '../../features/graph/models/graph_models.dart';
import '../../features/graph/models/graph_schema.dart';
import '../../features/workspace/models/workspace_models.dart';
import '../../features/workspace/workspace_controller.dart';
import '../../shared/colors/vector4_color_adapter.dart';

class GeneratedTextureData {
  const GeneratedTextureData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class MaterialFallbackTextureGenerator {
  const MaterialFallbackTextureGenerator({
    required int previewExtent,
    WorkspaceController? workspaceController,
  }) : _previewExtent = previewExtent,
       _workspaceController = workspaceController;

  final int _previewExtent;
  final WorkspaceController? _workspaceController;

  Future<GeneratedTextureData?> generate(GraphValueData value) async {
    switch (value.valueType) {
      case GraphValueType.colorBezierCurve:
        return GeneratedTextureData(
          bytes: _curveLutTextureBytes(
            value.curveValue ?? GraphColorCurveData.identity(),
          ),
          width: 256,
          height: 1,
        );
      case GraphValueType.gradient:
        return GeneratedTextureData(
          bytes: _gradientTextureBytes(
            value.gradientValue ?? GraphGradientData.identity(),
          ),
          width: 256,
          height: 256,
        );
      case GraphValueType.workspaceResource:
        return _workspaceResourceTextureBytes(value.asWorkspaceResource());
      case GraphValueType.textBlock:
        return _textTextureBytes(value.asTextBlock());
      case GraphValueType.integer:
      case GraphValueType.integer2:
      case GraphValueType.integer3:
      case GraphValueType.integer4:
      case GraphValueType.float:
      case GraphValueType.float2:
      case GraphValueType.float3:
      case GraphValueType.float4:
      case GraphValueType.float3x3:
      case GraphValueType.stringValue:
      case GraphValueType.boolean:
      case GraphValueType.enumChoice:
        return null;
    }
  }

  Uint8List _curveLutTextureBytes(GraphColorCurveData curve) {
    const width = 256;
    final bytes = Uint8List(width * 4);
    for (var index = 0; index < width; index += 1) {
      final x = index / (width - 1);
      final lum = curve.lum.valueAt(x).clamp(0, 1).toDouble();
      final encodedAlpha = lum;
      final red = curve.red.valueAt(x).clamp(0, 1).toDouble();
      final green = curve.green.valueAt(x).clamp(0, 1).toDouble();
      final blue = curve.blue.valueAt(x).clamp(0, 1).toDouble();
      final encodedRed = (math.sqrt(red) * encodedAlpha).clamp(0, 1).toDouble();
      final encodedGreen = (math.sqrt(green) * encodedAlpha)
          .clamp(0, 1)
          .toDouble();
      final encodedBlue = (math.sqrt(blue) * encodedAlpha)
          .clamp(0, 1)
          .toDouble();
      final offset = index * 4;
      bytes[offset] = _toByte(encodedBlue);
      bytes[offset + 1] = _toByte(encodedGreen);
      bytes[offset + 2] = _toByte(encodedRed);
      bytes[offset + 3] = _toByte(encodedAlpha);
    }
    return bytes;
  }

  Uint8List _gradientTextureBytes(GraphGradientData gradient) {
    const width = 256;
    const height = 256;
    final bytes = Uint8List(width * height * 4);
    final normalized = gradient.normalized();
    final row = Uint8List(width * 4);
    for (var index = 0; index < width; index += 1) {
      final color = _gradientColorAt(normalized, index / (width - 1));
      final offset = index * 4;
      row[offset] = _toByte(color.z);
      row[offset + 1] = _toByte(color.y);
      row[offset + 2] = _toByte(color.x);
      row[offset + 3] = _toByte(color.w);
    }
    for (var rowIndex = 0; rowIndex < height; rowIndex += 1) {
      bytes.setRange(rowIndex * row.length, (rowIndex + 1) * row.length, row);
    }
    return bytes;
  }

  Vector4 _gradientColorAt(GraphGradientData gradient, double position) {
    final stops = gradient.stops;
    if (position <= stops.first.position) {
      return stops.first.color.clone();
    }
    if (position >= stops.last.position) {
      return stops.last.color.clone();
    }
    for (var index = 1; index < stops.length; index += 1) {
      final left = stops[index - 1];
      final right = stops[index];
      if (position <= right.position) {
        final range = right.position - left.position;
        final t = range <= 0 ? 0.0 : (position - left.position) / range;
        return Vector4(
          left.color.x + ((right.color.x - left.color.x) * t),
          left.color.y + ((right.color.y - left.color.y) * t),
          left.color.z + ((right.color.z - left.color.z) * t),
          left.color.w + ((right.color.w - left.color.w) * t),
        );
      }
    }
    return stops.last.color.clone();
  }

  Future<GeneratedTextureData?> _workspaceResourceTextureBytes(
    String resourceId,
  ) async {
    if (resourceId.isEmpty) {
      return null;
    }
    final workspaceController = _workspaceController;
    if (workspaceController == null || !workspaceController.isInitialized) {
      return null;
    }
    final resource = workspaceController.resourceById(resourceId);
    if (resource == null) {
      return null;
    }
    switch (resource.kind) {
      case WorkspaceResourceKind.image:
        final image = workspaceController.imageDocumentByResourceId(resourceId);
        if (image == null) {
          return null;
        }
        return _rasterImageTextureBytes(base64Decode(image.encodedBytesBase64));
      case WorkspaceResourceKind.svg:
        final svgDocument = workspaceController.svgDocumentByResourceId(
          resourceId,
        );
        if (svgDocument == null) {
          return null;
        }
        return _svgTextureBytes(svgDocument.svgText);
      case WorkspaceResourceKind.folder:
      case WorkspaceResourceKind.materialGraph:
      case WorkspaceResourceKind.mathGraph:
        return null;
    }
  }

  Future<GeneratedTextureData> _rasterImageTextureBytes(
    Uint8List encodedBytes,
  ) async {
    final codec = await ui.instantiateImageCodec(encodedBytes);
    final frame = await codec.getNextFrame();
    return _imageToSquareTextureBytes(frame.image);
  }

  Future<GeneratedTextureData> _svgTextureBytes(String svgText) async {
    final loadedPicture = await svg.vg.loadPicture(
      svg.SvgStringLoader(svgText),
      null,
    );
    try {
      return _pictureToSquareTextureBytes(
        loadedPicture.picture,
        width: loadedPicture.size.width,
        height: loadedPicture.size.height,
      );
    } finally {
      loadedPicture.picture.dispose();
    }
  }

  Future<GeneratedTextureData> _textTextureBytes(GraphTextData textData) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(_previewExtent.toDouble(), _previewExtent.toDouble());
    final backgroundPaint = ui.Paint()
      ..color = Vector4ColorAdapter.toFlutterColor(textData.backgroundColor);
    canvas.drawRect(ui.Offset.zero & size, backgroundPaint);

    final painter = painting.TextPainter(
      text: painting.TextSpan(
        text: textData.text,
        style: painting.TextStyle(
          color: Vector4ColorAdapter.toFlutterColor(textData.textColor),
          fontSize: textData.fontSize,
          fontFamily: textData.fontFamily.trim().isEmpty
              ? null
              : textData.fontFamily.trim(),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: painting.TextAlign.center,
      maxLines: 6,
      ellipsis: '...',
    )..layout(maxWidth: size.width - 24);

    final offset = ui.Offset(
      (size.width - painter.width) * 0.5,
      (size.height - painter.height) * 0.5,
    );
    painter.paint(canvas, offset);

    final image = await recorder.endRecording().toImage(
      _previewExtent,
      _previewExtent,
    );
    try {
      final rgbaBytes = await _rawRgbaBytes(image);
      return GeneratedTextureData(
        bytes: _rgbaToBgra(rgbaBytes),
        width: _previewExtent,
        height: _previewExtent,
      );
    } finally {
      image.dispose();
    }
  }

  Future<GeneratedTextureData> _imageToSquareTextureBytes(
    ui.Image image,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final destinationSize = ui.Size(
      _previewExtent.toDouble(),
      _previewExtent.toDouble(),
    );
    final fittedSizes = painting.applyBoxFit(
      painting.BoxFit.contain,
      ui.Size(image.width.toDouble(), image.height.toDouble()),
      destinationSize,
    );
    final outputRect = painting.Alignment.center.inscribe(
      fittedSizes.destination,
      ui.Offset.zero & destinationSize,
    );
    canvas.drawImageRect(
      image,
      ui.Offset.zero & ui.Size(image.width.toDouble(), image.height.toDouble()),
      outputRect,
      ui.Paint(),
    );
    final squareImage = await recorder.endRecording().toImage(
      _previewExtent,
      _previewExtent,
    );
    try {
      final rgbaBytes = await _rawRgbaBytes(squareImage);
      return GeneratedTextureData(
        bytes: _rgbaToBgra(rgbaBytes),
        width: _previewExtent,
        height: _previewExtent,
      );
    } finally {
      squareImage.dispose();
      image.dispose();
    }
  }

  Future<GeneratedTextureData> _pictureToSquareTextureBytes(
    ui.Picture picture, {
    required double width,
    required double height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final destinationSize = ui.Size(
      _previewExtent.toDouble(),
      _previewExtent.toDouble(),
    );
    final safeWidth = width <= 0 ? destinationSize.width : width;
    final safeHeight = height <= 0 ? destinationSize.height : height;
    final fittedSizes = painting.applyBoxFit(
      painting.BoxFit.contain,
      ui.Size(safeWidth, safeHeight),
      destinationSize,
    );
    final outputRect = painting.Alignment.center.inscribe(
      fittedSizes.destination,
      ui.Offset.zero & destinationSize,
    );
    canvas.save();
    canvas.translate(outputRect.left, outputRect.top);
    canvas.scale(outputRect.width / safeWidth, outputRect.height / safeHeight);
    canvas.drawPicture(picture);
    canvas.restore();
    final image = await recorder.endRecording().toImage(
      _previewExtent,
      _previewExtent,
    );
    try {
      final rgbaBytes = await _rawRgbaBytes(image);
      return GeneratedTextureData(
        bytes: _rgbaToBgra(rgbaBytes),
        width: _previewExtent,
        height: _previewExtent,
      );
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> _rawRgbaBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return Uint8List(image.width * image.height * 4);
    }
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }

  Uint8List _rgbaToBgra(Uint8List rgbaBytes) {
    final converted = Uint8List.fromList(rgbaBytes);
    for (var index = 0; index + 3 < converted.length; index += 4) {
      final red = converted[index];
      converted[index] = converted[index + 2];
      converted[index + 2] = red;
    }
    return converted;
  }

  int _toByte(double value) => (value.clamp(0, 1) * 255).round();
}
