#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform LevelsParams {
    vec4 minValuesBlock;
    vec4 maxValuesBlock;
    vec4 midValuesBlock;
    vec4 valueBlock;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define minValues params.minValuesBlock.xyz
#define maxValues params.maxValuesBlock.xyz
#define midValues params.midValuesBlock.xyz
#define value params.valueBlock.xy

float Gamma(float mid) {
    float gamma = 1;

    if (mid < 0.5) {
        mid = mid * 2;
        gamma = 1 + (9 * (1 - mid));
        gamma = min(gamma, 9.99);
    } else if (mid > 0.5) {
        mid = (mid * 2) - 1;
        gamma = 1 - mid;
        gamma = max(gamma, 0.01);
    }

    return 1.0 / gamma;
}

void main() {
    vec4 c = texture(MainTex, UV);

    float rgamma = 1;
    float ggamma = 1;
    float bgamma = 1;

    rgamma = Gamma(midValues.r);
    ggamma = Gamma(midValues.g);
    bgamma = Gamma(midValues.b);

    vec3 adjusted = (c.rgb - minValues) / (maxValues - minValues);

    adjusted = min(vec3(1), max(vec3(0), adjusted));

    if (rgamma < 1 || rgamma > 1) {
        adjusted.r = min(1, max(0, pow(adjusted.r, rgamma)));
    }
    if (ggamma > 1 || ggamma < 1) {
        adjusted.g = min(1, max(0, pow(adjusted.g, ggamma)));
    }
    if (bgamma > 1 || bgamma < 1) {
        adjusted.b = min(1, max(0, pow(adjusted.b, bgamma)));
    }

    adjusted = min(vec3(1), max(vec3(0), adjusted * (value.y - value.x) + value.x));

    FragColor = vec4(adjusted, c.a);
}
