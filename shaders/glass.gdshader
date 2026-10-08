shader_type canvas_item;
// Translucent glass without touching the screen texture: no framebuffer copy, so it is the
// "Low" effects quality and the variant used for the many small elements (cards, buttons).
#include "res://shaders/glass_common.gdshaderinc"

void fragment() {
	COLOR = glass_out(glass_shade(UV, vec3(0.0), 0.0), COLOR);
}
