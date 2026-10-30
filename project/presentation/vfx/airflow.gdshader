shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;

varying float age;

vec3 path(float t, float seed, float progress, float length_value) {
	float bow = sin(t * 3.14159);
	float curl = sin(seed * 6.28318 + progress * 2.4);
	float flutter = sin(seed * 15.0 - progress * 3.0);
	return vec3(bow * curl * 0.028 * length_value, bow * flutter * 0.009 * length_value, (t - 1.0) * length_value);
}

void vertex() {
	age = INSTANCE_CUSTOM.x;
	float seed = INSTANCE_CUSTOM.y;
	float length_value = INSTANCE_CUSTOM.z;
	float width = INSTANCE_CUSTOM.w;
	vec3 point = path(UV.y, seed, age, length_value);
	vec3 tangent = path(UV.y + 0.02, seed, age, length_value) - path(UV.y - 0.02, seed, age, length_value);
	mat4 to_view = VIEW_MATRIX * MODEL_MATRIX;
	vec3 direction = (to_view * vec4(tangent, 0.0)).xyz;
	// Face each curved strip toward the camera: no edge-on dotted rails.
	vec2 across = normalize(vec2(-direction.y, direction.x) + vec2(0.00001));
	vec3 position_view = (to_view * vec4(point, 1.0)).xyz;
	position_view.xy += across * (UV.x - 0.5) * width * 2.0 * sin(UV.y * 3.14159);
	VERTEX = position_view;
}

void fragment() {
	float cross_section = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 2.0), 1.4);
	float ends = smoothstep(0.0, 0.28, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	float lifetime = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.48, 1.0, age));
	ALBEDO = COLOR.rgb;
	ALPHA = cross_section * ends * lifetime * COLOR.a;
}
