shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 pixel = texture(TEXTURE, UV) * COLOR;
    COLOR = vec4(mix(pixel.rgb, vec3(1.0, 0.96, 0.78), flash), pixel.a);
}
