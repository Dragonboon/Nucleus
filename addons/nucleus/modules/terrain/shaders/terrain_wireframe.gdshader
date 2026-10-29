shader_type spatial;
render_mode wireframe, unshaded, cull_disabled;

uniform vec4 wire_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void fragment() {
	ALBEDO = wire_color.rgb;
}
