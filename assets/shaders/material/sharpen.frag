#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform SharpenParams {
    vec4 sharpenParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define intensity params.sharpenParams.x

float kernel[9];

void initKernel() {
    kernel[0] = 0.077847;
    kernel[1] = 0.123317;
    kernel[2] = 0.077847;
    kernel[3] = 0.123317;
    kernel[4] = 0.195346;
    kernel[5] = 0.123317;
    kernel[6] = 0.077847;
    kernel[7] = 0.123317;
    kernel[8] = 0.077847;
}

void main() {
    initKernel();
    vec2 offset = 1.0 / textureSize(MainTex, 0);

    vec4 sum = vec4(0);
    int oidx = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec4 c = texture(MainTex, min(vec2(1.0), max(vec2(0), UV + offset * vec2(x, y))));
            sum += c * kernel[oidx];
            oidx += 1;
        }
    }

    vec4 o = texture(MainTex, UV);
    FragColor = o + (o - sum) * intensity;
}
