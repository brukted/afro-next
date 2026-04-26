import 'dart:io';
import 'dart:ui' as ui;

import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/graph/models/graph_schema.dart';
import 'package:afro/features/workspace/models/workspace_models.dart';
import 'package:afro/features/workspace/workspace_controller.dart';
import 'package:afro/vulkan/renderer/material_fallback_texture_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a curve LUT that preserves the identity curve', () async {
    const generator = MaterialFallbackTextureGenerator(previewExtent: 64);
    final curveTexture = await generator.generate(
      GraphValueData.colorCurve(GraphColorCurveData.identity()),
    );

    expect(curveTexture, isNotNull);
    expect(curveTexture!.width, 256);
    expect(curveTexture.height, 1);

    const sampleIndex = 128;
    final x = sampleIndex / 255.0;
    final offset = sampleIndex * 4;
    final encodedBlue = curveTexture.bytes[offset] / 255.0;
    final encodedGreen = curveTexture.bytes[offset + 1] / 255.0;
    final encodedRed = curveTexture.bytes[offset + 2] / 255.0;
    final encodedAlpha = curveTexture.bytes[offset + 3] / 255.0;

    expect(_decodeCurveChannel(encodedRed, encodedAlpha), closeTo(x, 0.015));
    expect(_decodeCurveChannel(encodedGreen, encodedAlpha), closeTo(x, 0.015));
    expect(_decodeCurveChannel(encodedBlue, encodedAlpha), closeTo(x, 0.015));
  });

  test('generates gradient text image and svg fallback textures', () async {
    final workspaceController = WorkspaceController.preview()..initializeForPreview();
    final tempDir = await Directory.systemTemp.createTemp('afro-fallbacks');
    addTearDown(() => tempDir.delete(recursive: true));

    final imagePath = '${tempDir.path}/pixel.png';
    final svgPath = '${tempDir.path}/pixel.svg';
    await File(imagePath).writeAsBytes(await _createPngBytes());
    await File(svgPath).writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8">'
      '<circle cx="4" cy="4" r="3" fill="#00ffff" />'
      '</svg>',
    );

    await workspaceController.importImageFileAt(
      imagePath,
      workspaceController.workspace.rootFolderId,
    );
    await workspaceController.importSvgFileAt(
      svgPath,
      workspaceController.workspace.rootFolderId,
    );

    final imageResource = workspaceController.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.image,
    );
    final svgResource = workspaceController.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.svg,
    );

    const previewExtent = 64;
    final generator = MaterialFallbackTextureGenerator(
      previewExtent: previewExtent,
      workspaceController: workspaceController,
    );

    final gradientTexture = await generator.generate(
      GraphValueData.gradient(
        GraphGradientData(
          stops: [
            GraphGradientStopData(position: 0, color: Vector4(1, 0, 0, 1)),
            GraphGradientStopData(position: 1, color: Vector4(0, 0, 1, 1)),
          ],
        ),
      ),
    );
    final textTexture = await generator.generate(
      GraphValueData.textBlock(
        GraphTextData(
          text: 'Hi',
          fontFamily: 'Helvetica',
          fontSize: 24,
          backgroundColor: Vector4.zero(),
          textColor: Vector4.all(1),
        ),
      ),
    );
    final imageTexture = await generator.generate(
      GraphValueData.workspaceResource(imageResource.id),
    );
    final svgTexture = await generator.generate(
      GraphValueData.workspaceResource(svgResource.id),
    );

    expect(gradientTexture, isNotNull);
    expect(gradientTexture!.width, 256);
    expect(gradientTexture.height, 256);
    expect(gradientTexture.bytes.length, 256 * 256 * 4);

    expect(textTexture, isNotNull);
    expect(textTexture!.width, previewExtent);
    expect(textTexture.height, previewExtent);
    expect(textTexture.bytes.any((value) => value != 0), isTrue);

    expect(imageTexture, isNotNull);
    expect(imageTexture!.width, previewExtent);
    expect(imageTexture.height, previewExtent);
    expect(imageTexture.bytes.any((value) => value != 0), isTrue);

    expect(svgTexture, isNotNull);
    expect(svgTexture!.width, previewExtent);
    expect(svgTexture.height, previewExtent);
    expect(svgTexture.bytes.any((value) => value != 0), isTrue);
  });
}

Future<List<int>> _createPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

double _decodeCurveChannel(double encodedChannel, double encodedLuminance) {
  if (encodedLuminance <= 0.0001) {
    return 0.0;
  }
  return (encodedChannel * encodedChannel) / encodedLuminance;
}
