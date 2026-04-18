#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform BloomParams {
    vec4 unusedParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;
layout(set = 0, binding = 3) uniform texture2D BloomTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define Bloom sampler2D(BloomTex, linearSampler)

void main() {
    vec4 c = texture(MainTex, UV);
    vec4 b = texture(Bloom, UV);

    vec4 final = vec4(0, 0, 0, clamp(c.a + b.a, 0, 1));
    final.rgb = c.rgb + b.rgb;

    final.rgb = final.rgb / (final.rgb + vec3(1.0));
    final.rgb = pow(final.rgb, vec3(1.0 / 2.2));

    FragColor = final;
}
