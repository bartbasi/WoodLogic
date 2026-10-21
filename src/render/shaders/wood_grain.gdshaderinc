// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Procedural wood grain (docs/DESIGN.md 5): flat sawn rings whose depth wanders along the
// plank, which draws the arches of a real board, plus warp, figure, long fibers and pores from
// one small tiling noise texture. Lengths in design units. Included by the bake shaders.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 wood_light : source_color = vec4(0.86, 0.68, 0.42, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.66, 0.44, 0.23, 1.0);
uniform float ring_freq = 0.11;
uniform float ring_contrast = 0.7;
uniform float figure = 14.0;
uniform float fiber = 0.4;
uniform float pores = 0.22;
uniform float seed = 1.0;
uniform float grain_angle = 0.0;
uniform float pith = 0.0;
uniform float tone = 1.0;

float grain_noise(vec2 uv) {
	return texture(noise_tex, uv).r;
}

vec3 wood_grain(vec2 p) {
	float ca = cos(grain_angle);
	float sa = sin(grain_angle);
	vec2 q = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y); // x along the grain
	vec2 so = vec2(seed * 0.137, seed * 0.291);
	float warp = grain_noise(q * vec2(0.0008, 0.003) + so);
	float fig = grain_noise(vec2(q.x * 0.0015 + q.y * 0.002, q.y * 0.005) + so * 1.7);
	float fib = grain_noise(vec2(q.x * 0.003 + q.y * 0.011, q.y * 0.035) + so * 2.3);
	float v = q.y + pith + (warp - 0.5) * figure;
	float depth = 18.0 + 16.0 * sin(q.x * 0.011 + seed * 3.1) + 40.0 * warp;
	float r = sqrt(v * v + depth * depth);
	float ring = fract(r * ring_freq + fig * 0.15);
	float late = smoothstep(0.45, 0.9, ring) * (1.0 - smoothstep(0.9, 1.0, ring));
	float m = clamp(late * ring_contrast + (fib - 0.5) * fiber + (fig - 0.5) * 0.2, 0.0, 1.0);
	vec3 c = mix(wood_light.rgb, wood_dark.rgb, m);
	if (pores > 0.0) {
		float pn = grain_noise(vec2(q.x * 0.02 + q.y * 0.013, q.y * 0.09) + so * 3.1);
		c *= 1.0 - pores * smoothstep(0.6, 0.78, pn);
	}
	return c * tone;
}
