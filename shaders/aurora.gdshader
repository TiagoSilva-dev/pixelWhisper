shader_type canvas_item;
// Slowly drifting aurora + soft bokeh. It is rendered into a small SubViewport and scaled up
// (the image is blurry by nature), so the per-pixel cost is negligible even on old phones.

uniform float aspect = 0.5625;                  // width / height of the target
uniform vec4 base_top : source_color = vec4(0.055, 0.035, 0.125, 1.0);
uniform vec4 base_bottom : source_color = vec4(0.02, 0.045, 0.075, 1.0);
uniform vec4 violet : source_color = vec4(0.42, 0.24, 0.95, 1.0);
uniform vec4 magenta : source_color = vec4(0.92, 0.28, 0.66, 1.0);
uniform vec4 teal : source_color = vec4(0.07, 0.72, 0.68, 1.0);
uniform vec4 blue : source_color = vec4(0.18, 0.40, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float speed = 1.0;
uniform float parallax = 0.0;                   // 0..1+, driven by the gallery scroll

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

vec3 blob(vec2 p, vec2 c, float r, vec3 col) {
	vec2 d = p - c;
	return col * exp(-dot(d, d) / (r * r));
}

void fragment() {
	vec2 uv = UV;
	uv.y += parallax * 0.18;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = TIME * 0.11 * speed;

	vec3 col = mix(base_top.rgb, base_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	// Four big light pools on slow Lissajous paths.
	col += blob(p, vec2((0.20 + 0.16 * sin(t * 1.30)) * aspect, 0.16 + 0.07 * sin(t * 0.90 + 1.0)), 0.30, violet.rgb) * 0.44;
	col += blob(p, vec2((0.88 + 0.10 * sin(t * 1.10 + 2.0)) * aspect, 0.30 + 0.10 * sin(t * 0.70)), 0.26, magenta.rgb) * 0.30;
	col += blob(p, vec2((0.12 + 0.12 * sin(t * 0.80 + 4.0)) * aspect, 0.62 + 0.09 * sin(t * 1.00 + 2.5)), 0.34, teal.rgb) * 0.38;
	col += blob(p, vec2((0.78 + 0.14 * sin(t * 0.60 + 1.0)) * aspect, 0.88 + 0.06 * sin(t * 1.20)), 0.36, blue.rgb) * 0.30;
	col += blob(p, vec2((0.55 + 0.10 * sin(t * 1.50)) * aspect, 0.50 + 0.12 * sin(t * 0.50 + 3.0)), 0.22, magenta.rgb) * 0.10;

	// Bokeh: soft discs drifting upward with a gentle twinkle.
	for (int i = 0; i < 14; i++) {
		float fi = float(i);
		float sx = hash11(fi + 1.0);
		float sy = hash11(fi + 17.0);
		float rate = 0.020 + 0.040 * hash11(fi + 31.0);
		vec2 c = vec2((sx + 0.04 * sin(t * 2.0 + fi)) * aspect, fract(sy - t * rate * 3.0));
		float r = 0.010 + 0.022 * hash11(fi + 47.0);
		float d = length(p - c);
		float disc = smoothstep(r, r * 0.35, d);
		float tw = 0.55 + 0.45 * sin(t * 6.0 + fi * 3.1);
		vec3 tone = mix(vec3(0.55, 0.85, 1.0), vec3(1.0, 0.62, 0.92), hash11(fi + 5.0));
		col += tone * disc * (0.07 + 0.12 * hash11(fi + 61.0)) * tw;
	}

	// Gentle vignette keeps the eye on the content.
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.55;
	COLOR = vec4(col * intensity, 1.0);
}
