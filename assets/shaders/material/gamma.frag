#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform GammaParams {
    vec4 gammaParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define gamma params.gammaParams.x

void main() {
    vec4 c = texture(MainTex, UV);
    FragColor.rgb = pow(c.rgb, vec3(1.0 / gamma));
    FragColor.a = c.a;
}
