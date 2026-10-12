shader_type spatial;
// World-space lookup keeps adjacent regions aligned. The terrain still owns geometry.
uniform sampler2D biome_colors : source_color, filter_linear, repeat_disable;
uniform vec2 map_minimum;
uniform vec2 map_size;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = texture(biome_colors, (world_xz - map_minimum) / map_size).rgb;
	ROUGHNESS = 0.95;
}
