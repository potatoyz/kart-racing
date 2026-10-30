shader_type spatial;
varying vec3 world_position;

float hash(vec2 point) {
	return fract(sin(dot(point,vec2(127.1,311.7)))*43758.5453);
}

float noise(vec2 point) {
	vec2 i=floor(point);
	vec2 f=fract(point);
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),u.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),u.x),u.y);
}

void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 point=world_position.xz;
	float broad=noise(point*0.025);
	float grain=noise(point*5.0)*0.035;
	vec3 grass=mix(vec3(0.075,0.17,0.085),vec3(0.18,0.28,0.11),broad);
	float dunes=smoothstep(0.62,0.88,noise(point*0.013+vec2(7.0)));
	ALBEDO=mix(grass,vec3(0.57,0.47,0.27),dunes)+grain;
	ROUGHNESS=0.98;
}
