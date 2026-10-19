// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Nordic background: a pale linen wall in soft morning light. A gentle vertical falloff, one
// wide diagonal band of window light, and a faint woven texture from two noise samples.
shader_type canvas_item;

uniform vec2 size = vec2(360.0, 800.0);
uniform vec4 top : source_color = vec4(0.95, 0.94, 0.91, 1.0);
uniform vec4 bottom : source_color = vec4(0.88, 0.86, 0.82, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 uv = lp / size;
	vec3 c = mix(top.rgb, bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	// Window light: a soft diagonal band from the upper left.
	float band = dot(uv - vec2(0.15, 0.1), normalize(vec2(1.0, -0.55)));
	c += vec3(0.035, 0.03, 0.02) * (1.0 - smoothstep(0.0, 0.22, abs(band - 0.05)));
	// Linen weave: fine threads in two directions.
	float warp = texture(noise_tex, vec2(lp.x * 0.8, lp.y * 0.02)).r;
	float weft = texture(noise_tex, vec2(lp.x * 0.02, lp.y * 0.8) + vec2(0.37, 0.11)).r;
	c *= 0.985 + 0.03 * (warp * 0.5 + weft * 0.5);
	COLOR = vec4(c, 1.0);
}
