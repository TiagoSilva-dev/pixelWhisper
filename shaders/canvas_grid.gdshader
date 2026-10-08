shader_type canvas_item;
// Renders the entire color-by-number grid in ONE draw call.
//
//   TEXTURE   : "answer key"  - the true color of every cell (alpha 0 = not paintable)
//   state_tex : per-cell state. R = palette index, G = painted (0/1), B = pop animation 1 -> 0
//   glyph_tex : 5x7 digit font atlas (10 glyphs, 6 px per glyph cell, 1 px padding top/bottom)
//
// Everything below (grayscale hints, numbers, grid lines, highlight, pop animation,
// completion shine) is computed per fragment, so the CPU never touches individual cells
// except to flip a pixel of state_tex when one is painted.

uniform sampler2D state_tex : filter_nearest, repeat_disable;
uniform sampler2D glyph_tex : filter_linear, repeat_disable;

uniform vec2 grid_size = vec2(64.0, 64.0);
uniform float cell_px = 16.0;        // screen pixels per cell (drives LOD of numbers / grid)
uniform int selected = -1;           // palette index to highlight, -1 = none
uniform vec3 sel_color : source_color = vec3(1.0, 0.8, 0.4);
uniform float show_numbers = 1.0;
uniform float show_grid = 1.0;
uniform float reveal = 0.0;          // 0..1: grid dissolves when the picture is complete
uniform float shine = -1.0;          // diagonal highlight sweep position (-1 = off)
uniform vec3 empty_color : source_color = vec3(0.09, 0.08, 0.13);

const float GLYPH_PX = 0.072;        // cell fraction per glyph pixel -> digits are ~50% of the cell

float number_coverage(int n, vec2 f) {
	bool two = n >= 10;
	float tw = two ? 11.0 : 5.0;
	vec2 p = (f - 0.5) / GLYPH_PX + vec2(tw * 0.5, 3.5);
	if (p.x < -0.5 || p.x > tw + 0.5 || p.y < -0.5 || p.y > 7.5) {
		return 0.0;
	}
	int d = n;
	float lx = p.x;
	if (two) {
		if (p.x < 5.5) {
			d = n / 10;
		} else {
			d = n - (n / 10) * 10;
			lx = p.x - 6.0;
		}
	}
	float v = texture(glyph_tex, vec2(float(d) * 6.0 + lx, p.y + 1.0) / vec2(60.0, 9.0)).r;
	// The atlas is bilinear-filtered; thresholding the blur gives smooth, rounded digits.
	return smoothstep(0.32, 0.62, v);
}

void fragment() {
	vec2 g = UV * grid_size;
	vec2 cell = floor(g);
	ivec2 c = ivec2(clamp(cell, vec2(0.0), grid_size - vec2(1.0)));
	vec2 f = clamp(g - cell, 0.0, 1.0);

	vec4 tgt = texelFetch(TEXTURE, c, 0);
	vec4 st = texelFetch(state_tex, c, 0);
	int idx = int(st.r * 255.0 + 0.5);
	float painted = step(0.5, st.g);
	float anim = st.b;

	if (tgt.a < 0.5) {
		COLOR = vec4(empty_color, 1.0);
	} else {
		// Unpainted: a light grayscale ghost of the picture, so shapes are readable.
		float lum = dot(tgt.rgb, vec3(0.299, 0.587, 0.114));
		vec3 base = vec3(mix(lum, 0.90, 0.52));

		// Cells that match the selected color glow softly in that color.
		float is_sel = (idx == selected && painted < 0.5) ? 1.0 : 0.0;
		float pulse = 0.5 + 0.5 * sin(TIME * 3.2);
		vec3 hl = mix(vec3(1.0), sel_color, 0.55);
		base = mix(base, hl, is_sel * (0.62 + 0.22 * pulse));

		vec3 col = base;
		if (painted > 0.5) {
			// Pop-in: the color grows from the center with a little overshoot + white flash.
			float k = 1.0 - anim;
			float s = 10.0;
			if (anim > 0.0) {
				float eased = 1.0 - pow(1.0 - k, 3.0);
				s = mix(0.45, 1.0, eased) * (1.0 + 0.18 * sin(k * 3.14159));
			}
			vec2 q = abs(f - 0.5) * 2.0;
			float inside = step(max(q.x, q.y), s);
			vec3 pc = mix(tgt.rgb, vec3(1.0), anim * 0.55);
			col = mix(base, pc, inside);
		} else if (show_numbers > 0.0) {
			float na = smoothstep(7.0, 13.0, cell_px) * show_numbers;
			if (na > 0.0) {
				float cov = number_coverage(idx + 1, f);
				vec3 ink = mix(vec3(0.36, 0.34, 0.45), vec3(0.10, 0.08, 0.16), is_sel);
				col = mix(col, ink, cov * na * 0.95);
			}
		}

		// Grid lines: fade in with zoom, fade out on completion.
		float lw = clamp(0.75 / cell_px, 0.0, 0.45);
		vec2 e = min(f, 1.0 - f);
		float d = min(e.x, e.y);
		float line = 1.0 - smoothstep(lw * 0.5, lw * 1.25, d);
		float ga = smoothstep(2.5, 8.0, cell_px) * show_grid * (1.0 - reveal);
		vec3 line_col = mix(vec3(0.62, 0.60, 0.70), tgt.rgb * 0.62, painted);
		col = mix(col, line_col, line * ga * mix(0.55, 0.30, painted));

		// Completion shine sweeping across the finished picture.
		if (shine > -0.5) {
			float diag = (UV.x + UV.y) * 0.5;
			float band = exp(-pow((diag - shine) * 6.5, 2.0));
			col += band * 0.32 * painted;
		}
		COLOR = vec4(col, 1.0);
	}
}
