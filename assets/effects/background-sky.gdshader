shader_type canvas_item;
render_mode unshaded;

uniform sampler2D depth_mask : filter_nearest, repeat_disable;
uniform vec4 sky_region = vec4(0.25, 0.03, 0.5, 0.4);

void fragment() {
    vec2 uv = UV;
    // Preserve the sector's painted stars, clouds and nebulae. Replace every
    // solid silhouette with open sky so there is no baked copy under a planet.
    if (texture(depth_mask, uv).r > 0.1) {
        uv = sky_region.xy + UV * sky_region.zw;
        for (int attempt = 0; attempt < 12; attempt++) {
            if (texture(depth_mask, uv).r <= 0.1) { break; }
            uv = sky_region.xy + fract(UV + vec2(0.173, 0.271) * float(attempt + 1)) * sky_region.zw;
        }
    }
    vec4 source = texture(TEXTURE, uv);
    if (texture(depth_mask, uv).r > 0.1) {
        source = vec4(0.015, 0.035, 0.06, 1.0);
    }
    COLOR = vec4(mix(source.rgb, vec3(0.015, 0.035, 0.06), 0.14), source.a);
}
