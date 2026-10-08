// Shared "frosted glass" look for every panel, card, pill and button.
//
// The quad drawn with this shader is `rect_size + 2 * margin` so the soft shadow has room to
// fall off outside the panel. All sizes are in canvas pixels. The composite is done in
// premultiplied alpha so highlights/shadows layer correctly in both variants:
//   glass.gdshader       - translucent fill only (cheap, works everywhere)
//   glass_blur.gdshader  - also blurs whatever is behind the panel (screen texture)

uniform vec2 rect_size = vec2(300.0, 120.0);
uniform float margin = 44.0;
uniform float radius = 36.0;
uniform vec4 tint : source_color = vec4(0.86, 0.82, 1.0, 1.0);
uniform float fill_top = 0.17;
uniform float fill_bottom = 0.07;
uniform float rim = 0.6;            // brightness of the 1.5 px edge light
uniform float bevel = 0.0;          // >0 gives buttons a raised, 3D feel
uniform float shadow_alpha = 0.38;
uniform float shadow_size = 28.0;
uniform float sheen = -1.0;         // 0..1 position of a light sweep, <0 = off
uniform float glow = 0.0;           // soft colored light hugging the inside edge
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.85, 1.0);
uniform float press = 0.0;          // 0..1, darkens slightly when pressed

float sd_round_box(vec2 p, vec2 b, float r) {
	r = min(r, min(b.x, b.y));
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// "A over B" for premultiplied colors.
vec4 over(vec4 a, vec4 b) {
	return a + b * (1.0 - a.a);
}

vec4 glass_shade(vec2 uv, vec3 backdrop, float use_backdrop) {
	vec2 quad = rect_size + vec2(2.0 * margin);
	vec2 p = (uv - 0.5) * quad;
	vec2 half_size = rect_size * 0.5;
	float d = sd_round_box(p, half_size, radius);
	float inside = 1.0 - smoothstep(-0.75, 0.75, d);
	float vy = clamp(p.y / rect_size.y + 0.5, 0.0, 1.0);   // 0 top .. 1 bottom

	float fill = mix(fill_top, fill_bottom, vy);
	vec4 body = use_backdrop > 0.5
		? vec4(mix(backdrop, tint.rgb, fill), 1.0)
		: vec4(tint.rgb * fill, fill);

	// Light from the top-left: bright rim there, faint on the opposite side.
	float edge = 1.0 - smoothstep(0.0, 1.7, abs(d + 0.85));
	float facing = dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.55, -0.85))) * 0.5 + 0.5;
	float rim_light = edge * rim * (0.14 + 0.86 * pow(clamp(facing, 0.0, 1.0), 2.2));
	body = over(vec4(vec3(rim_light), rim_light), body);

	// Soft inner glow along the edge + a faint sky-light over the top half.
	float near_edge = (1.0 - smoothstep(0.0, 16.0, -d)) * step(d, 0.0);
	body = over(vec4(vec3(0.07 * near_edge), 0.07 * near_edge), body);
	float sky = (1.0 - smoothstep(0.0, 0.55, vy)) * 0.075;
	body = over(vec4(vec3(sky), sky), body);

	// Raised bevel for buttons: light lip on top, shade on the bottom.
	if (bevel > 0.0) {
		float lip = (1.0 - smoothstep(0.0, 9.0, -d)) * step(d, 0.0);
		float top_light = lip * (1.0 - vy) * 0.34 * bevel;
		float bottom_shade = lip * vy * 0.28 * bevel;
		body = over(vec4(vec3(top_light), top_light), body);
		body = over(vec4(0.0, 0.0, 0.0, bottom_shade), body);
	}

	if (glow > 0.0) {
		float g = exp(d / 22.0) * step(d, 0.0) * glow;
		body = over(vec4(glow_color.rgb * g, g), body);
	}

	if (sheen >= 0.0) {
		float t = p.x / rect_size.x + p.y / rect_size.y * 0.55 + 0.5;
		float band = exp(-pow((t - (sheen * 2.2 - 0.6)) * 4.2, 2.0)) * 0.26;
		body = over(vec4(vec3(band), band), body);
	}

	if (press > 0.0) {
		body = over(vec4(0.0, 0.0, 0.0, 0.16 * press), body);
	}

	if (use_backdrop > 0.5) {
		// Fine grain breaks up banding in the blurred backdrop and sells the "frosted" feel.
		float n = (hash21(uv * quad) - 0.5) * 0.03;
		body.rgb += vec3(n);
	}

	body *= inside;

	float ds = sd_round_box(p - vec2(0.0, shadow_size * 0.38), half_size, radius);
	float shadow = (1.0 - smoothstep(-shadow_size, shadow_size * 0.9, ds)) * shadow_alpha;
	return over(body, vec4(0.0, 0.0, 0.0, shadow));
}

// Converts the premultiplied result to straight alpha and applies the node's modulate.
vec4 glass_out(vec4 pm, vec4 node_color) {
	vec3 rgb = pm.rgb / max(pm.a, 0.0001);
	return vec4(rgb * node_color.rgb, pm.a * node_color.a);
}
