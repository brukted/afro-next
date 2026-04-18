#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform MotionBlurParams {
    vec4 motionBlurParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define tx params.motionBlurParams.x
#define ty params.motionBlurParams.y
#define magnitude params.motionBlurParams.z

void main() {
    vec2 dir = normalize(vec2(tx, ty));
    vec2 offset = 1.0 / textureSize(MainTex, 0);
    float whalf = magnitude * 0.5;
    vec4 result = vec4(0);

    for (float j = -whalf; j <= whalf; j++) {
        result += texture(MainTex, UV + (j * offset * dir));
    }

    FragColor = result / magnitude;
}
