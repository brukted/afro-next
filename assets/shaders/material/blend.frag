#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform BlendParams {
    ivec4 modes;
    vec4 scalars;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D foregroundTex;
layout(set = 0, binding = 3) uniform texture2D backgroundTex;
layout(set = 0, binding = 4) uniform texture2D maskTex;

vec3 copyColor(vec4 a, vec4 b, float alpha) {
    float clampedAlpha = clamp(alpha, 0.0, 1.0);
    return clamp(a.rgb, vec3(0.0), vec3(1.0)) * clampedAlpha +
        clamp(b.rgb, vec3(0.0), vec3(1.0)) * (1.0 - clampedAlpha);
}

float addSub(float a, float b) {
    return a >= 0.5 ? clamp(a + b, 0.0, 1.0) : clamp(b - a, 0.0, 1.0);
}

float multiply(float a, float b) {
    return clamp(a * b, 0.0, 1.0);
}

float screenBlend(float a, float b) {
    return clamp(1.0 - (1.0 - a) * (1.0 - b), 0.0, 1.0);
}

float overlay(float a, float b) {
    return b < 0.5 ? clamp(2.0 * a * b, 0.0, 1.0) : clamp(1.0 - 2.0 * (1.0 - a) * (1.0 - b), 0.0, 1.0);
}

float chooseMask(vec4 maskColor) {
    return maskColor.a >= 1.0
        ? clamp(maskColor.r, 0.0, 1.0)
        : clamp(maskColor.r + maskColor.a, 0.0, 1.0);
}

vec3 blendColor(vec4 a, vec4 b, float opacity) {
    int blendMode = params.modes.x;
    if (blendMode == 0) {
        return vec3(
            addSub(a.r * opacity, b.r),
            addSub(a.g * opacity, b.g),
            addSub(a.b * opacity, b.b)
        );
    }
    if (blendMode == 1) {
        return copyColor(a, b, opacity * a.a);
    }
    if (blendMode == 2) {
        return vec3(
            multiply(a.r * opacity, b.r),
            multiply(a.g * opacity, b.g),
            multiply(a.b * opacity, b.b)
        );
    }
    if (blendMode == 3) {
        return vec3(
            screenBlend(a.r * opacity, b.r),
            screenBlend(a.g * opacity, b.g),
            screenBlend(a.b * opacity, b.b)
        );
    }
    if (blendMode == 4) {
        return vec3(
            overlay(a.r * opacity, b.r),
            overlay(a.g * opacity, b.g),
            overlay(a.b * opacity, b.b)
        );
    }
    return copyColor(a, b, opacity * a.a);
}

float blendAlpha(vec4 a, vec4 b) {
    int alphaMode = params.modes.y;
    if (alphaMode == 0) {
        return clamp(b.a, 0.0, 1.0);
    }
    if (alphaMode == 1) {
        return clamp(a.a, 0.0, 1.0);
    }
    if (alphaMode == 2) {
        return min(a.a, b.a);
    }
    if (alphaMode == 3) {
        return max(a.a, b.a);
    }
    if (alphaMode == 4) {
        return (clamp(a.a, 0.0, 1.0) + clamp(b.a, 0.0, 1.0)) * 0.5;
    }
    if (alphaMode == 5) {
        return clamp(a.a + b.a, 0.0, 1.0);
    }
    return clamp(b.a, 0.0, 1.0);
}

void main() {
    vec4 foreground = texture(sampler2D(foregroundTex, linearSampler), UV);
    vec4 background = texture(sampler2D(backgroundTex, linearSampler), UV);
    vec4 maskColor = texture(sampler2D(maskTex, linearSampler), UV);

    float opacity = clamp(params.scalars.x, 0.0, 1.0) * chooseMask(maskColor);
    vec3 color = blendColor(foreground, background, opacity);
    float alpha = blendAlpha(foreground, background);

    fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha);
}
