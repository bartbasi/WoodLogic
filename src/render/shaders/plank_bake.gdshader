// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Draws a still plank once, into a texture, when the level loads (docs/DESIGN.md 10). The
// shape is the logic's own outline polygon (and a ring's inner outline) with round holes, as a
// signed distance found in one loop that also gives the outward direction, so the bevel needs
// no extra samples. Two outputs, one per pass:
//   pass 0, the face: rgb wood grain (everywhere, so filtering never darkens the rim), a coverage.
//   pass 1, the shape: rg the bevel's surface slope (0.5 is flat), b the rim line, a the soft
//   shadow silhouette (outline only, so holes are in shadow too).
// The texture covers `area` (plank local design units); one texel is `texel` units.
shader_type canvas_item;
render_mode blend_disabled;

#include "res://src/render/shaders/wood_grain.gdshaderinc"

uniform int pass_index = 0;
uniform vec4 area = vec4(0.0, 0.0, 100.0, 100.0);
uniform float texel = 0.33;
uniform vec2 outer[128];
uniform int outer_count = 0;
uniform vec2 inner[64];
uniform int inner_count = 0;
uniform vec3 holes[8];
uniform int hole_count = 0;
uniform float bevel = 4.5;
uniform float bevel_strength = 1.5;
uniform float shadow_blur = 6.0;

varying vec2 lp;

void vertex() {
	lp = area.xy + VERTEX * texel;
}

// One edge of a polygon: keeps the nearest point so far and flips `inside` on a crossing.
void edge(vec2 p, vec2 a, vec2 b, inout float best, inout vec2 best_q, inout bool inside) {
	vec2 e = b - a;
	vec2 w = p - a;
	float t = clamp(dot(w, e) / max(dot(e, e), 1e-6), 0.0, 1.0);
	vec2 q = w - e * t;
	float dd = dot(q, q);
	if (dd < best) {
		best = dd;
		best_q = q;
	}
	if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
		inside = !inside;
	}
}

// Signed distance and outward unit direction, from the nearest point and the crossings.
vec3 signed_result(float best, vec2 best_q, bool inside) {
	float s = inside ? -1.0 : 1.0;
	float d = sqrt(best);
	vec2 g = d > 1e-5 ? best_q / d * s : vec2(0.0, -1.0);
	return vec3(d * s, g);
}

vec3 outer_sd(vec2 p) {
	float best = 1e20;
	vec2 best_q = vec2(1.0, 0.0);
	bool inside = false;
	for (int i = 0; i < outer_count; i++) {
		edge(p, outer[i], outer[(i + 1) % outer_count], best, best_q, inside);
	}
	return signed_result(best, best_q, inside);
}

vec3 inner_sd(vec2 p) {
	float best = 1e20;
	vec2 best_q = vec2(1.0, 0.0);
	bool inside = false;
	for (int i = 0; i < inner_count; i++) {
		edge(p, inner[i], inner[(i + 1) % inner_count], best, best_q, inside);
	}
	return signed_result(best, best_q, inside);
}

void fragment() {
	vec3 o = outer_sd(lp);
	float outline_d = o.x;
	vec3 sd = o;
	if (inner_count > 2) {
		vec3 h = inner_sd(lp);
		if (-h.x > sd.x) {
			sd = vec3(-h.x, -h.yz);
		}
		outline_d = sd.x;
	}
	for (int i = 0; i < hole_count; i++) {
		vec2 to = lp - holes[i].xy;
		float l = length(to);
		float hd = holes[i].z - l;
		if (hd > sd.x) {
			sd = vec3(hd, l > 1e-5 ? -to / l : vec2(0.0, -1.0));
		}
	}
	float aa = texel * 0.75;
	if (pass_index == 0) {
		COLOR = vec4(wood_grain(lp), 1.0 - smoothstep(-aa, aa, sd.x));
	} else {
		float t = clamp(-sd.x / bevel, 0.0, 1.0);
		vec2 slope = sd.yz * (1.0 - t) * (1.0 - t) * bevel_strength;
		float rim = 1.0 - smoothstep(0.0, texel * 2.5, -sd.x);
		float sil = 1.0 - smoothstep(-shadow_blur, shadow_blur, outline_d);
		COLOR = vec4(clamp(slope * 0.25 + 0.5, 0.0, 1.0), rim, sil);
	}
}
