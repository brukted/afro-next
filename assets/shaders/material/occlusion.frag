#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform OcclusionParams {
    vec4 unusedParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;
layout(set = 0, binding = 3) uniform texture2D OriginalTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define Original sampler2D(OriginalTex, linearSampler)

void main() {
    vec4 c = texture(MainTex, UV);
    vec4 c2 = texture(Original, UV);

    c.rgb = min(vec3(1), max(vec3(0), 1.0 + c.rrr - c2.r));

    FragColor = vec4(c.rgb, 1);
}
