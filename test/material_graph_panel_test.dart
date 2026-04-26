import 'package:afro/features/material_graph/material_graph_panel.dart';
import 'package:afro/vulkan/resources/preview_render_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders live preview surface for external textures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaterialNodePreviewCard(
            title: 'Preview Node',
            previewTextureBuilder: (context, texture) {
              return const ColoredBox(
                key: Key('material-node-live-preview'),
                color: Colors.transparent,
              );
            },
            preview: const PreviewRenderTarget(
              id: 'node-preview',
              kind: PreviewRenderTargetKind.externalTexture,
              label: 'Live preview',
              diagnostics: ['Revision: 2'],
              texture: PreviewTextureDescriptor(
                textureId: 77,
                width: 192,
                height: 192,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('material-node-live-preview')), findsWidgets);
  });

  testWidgets('renders placeholder previews when no texture is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaterialNodePreviewCard(
            title: 'Preview Node',
            preview: const PreviewRenderTarget(
              id: 'node-preview',
              kind: PreviewRenderTargetKind.placeholder,
              label: 'Preview',
              diagnostics: ['Revision: 2'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('material-node-live-preview')), findsNothing);
    expect(find.text('Preview'), findsWidgets);
  });
}
