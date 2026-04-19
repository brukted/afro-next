#version 330 core
out vec4 FragColor;
in vec2 UV;

uniform sampler2D MainTex;
uniform sampler2D CurveLUT;

float decodeCurveChannel(float encodedChannel, float encodedLuminance) {
    return encodedLuminance <= 0.0001
        ? 0.0
        : (encodedChannel * encodedChannel) / encodedLuminance;
}

void main() {
    vec4 c = texture(MainTex, UV);

    //convert to int in the 0-255 curve range
    int rx = int(min(1, max(0, c.r)) * 255);
    int gx = int(min(1, max(0, c.g)) * 255);
    int bx = int(min(1, max(0, c.b)) * 255);

    //texelFetch instead of texture() so no filtering is applied whatsoever
    //otherwise if using texture() then it is possible that the
    //curve lookup will be off if using linear or way off if using nearest
    vec4 rr = texelFetch(CurveLUT, ivec2(rx, 0), 0);
    vec4 gg = texelFetch(CurveLUT, ivec2(gx, 0), 0);
    vec4 bb = texelFetch(CurveLUT, ivec2(bx, 0), 0);

    //alpha stores the luminance curve, and rgb stores luminance-premultiplied
    //channel values so luminance affects every sampled channel.
    FragColor = vec4(
        decodeCurveChannel(rr.r, rr.a),
        decodeCurveChannel(gg.g, gg.a),
        decodeCurveChannel(bb.b, bb.a),
        c.a
    );
}