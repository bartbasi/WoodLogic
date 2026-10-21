// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// A screw head (docs/DESIGN.md 3.1 and 4): a soft contact shadow, a bare metal rim with brushed
// marks, a domed enamel cap, and the drive recess cut in the shape of the color's symbol, so the
// symbol is the slot and nothing hides it. The recess and rim marks turn with `angle`, so the
// light on them moves as the screw turns. `lift` raises the head out of its hole (bigger, the
// shadow further and softer). `cover` cross-fades to the covered look: flat, 45 percent, symbol
// at 70 percent, a dashed ring, no shadow. Lengths are in head radii. One small quad.
shader_type canvas_item;

uniform float radius = 14.0;
uniform vec4 head_color : source_color = vec4(0.9, 0.2, 0.12, 1.0);
uniform vec4 metal_light : source_color = vec4(0.96, 0.95, 0.92, 1.0);
uniform vec4 metal_dark : source_color = vec4(0.3, 0.27, 0.24, 1.0);
uniform vec4 recess_metal : source_color = vec4(0.9, 0.89, 0.85, 1.0);
uniform float angle = 0.0;
uniform int symbol = 0; // Palette.Sym; -1 draws a plain cross (symbols off)
uniform float recess_light = 0.0; // 1 shows bright bare metal in the recess (dark caps)
uniform float rim = 0.2;
uniform float dome = 0.5;
uniform float gloss = 0.55;
uniform float spec_power = 26.0;
uniform vec2 shadow_off = vec2(0.14, 0.26);
uniform float shadow_blur = 0.22;
uniform float shadow_alpha = 0.55;
uniform vec4 shadow_color : source_color = vec4(0.1, 0.05, 0.02, 1.0);
uniform float lift = 0.0;
uniform float cover = 0.0;
uniform vec4 ghost_ink : source_color = vec4(0.2, 0.05, 0.02, 1.0);
uniform vec4 ghost_ring : source_color = vec4(0.165, 0.09, 0.03, 1.0);

varying vec2 lp;
// The node's modulate and self_modulate (Godot folds them into the vertex color), so fades
// with modulate work although this shader writes COLOR itself.
varying vec4 tint;

void vertex() {
	lp = VERTEX;
	tint = COLOR;
}

float sd_box(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

float sd_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	float d = min(sd_seg(p, a, b), min(sd_seg(p, b, c), sd_seg(p, c, a)));
	float s1 = cross2(b - a, p - a);
	float s2 = cross2(c - b, p - b);
	float s3 = cross2(a - c, p - c);
	bool inside = (s1 >= 0.0 && s2 >= 0.0 && s3 >= 0.0) || (s1 <= 0.0 && s2 <= 0.0 && s3 <= 0.0);
	return inside ? -d : d;
}

float sd_star(vec2 p, float ro, float ri) {
	float seg = TAU / 5.0;
	float a = atan(p.x, -p.y);
	a = abs(mod(a + seg * 0.5, seg) - seg * 0.5);
	vec2 q = length(p) * vec2(sin(a), cos(a));
	vec2 tip = vec2(0.0, ro);
	vec2 inner = vec2(ri * sin(seg * 0.5), ri * cos(seg * 0.5));
	float d = sd_seg(q, tip, inner);
	return cross2(inner - tip, q - tip) < 0.0 ? -d : d;
}

// The symbols in Palette order (triangle, star, diamond, cross, square, moon, circle, ring,
// bar), fitting a circle of 0.57 head radii (16 units on a 28 unit head).
float sd_symbol(vec2 q, int sym) {
	float s = 0.57;
	if (sym == 0) {
		vec2 off = vec2(0.0, 0.14 * s);
		float r = 0.9 * s;
		return sd_tri(q - off, vec2(0.0, -r), vec2(0.866 * r, 0.5 * r), vec2(-0.866 * r, 0.5 * r)) - 0.05;
	} else if (sym == 1) {
		return sd_star(q - vec2(0.0, 0.06 * s), 1.04 * s, 0.47 * s) - 0.025;
	} else if (sym == 2) {
		vec2 a = abs(q);
		float b = 0.68 * s;
		float h = 1.0 * s;
		return (a.x * h + a.y * b - b * h) / sqrt(b * b + h * h) - 0.02;
	} else if (sym == 4) {
		return sd_box(q, vec2(0.62 * s), 0.08);
	} else if (sym == 5) {
		return max(length(q) - 0.86 * s, 0.7 * s - length(q - vec2(0.38 * s, -0.22 * s)));
	} else if (sym == 6) {
		return length(q) - 0.62 * s;
	} else if (sym == 7) {
		return abs(length(q) - 0.61 * s) - 0.17 * s;
	} else if (sym == 8) {
		return sd_box(q, vec2(1.0 * s, 0.25 * s), 0.05);
	}
	// 3 (the cross) and -1 (symbols off): a cross.
	return min(sd_box(q, vec2(0.98 * s, 0.25 * s), 0.04), sd_box(q, vec2(0.25 * s, 0.98 * s), 0.04));
}

