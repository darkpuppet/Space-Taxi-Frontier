shader_type canvas_item;
render_mode unshaded;

// Explicit game time freezes the effect during pause and menus.
uniform float aurora_time = 0.0;
uniform bool layer_mask_enabled = false;
uniform bool depth_mask_enabled = false;
uniform sampler2D depth_mask : filter_nearest, repeat_disable;
uniform vec4 sky_region = vec4(0.25, 0.03, 0.50, 0.47);

float aurora_mask(vec2 uv, vec3 source) {
    // Follow the painted diagonal sky curtains and their distant lower ribbon.
    float curtain_edge = 0.04 + uv.x * 0.69;
    float upper = smoothstep(curtain_edge - 0.27, curtain_edge - 0.12, uv.y)
        * (1.0 - smoothstep(curtain_edge + 0.015, curtain_edge + 0.08, uv.y));
    upper *= 1.0 - smoothstep(0.74, 0.85, uv.x);
    float lower_edge = 0.56 + uv.x * 0.30;
    float lower = (1.0 - smoothstep(0.025, 0.085, abs(uv.y - lower_edge)))
        * smoothstep(0.10, 0.18, uv.x) * (1.0 - smoothstep(0.37, 0.48, uv.x));
    // Teal/green chroma excludes blue ice, planets, white stars and dark sky.
    float teal = smoothstep(0.015, 0.10, source.g - source.b * 0.82)
        * smoothstep(0.035, 0.16, source.g - source.r);
    return max(upper, lower * 0.7) * teal;
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    float mask = aurora_mask(UV, original.rgb);
    float wave = sin(UV.x * 23.0 - aurora_time * 0.48);
    float folds = sin(UV.x * 76.0 + UV.y * 13.0 + aurora_time * 0.72);
    vec2 drift = vec2(sin(UV.y * 21.0 + aurora_time * 0.34) * 0.0025,
        wave * 0.006 + folds * 0.0015) * mask;
    vec3 shifted = texture(TEXTURE, clamp(UV + drift, vec2(0.0), vec2(1.0))).rgb;
    vec3 color = mix(original.rgb, shifted, mask * 0.85);
    float shimmer = sin(UV.x * 18.0 - aurora_time * 0.60) * 0.17
        + sin(UV.x * 59.0 + aurora_time * 0.83) * 0.07;
    color *= 1.0 + shimmer * mask;
    color += vec3(0.015, 0.09, 0.065) * mask * (0.5 + 0.5 * wave);
    vec2 inset = min(UV - sky_region.xy, sky_region.xy + sky_region.zw - UV);
    float sky_alpha = smoothstep(0.0, 0.035, min(inset.x, inset.y));
    if (depth_mask_enabled) {
        sky_alpha = (1.0 - step(0.1, texture(depth_mask, UV).r)) * mask;
    }
    COLOR = vec4(color, original.a * (layer_mask_enabled ? sky_alpha : 1.0));
}
