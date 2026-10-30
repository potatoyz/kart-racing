shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float fx_clock=0.0;
uniform float power=0.0;
uniform vec4 tint:source_color=vec4(0.12,0.75,1.0,1.0);
uniform float core=0.0;
uniform float motion_amount=1.0;

void vertex() {
	float swell=0.44+0.7*sin(UV.y*3.14159);
	float flutter=1.0+0.08*motion_amount*sin(UV.y*17.0-fx_clock*24.0);
	VERTEX.xy*=swell*flutter;
}

void fragment() {
	float sway=sin(UV.y*19.0-fx_clock*20.0)*0.06*UV.y*motion_amount*(1.0-core);
	float across=abs(UV.x-0.5+sway)*2.0;
	float taper=pow(max(0.0,1.0-UV.y),0.5);
	float shape=1.0-smoothstep(taper*0.2,taper,across);
	float end=1.0-smoothstep(0.60,1.0,UV.y);
	float flow=0.84+0.16*motion_amount*sin(UV.y*24.0-fx_clock*32.0+sin(UV.x*13.0));
	float beads=0.82+0.18*cos(UV.y*46.0-fx_clock*12.0);
	float alpha=shape*end*flow*beads*power;
	ALBEDO=mix(tint.rgb,vec3(0.82,0.98,1.0),core)*1.15;
	ALPHA=alpha*mix(0.68,0.35,core);
}
