#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform CircleParams {
    vec4 shape;
} params;

void main() {
    float radius = params.shape.x;
    float outline = params.shape.y;
    float width = params.shape.z;
    float height = params.shape.w;

    vec2 rpos = vec2((UV.x - 0.5) * width, (UV.y - 0.5) * height);
    float sqr = dot(rpos, rpos);

    float rad = radius * (min(width, height) * 0.5);
    float radsqr = rad * rad;

    if (outline > 0.0) {
        if (sqr >= radsqr - outline * radsqr && sqr <= radsqr) {
            fragColor = vec4(1.0);
        } else {
            fragColor = vec4(0.0);
        }
        return;
    }

    fragColor = sqr <= radsqr ? vec4(1.0) : vec4(0.0);
}
