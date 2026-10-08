shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.r < 0.05 && color.g < 0.05 && color.b < 0.05) {
		discard;
	}
	COLOR = color;
}
