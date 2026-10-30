shader_type spatial;
render_mode cull_back;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float wave_a = sin(p.x * 0.12 + p.y * 0.18 + TIME * 0.65);
	float wave_b = sin(p.x * 0.31 - p.y * 0.19 - TIME * 0.45);
	float shimmer = pow(max(0.0, wave_a * wave_b), 10.0);
	float depth = smoothstep(165.0, 360.0, length(p * vec2(1.0,0.88)));
	vec3 shallow = vec3(0.11, 0.64, 0.66);
	vec3 deep = vec3(0.045, 0.35, 0.52);
	ALBEDO = mix(shallow, deep, depth) + vec3(0.16,0.20,0.17) * shimmer;
	ROUGHNESS = 0.38;
	SPECULAR = 0.5;
}
