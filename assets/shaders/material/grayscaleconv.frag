#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform GrayscaleParams {
    vec4 weightBlock;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define weight params.weightBlock

void main() {
    vec4 c = texture(MainTex, UV);

    int one = 0;
    if (weight.r > 0) {
        one = one + 1;
    }
    if (weight.g > 0) {
        one = one + 1;
    }
    if (weight.b > 0) {
        one = one + 1;
    }
    if (weight.a > 0) {
        one = one + 1;
    }

    if (one == 0) {
        one = 1;
    }

    float d = (c.r * weight.r + c.g * weight.g + c.b * weight.b + c.a * weight.a) / one;

    FragColor = vec4(d, d, d, 1);
}
