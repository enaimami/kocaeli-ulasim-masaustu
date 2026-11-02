#version 440
// Koyu tema için harita karoları: renkleri ters çevirip tonu 180° döndürür (yeşil yeşil,
// mavi mavi kalır), sonra biraz karartır. Kaynak önceden çarpılmış (premultiplied) alfadır.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec4 c = texture(source, qt_TexCoord0);
    vec3 inv = vec3(c.a) - c.rgb;
    vec3 rot = vec3(dot(vec3(-0.574, 1.430, 0.144), inv),
                    dot(vec3(0.426, 0.430, 0.144), inv),
                    dot(vec3(0.426, 1.430, -0.856), inv));
    // Doygunluğu azalt: ana yollar koyu zeminde göz yormasın.
    float l = dot(rot, vec3(0.299, 0.587, 0.114));
    rot = mix(vec3(l), rot, 0.55);
    rot = clamp(rot * 0.82 + vec3(0.02, 0.025, 0.04) * c.a, 0.0, c.a);
    fragColor = vec4(rot, c.a) * qt_Opacity;
}
