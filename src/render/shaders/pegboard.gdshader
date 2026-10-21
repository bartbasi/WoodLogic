// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The wall behind everything (docs/DESIGN.md 2): perforated hardboard lit by a warm lamp from
// the upper left, falling into shadow at the corners. One full screen pass: a grid of holes,
// one noise sample for the hardboard fiber, and a radial falloff.
shader_type canvas_item;

uniform vec2 size = vec2(360.0, 800.0);
uniform vec4 board : source_color = vec4(0.42, 0.3, 0.2, 1.0);
uniform vec4 hole : source_color = vec4(0.12, 0.07, 0.04, 1.0);
uniform vec2 lamp = vec2(0.22, 0.08); // lamp position as a fraction of the size
uniform float pitch = 24.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float px = max(length(vec2(dFdx(lp.x), dFdy(lp.x))), 0.0001);
	vec2 cell = mod(lp + vec2(pitch * 0.5), vec2(pitch)) - vec2(pitch * 0.5);
	float d = length(cell) - 2.6;
	float fiber = texture(noise_tex, lp * vec2(0.02, 0.05)).r;
	vec3 c = board.rgb * (0.9 + 0.2 * fiber);
	// The lower rim of each hole catches the lamp; the upper rim is in shadow.
	float rim = (1.0 - smoothstep(0.0, 1.2, abs(d))) * clamp(cell.y / 2.6, -1.0, 1.0);
	c *= 1.0 + 0.25 * rim;
	c = mix(c, hole.rgb, 1.0 - smoothstep(-px, px, d));
	vec2 to_lamp = (lp / size - lamp) * vec2(1.0, size.y / size.x * 0.75);
	float light = 1.0 - smoothstep(0.0, 1.25, length(to_lamp));
	c *= 0.45 + 0.75 * light;
	COLOR = vec4(c, 1.0);
}
