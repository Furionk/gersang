shader_type spatial;
render_mode unshaded;
uniform vec4 deep_color : source_color = vec4(0.04,0.25,0.32,1.0);
uniform vec4 foam_color : source_color = vec4(0.3,0.65,0.7,1.0);
void fragment() {
 float waves = sin(UV.x*50.0+TIME*1.2)*sin(UV.y*65.0-TIME*0.8);
 float flecks = smoothstep(0.5,0.95,waves);
 ALBEDO = mix(deep_color.rgb,foam_color.rgb,flecks*0.65);
}
