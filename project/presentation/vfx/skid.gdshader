shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
uniform float fx_clock = 0.0;
varying vec4 timing;
varying vec2 tread_uv;

void vertex() {
	// A fixed MultiMesh slot carries four world-space corners, not a rigid quad.
	vec3 near_left=MODEL_MATRIX[0].xyz;
	vec3 near_right=MODEL_MATRIX[1].xyz;
	vec3 far_left=MODEL_MATRIX[2].xyz;
	vec3 far_right=MODEL_MATRIX[3].xyz;
	vec3 point=mix(mix(near_left,near_right,UV.x),mix(far_left,far_right,UV.x),UV.y);
	float distance=length((far_left+far_right-near_left-near_right)*0.5);
	timing=INSTANCE_CUSTOM;
	tread_uv=vec2(UV.x,timing.w+UV.y*distance*2.0);
	VERTEX=(VIEW_MATRIX*vec4(point,1.0)).xyz;
}

void fragment() {
	float age=fx_clock-timing.x;
	if(timing.y<=0.0 || age<0.0 || age>=timing.y) discard;
	float edge=smoothstep(0.0,0.13,tread_uv.x)*(1.0-smoothstep(0.87,1.0,tread_uv.x));
	float grooves=0.7+0.3*smoothstep(0.2,0.6,abs(sin(tread_uv.x*42.0+tread_uv.y*0.8)));
	float grain=fract(sin(dot(floor(tread_uv*vec2(40.0,55.0)),vec2(12.9898,78.233)))*43758.5453);
	float fade=1.0-smoothstep(max(0.0,timing.y-2.0),timing.y,age);
	ALBEDO=vec3(0.018,0.025,0.027);
	ALPHA=edge*grooves*(0.75+0.25*grain)*timing.z*fade;
}
