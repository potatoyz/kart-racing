shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float flow_clock = 0.0;
uniform float speed_power = 0.0;
uniform float boost_power = 0.0;
uniform float burst = 0.0;
uniform float reduced = 0.0;
uniform vec2 focus = vec2(0.5, 0.40);

float hash(float n) { return fract(sin(n * 127.1 + 13.7) * 43758.5453); }

float streak_layer(float angle, float radius, float lanes, float offset) {
	float lane = floor(angle * lanes);
	float timing = flow_clock * (1.3 + hash(lane + offset) * 0.9) + hash(lane * 2.7) * 8.0;
	float cycle = fract(timing);
	// Each birth chooses a different angular offset, length and opacity.
	float seed = hash(lane + floor(timing) * 71.3 + offset);
	float center = 0.15 + hash(seed * 121.0) * 0.70;
	center += sin(cycle * 3.14159) * (seed - 0.5) * 0.18;
	float across = abs(fract(angle * lanes) - center);
	float line = 1.0 - smoothstep(0.010, 0.029 + boost_power * 0.011, across);
	float head = 0.24 + cycle * cycle * 1.25;
	float length_value = (0.035 + seed * 0.10) * (0.6 + cycle) * (1.0 + boost_power * 1.6);
	float streak = smoothstep(head - length_value, head - 0.012, radius) * (1.0 - smoothstep(head - 0.007, head, radius));
	float density = (0.20 + speed_power * 0.15 + boost_power * 0.30) * mix(1.0, 0.48, reduced);
	float lifetime = smoothstep(0.0, 0.12, cycle) * (1.0 - smoothstep(0.83, 1.0, cycle));
	return line * streak * step(seed, density) * lifetime;
}

void fragment() {
	vec2 delta = SCREEN_UV - focus;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 radial = delta * aspect;
	float radius = length(radial);
	// The road ahead and the player's car stay sharp. UI is drawn on a later layer.
	float peripheral = smoothstep(0.27, 0.78, radius);
	float zoom = peripheral * (boost_power * 0.006 + burst * 0.003) * (1.0 - reduced);
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	if (zoom > 0.0001) {
		scene += texture(screen_texture, clamp(SCREEN_UV - delta * zoom, vec2(0.0), vec2(1.0))).rgb;
		scene += texture(screen_texture, clamp(SCREEN_UV - delta * zoom * 2.0, vec2(0.0), vec2(1.0))).rgb;
		scene += texture(screen_texture, clamp(SCREEN_UV - delta * zoom * 3.0, vec2(0.0), vec2(1.0))).rgb;
		scene *= 0.25;
	}
	float angle = atan(radial.y, radial.x) / 6.2831853 + 0.5;
	float streaks = streak_layer(angle, radius, 89.0, 0.0) + streak_layer(fract(angle + 0.037), radius, 67.0, 31.0) * 0.65;
	float opacity = (speed_power * 0.25 + boost_power * 0.42 + burst * 0.13) * mix(1.0, 0.50, reduced);
	float wind = streaks * peripheral * opacity;
	vec3 tint = mix(vec3(0.89, 0.97, 1.0), vec3(0.38, 0.86, 1.0), boost_power * 0.60);
	scene = mix(scene, tint, clamp(wind, 0.0, 0.65));
	// A restrained cool edge wash, with no full-screen flash or repeating strobe.
	scene += vec3(0.025, 0.14, 0.19) * peripheral * peripheral * (boost_power * 0.20 + burst * 0.12) * mix(1.0, 0.4, reduced);
	COLOR = vec4(scene, 1.0);
}
