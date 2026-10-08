shader_type canvas_item;
// Full-screen frosted dim behind dialogs: blurs what is underneath and tints it.
// `amount` animates 0 -> 1 as the dialog opens.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float amount = 1.0;
uniform vec4 dim : source_color = vec4(0.03, 0.02, 0.10, 0.62);

vec3 blur(vec2 suv, vec2 pixel, float lod) {
	vec2 px = pixel * exp2(lod) * 0.9;
	vec3 c = textureLod(screen_texture, suv, lod).rgb * 0.36;
	c += textureLod(screen_texture, suv + vec2(px.x, px.y), lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(-px.x, px.y), lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(px.x, -px.y), lod).rgb * 0.16;
	c += textureLod(screen_texture, suv + vec2(-px.x, -px.y), lod).rgb * 0.16;
	return c;
}

void fragment() {
	vec3 c = blur(SCREEN_UV, SCREEN_PIXEL_SIZE, amount * 3.4);
	COLOR = vec4(mix(c, dim.rgb, dim.a * amount), 1.0);
}
