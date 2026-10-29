shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 tile_count = vec2(18.0, 10.0);
uniform float softness : hint_range(0.0, 0.5) = 0.08;
uniform float seed = 1.0;

float hash_tile(vec2 cell) {
	vec2 p = cell + vec2(seed, seed * 1.6180339);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 count = max(tile_count, vec2(1.0));
	vec2 cell = floor(UV * count);
	float threshold = hash_tile(cell);
	float width = max(softness, 0.0001);
	float alpha = smoothstep(threshold - width, threshold + width, progress);
	COLOR = vec4(transition_color.rgb, transition_color.a * alpha);
}
