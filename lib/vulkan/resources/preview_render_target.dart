enum PreviewRenderTargetKind {
  placeholder,
  externalTexture,
  error,
}

enum PreviewRenderStatus {
  ready,
  rendering,
  unsupported,
  failed,
}

class PreviewTextureDescriptor {
  const PreviewTextureDescriptor({
    required this.textureId,
    required this.width,
    required this.height,
  });

  final int textureId;
  final int width;
  final int height;
}

class PreviewRenderTarget {
  const PreviewRenderTarget({
    required this.id,
    required this.kind,
    required this.label,
    required this.diagnostics,
    this.status = PreviewRenderStatus.ready,
    this.texture,
  });

  final String id;
  final PreviewRenderTargetKind kind;
  final String label;
  final List<String> diagnostics;
  final PreviewRenderStatus status;
  final PreviewTextureDescriptor? texture;

  bool get hasTexture =>
      kind == PreviewRenderTargetKind.externalTexture && texture != null;

  PreviewRenderTarget copyWith({
    String? id,
    PreviewRenderTargetKind? kind,
    String? label,
    List<String>? diagnostics,
    PreviewRenderStatus? status,
    PreviewTextureDescriptor? texture,
  }) {
    return PreviewRenderTarget(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      diagnostics: diagnostics ?? this.diagnostics,
      status: status ?? this.status,
      texture: texture ?? this.texture,
    );
  }
}
