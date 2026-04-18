#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform UvParams {
    vec4 unusedParams;
} params;

void main() {
    fragColor = vec4(0, 0.75, 1, 1);
}
