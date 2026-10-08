shader_type canvas_item;
// Rounded-corner mask for thumbnails and the finished artwork (antialiased, no clip_children
// needed, which keeps it cheap on old GLES3 phones).
//
// NOTE: in canvas_item fragment(), COLOR already holds texture(TEXTURE, UV) * modulate.
// Multiplying by the texture again would square the colors.

uniform float radius_px = 28.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float desaturate = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius_px));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius_px;
	float a = 1.0 - smoothstep(-1.0, 0.75, d);
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(g), desaturate);
	COLOR.a *= a;
}
