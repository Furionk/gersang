shader_type canvas_item;
render_mode unshaded;
uniform float highlighted = 0.0;
uniform vec4 atlas_bounds = vec4(0.0,0.0,1.0,1.0);
uniform vec4 outline_color : source_color = vec4(0.25,1.0,0.1,1.0);
uniform float alpha_threshold = 0.18;
uniform float outline_width = 3.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
float covered(float alpha, vec2 point) {
	vec2 inside = step(atlas_bounds.xy,point)*step(point,atlas_bounds.zw);
	return step(alpha_threshold,alpha)*inside.x*inside.y;
}
void fragment() {
	vec4 base = texture(TEXTURE,UV)*vertex_tint;
	vec2 d = TEXTURE_PIXEL_SIZE*outline_width;
	vec2 east = UV+vec2(d.x,0.0);
	vec2 west = UV-vec2(d.x,0.0);
	vec2 south = UV+vec2(0.0,d.y);
	vec2 north = UV-vec2(0.0,d.y);
	vec2 se = UV+d;
	vec2 nw = UV-d;
	vec2 ne = UV+vec2(d.x,-d.y);
	vec2 sw = UV+vec2(-d.x,d.y);
	float around = max(max(covered(texture(TEXTURE,east).a,east),covered(texture(TEXTURE,west).a,west)),max(covered(texture(TEXTURE,south).a,south),covered(texture(TEXTURE,north).a,north)));
	around = max(around,max(max(covered(texture(TEXTURE,se).a,se),covered(texture(TEXTURE,nw).a,nw)),max(covered(texture(TEXTURE,ne).a,ne),covered(texture(TEXTURE,sw).a,sw))));
	float opaque = covered(texture(TEXTURE,UV).a,UV);
	float edge = (1.0-opaque)*around*highlighted;
	COLOR = vec4(mix(base.rgb,outline_color.rgb,edge),max(base.a*opaque,edge*outline_color.a));
}
