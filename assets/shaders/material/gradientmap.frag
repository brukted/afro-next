#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform GradientMapParams {
    ivec4 gradientFlags;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;
layout(set = 0, binding = 3) uniform texture2D ColorLUTTex;
layout(set = 0, binding = 4) uniform texture2D MaskTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define ColorLUT sampler2D(ColorLUTTex, linearSampler)
#define Mask sampler2D(MaskTex, linearSampler)
#define useMask params.gradientFlags.x
#define horizontal params.gradientFlags.y

void main() {
    vec4 rgba = texture(MainTex, UV);
    vec2 size = textureSize(ColorLUT, 0);
    vec4 c = vec4(0);

    if (horizontal == 1) {
        c = texelFetch(ColorLUT, ivec2(min(rgba.r * size.x, size.x - 1), 0), 0);
    } else {
        c = texelFetch(ColorLUT, ivec2(min(rgba.r * size.y, size.y - 1), 0), 0);
    }

    if (useMask == 1) {
        vec2 m2 = texture(Mask, UV).ra;
        if (m2.y >= 1) {
            float m = min(m2.x, 1);
            c *= m;
        } else {
            float m = min(m2.x + m2.y, 1);
            c *= m;
        }
    }

    c.a = rgba.a * c.a;
    FragColor = c;
}
