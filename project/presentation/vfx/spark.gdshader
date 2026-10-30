shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;
uniform float fx_clock=0.0;
varying vec4 particle_data;

void vertex() {
	particle_data=INSTANCE_CUSTOM;
	float angle=particle_data.z*6.28318;
	vec2 p=VERTEX.xy*vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
	p=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p;
	VERTEX=(VIEW_MATRIX*vec4(MODEL_MATRIX[3].xyz,1.0)).xyz+vec3(p,0.0);
}

void fragment() {
	float age=clamp((fx_clock-particle_data.x)/particle_data.y,0.0,1.0);
	vec2 p=(UV-0.5)*2.0;
	float shape=pow(max(0.0,1.0-dot(p,p)),2.0);
	ALBEDO=COLOR.rgb;
	ALPHA=shape*COLOR.a*(1.0-age);
}
