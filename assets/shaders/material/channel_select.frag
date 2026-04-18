#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform ChannelSelectParams {
    ivec4 channels;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D input1Tex;
layout(set = 0, binding = 3) uniform texture2D input2Tex;

float getChannel(vec4 c1, vec4 c2, int channel) {
    switch (channel) {
        case 0: return c1.r;
        case 1: return c1.g;
        case 2: return c1.b;
        case 3: return c1.a;
        case 4: return c2.r;
        case 5: return c2.g;
        case 6: return c2.b;
        case 7: return c2.a;
    }
    return 0.0;
}

void main() {
    vec4 c1 = texture(sampler2D(input1Tex, linearSampler), UV);
    vec4 c2 = texture(sampler2D(input2Tex, linearSampler), UV);

    fragColor = vec4(
        getChannel(c1, c2, params.channels.x),
        getChannel(c1, c2, params.channels.y),
        getChannel(c1, c2, params.channels.z),
        getChannel(c1, c2, params.channels.w)
    );
}
