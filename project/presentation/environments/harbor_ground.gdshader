shader_type spatial;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 vec2 cell=abs(fract(world/12.0)-0.5);
 float seam=smoothstep(0.488,0.499,max(cell.x,cell.y));
 float grain=fract(sin(dot(world,vec2(127.1,311.7)))*43758.5453);
 ALBEDO=mix(vec3(0.20,0.25,0.24),vec3(0.13,0.17,0.17),seam)+grain*0.012;
 ROUGHNESS=1.0;
 SPECULAR=0.1;
}
