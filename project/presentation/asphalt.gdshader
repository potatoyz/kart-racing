shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 cells=floor(world_position.xz*90.0);
	float grit=fract(sin(dot(cells,vec2(12.9898,78.233)))*43758.5453);
	ALBEDO=vec3(0.065,0.079,0.088)+grit*0.018;
	ROUGHNESS=0.91;
}
