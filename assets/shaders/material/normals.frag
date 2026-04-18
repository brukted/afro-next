#version 450

layout(location = 0) in vec2 UV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform NormalsParams {
    vec4 scalarParams;
    ivec4 flagParams;
} params;

layout(set = 0, binding = 1) uniform sampler linearSampler;
layout(set = 0, binding = 2) uniform texture2D MainTexTex;

#define FragColor fragColor
#define MainTex sampler2D(MainTexTex, linearSampler)
#define width params.scalarParams.x
#define height params.scalarParams.y
#define intensity params.scalarParams.z
#define reduce params.scalarParams.w
#define directx params.flagParams.x

void main() {
    float noiseReduction = (intensity * reduce);
    vec2 rpos = vec2(UV.x * width, UV.y * height);

    float left = (rpos.x - 1) / width;
    float right = (rpos.x + 1) / width;
    float top = (rpos.y - 1) / height;
    float bottom = (rpos.y + 1) / height;

    vec4 t = texture(MainTex, vec2(UV.x, top));
    vec4 b = texture(MainTex, vec2(UV.x, bottom));
    vec4 l = texture(MainTex, vec2(left, UV.y));
    vec4 r = texture(MainTex, vec2(right, UV.y));

    vec3 norm = vec3(0, 0, 1.0 / intensity);

    if (UV.x == 0 || UV.y == 0 || UV.x == 1 || UV.y == 1) {
        norm.x = 0;
        norm.y = 0;
    } else {
        vec4 cx = (l - r);
        vec4 cy = (t - b);

        norm.x = (cx.r + cx.g + cx.b) / 3.0;
        norm.y = (cy.r + cy.g + cy.b) / 3.0;
    }

    norm = normalize(norm);

    if (length(vec2(norm.x, norm.y)) <= noiseReduction) {
        norm.x = norm.y = 0;
    }

    if (directx == 1) {
        norm.y = -norm.y;
    }

    norm = (norm + vec3(1)) * 0.5;

    FragColor = vec4(norm.r, norm.g, norm.b, 1);
}
