shader_type canvas_item;
// Glass that blurs whatever is drawn behind it (real backdrop blur). Costs one screen copy per
// frame, shared by every panel using it, so it is reserved for the few panels that scroll
// content passes under (header, filter bar, hint pill, dialogs).
#include "res://shaders/glass_common.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 3.2;
uniform float saturation = 1.28;

vec3 blurred_backdrop(vec2 suv, vec2 pixel) {
	// Mip-chain blur plus 4 offset taps: smooth enough to read as frosted glass.
	vec2 px = pixel * exp2(blur_lod) * 0.8;
	vec3 c = textureLod(screen_texture, suv, blur_lod).rgb * 0.36;
	c += textureLod(screen_texture, suv + vec2(px.x, px.y), blur_lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(-px.x, px.y), blur_lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(px.x, -px.y), blur_lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(-px.x, -px.y), blur_lod).rgb * 0.16;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(l), c, saturation);
}

void fragment() {
	COLOR = glass_out(glass_shade(UV, blurred_backdrop(SCREEN_UV, SCREEN_PIXEL_SIZE), 1.0), COLOR);
}
