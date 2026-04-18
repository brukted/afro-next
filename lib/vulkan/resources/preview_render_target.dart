import 'package:flutter/material.dart';

enum PreviewRenderTargetKind {
  placeholder,
  externalTexture,
}

class PreviewRenderTarget {
  const PreviewRenderTarget({
    required this.id,
    required this.kind,
    required this.label,
    required this.accentColor,
    required this.diagnostics,
  });

  final String id;
  final PreviewRenderTargetKind kind;
  final String label;
  final Color accentColor;
  final List<String> diagnostics;
}
