shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.24, 0.38, 0.18, 1.0);
uniform float height_min = -20.0;
uniform float height_max = 50.0;
uniform bool use_triplanar = false;
uniform bool detail_enabled = true;
uniform bool detail_fade_enabled = true;
uniform float detail_distance_start = 25.0;
uniform float detail_distance_end = 100.0;
uniform int debug_view = 0;
uniform float debug_height_bands = 6.0;
uniform float debug_grid_scale = 10.0;

uniform bool layer0_enabled = false;
uniform bool layer0_use_texture = false;
uniform sampler2D layer0_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer0_tint : source_color = vec4(1.0);
uniform float layer0_uv_scale = 0.08;
uniform bool layer0_use_normal = false;
uniform sampler2D layer0_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float layer0_normal_strength = 1.0;
uniform bool layer0_use_roughness_texture = false;
uniform sampler2D layer0_roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float layer0_roughness_texture_strength = 1.0;
uniform vec2 layer0_height_range = vec2(0.0, 1.0);
uniform vec2 layer0_slope_range = vec2(0.0, 1.0);
uniform float layer0_softness = 0.08;
uniform float layer0_roughness = 0.9;
uniform float layer0_metallic = 0.0;

uniform bool layer1_enabled = false;
uniform bool layer1_use_texture = false;
uniform sampler2D layer1_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer1_tint : source_color = vec4(1.0);
uniform float layer1_uv_scale = 0.08;
uniform bool layer1_use_normal = false;
uniform sampler2D layer1_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float layer1_normal_strength = 1.0;
uniform bool layer1_use_roughness_texture = false;
uniform sampler2D layer1_roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float layer1_roughness_texture_strength = 1.0;
uniform vec2 layer1_height_range = vec2(0.0, 1.0);
uniform vec2 layer1_slope_range = vec2(0.0, 1.0);
uniform float layer1_softness = 0.08;
uniform float layer1_roughness = 0.9;
uniform float layer1_metallic = 0.0;

uniform bool layer2_enabled = false;
uniform bool layer2_use_texture = false;
uniform sampler2D layer2_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer2_tint : source_color = vec4(1.0);
uniform float layer2_uv_scale = 0.08;
uniform bool layer2_use_normal = false;
uniform sampler2D layer2_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float layer2_normal_strength = 1.0;
uniform bool layer2_use_roughness_texture = false;
uniform sampler2D layer2_roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float layer2_roughness_texture_strength = 1.0;
uniform vec2 layer2_height_range = vec2(0.0, 1.0);
uniform vec2 layer2_slope_range = vec2(0.0, 1.0);
uniform float layer2_softness = 0.08;
uniform float layer2_roughness = 0.9;
uniform float layer2_metallic = 0.0;

uniform bool layer3_enabled = false;
uniform bool layer3_use_texture = false;
uniform sampler2D layer3_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer3_tint : source_color = vec4(1.0);
uniform float layer3_uv_scale = 0.08;
uniform bool layer3_use_normal = false;
uniform sampler2D layer3_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float layer3_normal_strength = 1.0;
uniform bool layer3_use_roughness_texture = false;
uniform sampler2D layer3_roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float layer3_roughness_texture_strength = 1.0;
uniform vec2 layer3_height_range = vec2(0.0, 1.0);
uniform vec2 layer3_slope_range = vec2(0.0, 1.0);
uniform float layer3_softness = 0.08;
uniform float layer3_roughness = 0.9;
uniform float layer3_metallic = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying float terrain_height;

float range_weight(float value, vec2 limits, float softness) {
	float low = smoothstep(
		limits.x - softness,
		limits.x + softness,
		value
	);
	float high = 1.0 - smoothstep(
		limits.y - softness,
		limits.y + softness,
		value
	);
	return max(low * high, 0.0);
}

