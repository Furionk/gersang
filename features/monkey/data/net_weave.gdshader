shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 cell=abs(fract(UV*40.0)-0.5);
	if (max(cell.x,cell.y)<0.39) discard;
	ALBEDO=vec3(0.03,0.65,0.87);
	ROUGHNESS=0.7;
}
