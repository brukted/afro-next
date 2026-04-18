#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform InvertParams {
    ivec4 invertFlags;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define invertRed params.invertFlags.x
#define invertGreen params.invertFlags.y
#define invertBlue params.invertFlags.z
#define invertAlpha params.invertFlags.w

void main() {
    vec4 c = texture(MainTex, UV);
    float r = c.r;
    float g = c.g;
    float b = c.b;
    float a = c.a;

    if (invertRed > 0) {
        r = 1.0 - clamp(r, 0, 1);
    }

    if (invertGreen > 0) {
        g = 1.0 - clamp(g, 0, 1);
    }

    if (invertBlue > 0) {
        b = 1.0 - clamp(b, 0, 1);
    }

    if (invertAlpha > 0) {
        a = 1.0 - clamp(a, 0, 1);
    }

    FragColor = vec4(r, g, b, a);
}
