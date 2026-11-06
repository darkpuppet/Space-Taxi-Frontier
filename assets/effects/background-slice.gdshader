shader_type canvas_item;
render_mode unshaded;

// Six-value, artwork-aligned depth matte: 0 sky, 1/2 planets, 3/4/5 scenery.
uniform sampler2D depth_mask : filter_nearest, repeat_disable;
uniform int depth_layer = 1;
uniform vec2 world_size = vec2(2400.0, 1440.0);
uniform float overscan = 96.0;

float category(vec2 uv) {
    return floor(texture(depth_mask, clamp(uv, vec2(0.0), vec2(1.0))).r * 5.0 + 0.5);
}

void fragment() {
    vec2 uv = (UV * (world_size + vec2(overscan * 2.0)) - vec2(overscan)) / world_size;
    vec2 source_uv = clamp(uv, vec2(0.001), vec2(0.999));
    float selected = float(depth_layer);
    float current = category(source_uv);
    float alpha = current == selected ? 1.0 : 0.0;
    vec4 source = texture(TEXTURE, source_uv);
    float outside = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
    alpha *= 1.0 - smoothstep(0.0, 0.035, outside);
    COLOR = vec4(mix(source.rgb, vec3(0.015, 0.035, 0.06), 0.14), source.a * alpha);
}