vec3 projection_weights(vec3 normal_value) {
	if (!use_triplanar) {
		return vec3(0.0, 1.0, 0.0);
	}

	vec3 weights = pow(abs(normal_value), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	return weights;
}

vec3 sample_projected_rgb(
	sampler2D texture_source,
	vec3 position,
	vec3 weights,
	float scale
) {
	vec3 result = texture(
		texture_source,
		position.xz * scale
	).rgb * weights.y;

	if (use_triplanar) {
		result += texture(
			texture_source,
			position.zy * scale
		).rgb * weights.x;
		result += texture(
			texture_source,
			position.xy * scale
		).rgb * weights.z;
	}

	return result;
}

float sample_projected_scalar(
	sampler2D texture_source,
	vec3 position,
	vec3 weights,
	float scale
) {
	return sample_projected_rgb(
		texture_source,
		position,
		weights,
		scale
	).r;
}

vec3 sample_normal_perturbation(
	sampler2D texture_source,
	vec3 position,
	vec3 weights,
	float scale
) {
	vec2 top = texture(
		texture_source,
		position.xz * scale
	).rg * 2.0 - 1.0;
	vec3 result = vec3(top.x, 0.0, top.y) * weights.y;

	if (use_triplanar) {
		vec2 side_x = texture(
			texture_source,
			position.zy * scale
		).rg * 2.0 - 1.0;
		vec2 side_z = texture(
			texture_source,
			position.xy * scale
		).rg * 2.0 - 1.0;
		result += vec3(
			0.0,
			side_x.y,
			side_x.x
		) * weights.x;
		result += vec3(
			side_z.x,
			side_z.y,
			0.0
		) * weights.z;
	}

	return result;
}

vec3 layer_color(
	sampler2D texture_source,
	bool use_texture,
	vec4 tint,
	vec3 position,
	vec3 weights,
	float scale
) {
	vec3 color = vec3(1.0);

	if (use_texture) {
		color = sample_projected_rgb(
			texture_source,
			position,
			weights,
			scale
		);
	}

	return color * tint.rgb;
}

float layer_roughness(
	sampler2D texture_source,
	bool use_texture,
	float texture_strength,
	float fallback,
	vec3 position,
	vec3 weights,
	float scale,
	float detail_fade
) {
	if (!detail_enabled || !use_texture || detail_fade <= 0.001) {
		return fallback;
	}

	float sampled = sample_projected_scalar(
		texture_source,
		position,
		weights,
		scale
	);
	return mix(
		fallback,
		sampled,
		clamp(texture_strength * detail_fade, 0.0, 1.0)
	);
}

vec3 layer_normal_perturbation(
	sampler2D texture_source,
	bool use_normal,
	float strength,
	vec3 position,
	vec3 weights,
	float scale,
	float detail_fade
) {
	if (!detail_enabled || !use_normal || detail_fade <= 0.001) {
		return vec3(0.0);
	}

	return sample_normal_perturbation(
		texture_source,
		position,
		weights,
		scale
	) * max(strength, 0.0) * detail_fade;
}

vec3 height_band_color(float normalized_height) {
	float bands = max(debug_height_bands, 2.0);
	float band = floor(
		clamp(normalized_height, 0.0, 0.9999) * bands
	);
	float value = band / max(bands - 1.0, 1.0);
	vec3 phase = vec3(0.00, 0.33, 0.67);
	return 0.55 + 0.45 * cos(
		6.283185 * (phase + value)
	);
}

vec3 world_grid_color(vec3 position) {
	float scale = max(debug_grid_scale, 0.1);
	vec2 cell = floor(position.xz / scale);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 dark = vec3(0.08, 0.10, 0.12);
	vec3 light = vec3(0.70, 0.74, 0.80);
	return mix(dark, light, checker);
}

float detail_fade_at(vec3 position, vec3 camera_position) {
	if (!detail_enabled) {
		return 0.0;
	}

	if (!detail_fade_enabled) {
		return 1.0;
	}

	float fade_end = max(
		detail_distance_end,
		detail_distance_start + 0.01
	);
	return 1.0 - smoothstep(
		detail_distance_start,
		fade_end,
		distance(camera_position, position)
	);
}

void vertex() {
	world_position = (
		MODEL_MATRIX * vec4(VERTEX, 1.0)
	).xyz;
	world_normal = normalize(
		MODEL_NORMAL_MATRIX * NORMAL
	);
	terrain_height = VERTEX.y;
}

void fragment() {
	float normalized_height = clamp(
		(
			terrain_height - height_min
		) / max(
			height_max - height_min,
			0.0001
		),
		0.0,
		1.0
	);
	float slope = 1.0 - clamp(
		abs(world_normal.y),
		0.0,
		1.0
	);
	vec3 surface_normal = normalize(world_normal);
	vec3 weights = projection_weights(surface_normal);
	float detail_fade = detail_fade_at(
		world_position,
		CAMERA_POSITION_WORLD
	);

	float w0 = layer0_enabled ? range_weight(
		normalized_height,
		layer0_height_range,
		layer0_softness
	) * range_weight(
		slope,
		layer0_slope_range,
		layer0_softness
	) : 0.0;
	float w1 = layer1_enabled ? range_weight(
		normalized_height,
		layer1_height_range,
		layer1_softness
	) * range_weight(
		slope,
		layer1_slope_range,
		layer1_softness
	) : 0.0;
	float w2 = layer2_enabled ? range_weight(
		normalized_height,
		layer2_height_range,
		layer2_softness
	) * range_weight(
		slope,
		layer2_slope_range,
		layer2_softness
	) : 0.0;
	float w3 = layer3_enabled ? range_weight(
		normalized_height,
		layer3_height_range,
		layer3_softness
	) * range_weight(
		slope,
		layer3_slope_range,
		layer3_softness
	) : 0.0;

	float total = w0 + w1 + w2 + w3;
	vec3 color = base_color.rgb;
	float roughness = 1.0;
	float metallic = 0.0;
	vec3 perturbation = vec3(0.0);

	if (total > 0.0001) {
		w0 /= total;
		w1 /= total;
		w2 /= total;
		w3 /= total;
	}

	if (debug_view == 1) {
		color = height_band_color(normalized_height);
	} else if (debug_view == 2) {
		color = mix(
			vec3(0.08, 0.72, 0.22),
			vec3(0.96, 0.12, 0.05),
			slope
		);
	} else if (debug_view == 3) {
		color = world_normal * 0.5 + 0.5;
	} else if (debug_view == 4) {
		if (total > 0.0001) {
			color = (
				vec3(0.92, 0.72, 0.20) * w0
				+ vec3(0.18, 0.76, 0.22) * w1
				+ vec3(0.48, 0.50, 0.54) * w2
				+ vec3(0.88, 0.94, 1.00) * w3
			);
		} else {
			color = vec3(1.0, 0.0, 1.0);
		}
	} else if (debug_view == 5) {
		color = world_grid_color(world_position);
	} else if (total > 0.0001) {
		color = vec3(0.0);
		roughness = 0.0;
		metallic = 0.0;

		if (w0 > 0.0) {
			color += layer_color(
				layer0_albedo,
				layer0_use_texture,
				layer0_tint,
				world_position,
				weights,
				layer0_uv_scale
			) * w0;
			roughness += layer_roughness(
				layer0_roughness_texture,
				layer0_use_roughness_texture,
				layer0_roughness_texture_strength,
				layer0_roughness,
				world_position,
				weights,
				layer0_uv_scale,
				detail_fade
			) * w0;
			metallic += layer0_metallic * w0;
			perturbation += layer_normal_perturbation(
				layer0_normal,
				layer0_use_normal,
				layer0_normal_strength,
				world_position,
				weights,
				layer0_uv_scale,
				detail_fade
			) * w0;
		}

		if (w1 > 0.0) {
			color += layer_color(
				layer1_albedo,
				layer1_use_texture,
				layer1_tint,
				world_position,
				weights,
				layer1_uv_scale
			) * w1;
			roughness += layer_roughness(
				layer1_roughness_texture,
				layer1_use_roughness_texture,
				layer1_roughness_texture_strength,
				layer1_roughness,
				world_position,
				weights,
				layer1_uv_scale,
				detail_fade
			) * w1;
			metallic += layer1_metallic * w1;
			perturbation += layer_normal_perturbation(
				layer1_normal,
				layer1_use_normal,
				layer1_normal_strength,
				world_position,
				weights,
				layer1_uv_scale,
				detail_fade
			) * w1;
		}

		if (w2 > 0.0) {
			color += layer_color(
				layer2_albedo,
				layer2_use_texture,
				layer2_tint,
				world_position,
				weights,
				layer2_uv_scale
			) * w2;
			roughness += layer_roughness(
				layer2_roughness_texture,
				layer2_use_roughness_texture,
				layer2_roughness_texture_strength,
				layer2_roughness,
				world_position,
				weights,
				layer2_uv_scale,
				detail_fade
			) * w2;
			metallic += layer2_metallic * w2;
			perturbation += layer_normal_perturbation(
				layer2_normal,
				layer2_use_normal,
				layer2_normal_strength,
				world_position,
				weights,
				layer2_uv_scale,
				detail_fade
			) * w2;
		}

		if (w3 > 0.0) {
			color += layer_color(
				layer3_albedo,
				layer3_use_texture,
				layer3_tint,
				world_position,
				weights,
				layer3_uv_scale
			) * w3;
			roughness += layer_roughness(
				layer3_roughness_texture,
				layer3_use_roughness_texture,
				layer3_roughness_texture_strength,
				layer3_roughness,
				world_position,
				weights,
				layer3_uv_scale,
				detail_fade
			) * w3;
			metallic += layer3_metallic * w3;
			perturbation += layer_normal_perturbation(
				layer3_normal,
				layer3_use_normal,
				layer3_normal_strength,
				world_position,
				weights,
				layer3_uv_scale,
				detail_fade
			) * w3;
		}
	}

	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	if (debug_view == 0 && dot(perturbation, perturbation) > 0.000001) {
		perturbation -= surface_normal * dot(
			surface_normal,
			perturbation
		);
		NORMAL = normalize(
			mat3(VIEW_MATRIX)
			* normalize(surface_normal + perturbation)
		);
	}
}
