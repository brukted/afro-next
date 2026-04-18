#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform TransformParams {
    vec4 rotationCol0;
    vec4 rotationCol1;
    vec4 rotationCol2;
    vec4 scaleCol0;
    vec4 scaleCol1;
    vec4 scaleCol2;
    vec4 translationBlock;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define rotation mat3(params.rotationCol0.xyz, params.rotationCol1.xyz, params.rotationCol2.xyz)
#define scale mat3(params.scaleCol0.xyz, params.scaleCol1.xyz, params.scaleCol2.xyz)
#define translation params.translationBlock.xyz

void main() {
    vec2 size = textureSize(MainTex, 0);
    vec3 runits = vec3(size * (UV - 0.5), 0);

    runits = rotation * runits;
    runits = scale * runits;
    runits += translation;

    vec2 fpos = runits.xy / size + 0.5;

    vec4 c = texture(MainTex, fpos);

    FragColor = c;
}
