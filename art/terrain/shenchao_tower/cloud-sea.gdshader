shader_type canvas_item;
render_mode unshaded;
uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	// All native tiles sample the same plane, including their overlap margins.
	// Mirrored repeats join matching image edges without altering the source PNG.
	vec2 uv = abs(mod(world_point / 1254.0, 2.0) - 1.0);
	COLOR = texture(clouds, uv);
}
