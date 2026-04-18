#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform WarpDirectionalParams {
    vec4 warpDirectionalParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;
layout(set = 0, binding = 3) uniform texture2D WarpTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define Warp sampler2D(WarpTex, linearSampler)
#define intensity params.warpDirectionalParams.x
#define angle params.warpDirectionalParams.y

void main() {
    vec2 uv = UV;
    float cs = cos(angle);
    float si = sin(angle);
    float r = texture(Warp, uv).r;
    vec2 n = vec2(r * cs, r * si);
    FragColor = texture(MainTex, uv + n * intensity);
}
