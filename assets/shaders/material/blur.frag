#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform BlurParams {
    vec4 blurParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define intensity params.blurParams.x
#define pixel_shape params.blurParams.yz

void main() {
    vec2 offset = 1.0 / textureSize(MainTex, 0);

    float whalf = intensity * 0.5;
    vec4 result = vec4(0);

    offset.y = offset.y * pixel_shape.y;
    offset.x = offset.x * pixel_shape.x;

    for (float j = -whalf; j <= whalf; j++) {
        result += texture(MainTex, UV + (j * offset));
    }

    FragColor = result / (intensity + 1);
}
