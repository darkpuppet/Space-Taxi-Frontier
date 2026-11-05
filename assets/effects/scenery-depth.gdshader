shader_type canvas_item;
render_mode unshaded;

uniform vec4 sky_region = vec4(0.15, 0.10, 0.55, 0.29);
uniform vec2 world_size = vec2(2400.0, 1440.0);
uniform float overscan = 96.0;
uniform bool foreground = false;
uniform bool frame_edges = false;
uniform float foreground_start = 0.80;
uniform bool window_mask_enabled = false;
uniform sampler2D window_mask_texture : filter_linear, repeat_disable;
uniform float glass_opacity : hint_range(0.0, 1.0) = 0.06;
// -1 retains the legacy combined-window rendering used by isolated previews.
uniform int layer_kind = -1;
uniform bool semantic_masks_enabled = false;
uniform sampler2D planets_mask_texture : filter_linear, repeat_disable;
uniform sampler2D frame_mask_texture : filter_linear, repeat_disable;
uniform sampler2D buildings_mask_texture : filter_linear, repeat_disable;
uniform bool planet_reconstructed = false;

void fragment() {
    vec2 uv = (UV * (world_size + vec2(overscan * 2.0)) - vec2(overscan)) / world_size;
    vec2 sample_uv = clamp(uv, vec2(0.001), vec2(0.999));
    vec2 inset = min(sample_uv - sky_region.xy, sky_region.xy + sky_region.zw - sample_uv);
    float open_sky = smoothstep(0.0, 0.065, min(inset.x, inset.y));
    float near_mask = smoothstep(foreground_start - 0.025, foreground_start + 0.025, sample_uv.y);
    if (frame_edges) {
        float edge = min(sample_uv.x, 1.0 - sample_uv.x);
        near_mask = max(near_mask, 1.0 - smoothstep(0.035, 0.075, edge));
    }
    // The legacy middle plate extends behind near objects to cover revealed edges.
    float alpha = (1.0 - open_sky) * (foreground ? near_mask : 1.0);
    float outside = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
    alpha *= 1.0 - smoothstep(0.0, 0.035, outside);
    vec4 source = texture(TEXTURE, sample_uv);
    source.rgb = mix(source.rgb, vec3(0.015, 0.035, 0.06), 0.14);
    if (window_mask_enabled && !semantic_masks_enabled) {
        float glass = texture(window_mask_texture, sample_uv).r;
        // Remove fine stray white outlines and keep a safe margin around solids.
        vec2 texel = vec2(2.0) / vec2(textureSize(window_mask_texture, 0));
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                glass = min(glass, texture(window_mask_texture, sample_uv + vec2(float(x), float(y)) * texel).r);
            }
        }
        // Replace painted stars with a uniform translucent glass tint.
        source.rgb = mix(source.rgb, vec3(0.025, 0.065, 0.10), glass);
        float transmission = mix(1.0, glass_opacity, glass);
        alpha = foreground ? near_mask * (1.0 - glass) : transmission;
        alpha *= 1.0 - smoothstep(0.0, 0.035, outside);
    }
    if (semantic_masks_enabled && layer_kind >= 0) {
        float planet = texture(planets_mask_texture, sample_uv).r;
        float frame = texture(frame_mask_texture, sample_uv).r;
        float structures = texture(buildings_mask_texture, sample_uv).r;
        float sky = texture(window_mask_texture, sample_uv).r;
        structures *= 1.0 - frame;
        // Closed control-room glazing belongs to the buildings, not the outer glass.
        bool left_room = sample_uv.x < 0.135 && sample_uv.y > 0.35 && sample_uv.y < 0.49;
        bool right_room = sample_uv.x > 0.85 && sample_uv.y > 0.48 && sample_uv.y < 0.60;
        if (left_room || right_room) {
            structures = max(structures, 1.0 - sky);
        }
        // Preserve solid light slits and tiny unassigned edges of the original frame.
        frame = max(frame, (1.0 - sky) * (1.0 - planet) * (1.0 - structures));
        float opening = clamp(sky + planet, 0.0, 1.0) * (1.0 - max(frame, structures));
        // Every visible source pixel belongs to a distinct solid plane.
        source.rgb = mix(texture(TEXTURE, sample_uv).rgb, vec3(0.015, 0.035, 0.06), 0.14);
        if (layer_kind == 0) {
            vec3 celestial_color = texture(TEXTURE, sample_uv).rgb;
            float celestial_luma = max(celestial_color.r, max(celestial_color.g, celestial_color.b));
            // Reconstruction plates have pure black empty space; retain the atmosphere.
            alpha = planet_reconstructed ? smoothstep(0.002, 0.012, celestial_luma) : planet * (1.0 - max(frame, structures));
        } else if (layer_kind == 1) {
            alpha = opening * glass_opacity;
            source.rgb = vec3(0.025, 0.065, 0.10);
        } else if (layer_kind == 2) {
            alpha = frame * (1.0 - structures);
        } else {
            alpha = structures;
        }
        alpha *= 1.0 - smoothstep(0.0, 0.035, outside);
    }
    COLOR = vec4(source.rgb, source.a * alpha);
}
