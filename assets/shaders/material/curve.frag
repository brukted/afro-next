#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform CurveParams {
    vec4 unusedParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;
layout(set = 0, binding = 3) uniform texture2D CurveLUTTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define CurveLUT sampler2D(CurveLUTTex, linearSampler)

void main() {
    vec4 c = texture(MainTex, UV);

    int rx = int(min(1, max(0, c.r)) * 255);
    int gx = int(min(1, max(0, c.g)) * 255);
    int bx = int(min(1, max(0, c.b)) * 255);

    vec4 rr = texelFetch(CurveLUT, ivec2(rx, 0), 0);
    vec4 gg = texelFetch(CurveLUT, ivec2(gx, 0), 0);
    vec4 bb = texelFetch(CurveLUT, ivec2(bx, 0), 0);

    float rmid = (rr.r * 255) / (rr.a * 255);
    float gmid = (gg.g * 255) / (gg.a * 255);
    float bmid = (bb.b * 255) / (bb.a * 255);

    FragColor = vec4(rr.r * rmid, gg.g * gmid, bb.b * bmid, c.a);
}
