shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float life = 1.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float band = (1.0 - smoothstep(0.016, 0.085, abs(radius - 0.78)));
	float angle = atan(p.y, p.x);
	float wisps = 0.42 + 0.58 * pow(abs(sin(angle * 3.0 + life * 2.0)), 2.0);
	ALBEDO = vec3(0.48, 0.86, 1.0);
	ALPHA = band * wisps * pow(1.0 - life, 1.6) * strength * 0.50;
}
