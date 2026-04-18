#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform ImageBasicParams {
    vec4 unusedParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)

void main() {
    vec4 c = texture(MainTex, UV);
    FragColor = c;
}