vec2 turn(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / a, a);
}

vec4 free_head(vec2 p0, float px0) {
	float grow = 1.0 + 0.15 * lift;
	vec2 p = p0 / grow;
	float px = px0 / grow;
	float r = length(p);
	float dsh = length(p0 - shadow_off * (1.0 + lift)) - grow;
	float blur = shadow_blur * (1.0 + 2.0 * lift);
	vec4 col = vec4(shadow_color.rgb, shadow_alpha * (1.0 - 0.3 * lift) * (1.0 - smoothstep(-blur, blur, dsh)));
	if (r > 1.0 + px) {
		return col;
	}
	vec3 l3 = normalize(vec3(-0.5, -0.8, 1.0));
	vec3 h3 = normalize(l3 + vec3(0.0, 0.0, 1.0));
	float edge = smoothstep(1.0 - rim, 1.0, r);
	vec2 radial = r > 0.0001 ? p / r : vec2(0.0);
	vec3 n = normalize(vec3(p * dome + radial * edge * 1.4, 1.0));
	float diff = max(dot(n, l3), 0.0);
	float spec = pow(max(dot(n, h3), 0.0), spec_power);
	float theta = atan(p.y, p.x) + angle;
	float brushed = 0.5 + 0.5 * sin(theta * 9.0);
	vec3 metal = mix(metal_dark.rgb, metal_light.rgb, clamp(diff * 0.9 + 0.08 * brushed, 0.0, 1.0)) + vec3(spec * 0.9);
	vec3 cap = head_color.rgb * (0.5 + 0.62 * diff) + vec3(spec * gloss);
	float cap_cover = 1.0 - smoothstep(1.0 - rim - px, 1.0 - rim + px, r);
	vec3 c = mix(metal, cap, cap_cover);
	c *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, px * 1.5, abs(r - (1.0 - rim))));
	int sym = symbol;
	vec2 q = turn(p, angle);
	float sd = sd_symbol(q, sym);
	if (sd < 0.12) {
		float e = 0.02;
		vec2 g = vec2(sd_symbol(turn(p + vec2(e, 0.0), angle), sym) - sd_symbol(turn(p - vec2(e, 0.0), angle), sym),
			sd_symbol(turn(p + vec2(0.0, e), angle), sym) - sd_symbol(turn(p - vec2(0.0, e), angle), sym));
		g = g / max(length(g), 0.0001);
		vec3 floor_c = mix(head_color.rgb * 0.16 + vec3(0.02), recess_metal.rgb * 0.82, recess_light);
		float wall = 1.0 - smoothstep(0.0, 0.11, -sd);
		float lit = clamp(dot(-g, l3.xy) * 1.2, -1.0, 1.0);
		vec3 wall_c = lit > 0.0 ? mix(floor_c, metal_light.rgb, lit * 0.85) : floor_c * (1.0 + lit * 0.6);
		vec3 inside = mix(floor_c, wall_c, wall);
		float into = sd_symbol(turn(p + l3.xy * 0.1, angle), sym);
		inside *= mix(1.0, 0.55, (1.0 - smoothstep(-0.02, 0.04, -into)) * (1.0 - recess_light * 0.5));
		float lip = (1.0 - smoothstep(0.0, 0.07, sd)) * step(0.0, sd);
		c = mix(c, c * (recess_light > 0.5 ? 0.75 : 0.6), lip);
		c = mix(c, inside, 1.0 - smoothstep(-px, px, sd));
	}
	return over(vec4(c, 1.0 - smoothstep(1.0 - px, 1.0 + px, r)), col);
}

vec4 ghost(vec2 p, float px) {
	float r = length(p);
	vec4 col = vec4(head_color.rgb, 0.45 * (1.0 - smoothstep(0.92 - px, 0.92 + px, r)));
	float sd = sd_symbol(p, symbol);
	col = over(vec4(ghost_ink.rgb, 0.7 * (1.0 - smoothstep(-px, px, sd))), col);
	float a = atan(p.y, p.x) / (TAU / 12.0);
	float dash = step(fract(a), 0.55);
	float ring_w = 0.057;
	float on_ring = 1.0 - smoothstep(ring_w - px, ring_w + px, abs(r - 1.0));
	col = over(vec4(ghost_ring.rgb, 0.7 * dash * on_ring), col);
	return col;
}

void fragment() {
	vec2 p = lp / radius;
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.0001);
	vec4 col = vec4(0.0);
	if (cover < 0.999) {
		col = free_head(p, px);
	}
	if (cover > 0.001) {
		vec4 g = ghost(p, px);
		col = mix(col, g, cover);
	}
	COLOR = col * tint;
}
