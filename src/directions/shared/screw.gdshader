// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// A screw head seen from the front: a soft contact shadow, a bare metal rim, a colored domed
// cap, and the drive recess cut in the shape of the color's symbol (a slot is the bar, a cross
// is the cross, and so on), so the symbol is never hidden by a separate slot. The recess and
// the brushed marks on the rim rotate with `angle`, so the light on them moves as the screw
// turns. Lengths are in head radii. Cost: small quads, a handful of shape evaluations each.
shader_type canvas_item;

uniform float radius = 14.0;
uniform vec4 head_color : source_color = vec4(0.9, 0.2, 0.1, 1.0);
uniform vec4 metal_light : source_color = vec4(0.92, 0.92, 0.9, 1.0);
uniform vec4 metal_dark : source_color = vec4(0.32, 0.33, 0.35, 1.0);
uniform float angle = 0.0;
uniform int symbol = 0; // DirColors.Sym order; -1 draws a plain cross (symbols off)
uniform float recess_light = 0.0; // 1 shows bright bare metal in the recess (for dark caps)
uniform float rim = 0.2; // rim width in radii
uniform float dome = 0.55;
uniform float gloss = 0.6;
uniform float spec_power = 30.0;
uniform float paint_sheen = 0.0; // a soft wide highlight for matte powder coat
uniform vec2 shadow_off = vec2(0.14, 0.26);
uniform float shadow_blur = 0.22;
uniform float shadow_alpha = 0.45;
uniform vec4 shadow_color : source_color = vec4(0.08, 0.05, 0.03, 1.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
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

// Five point star, one point straight up, folded into one wedge.
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

float sd_symbol(vec2 q) {
	float s = 0.6;
	if (symbol == 0) {
		vec2 off = vec2(0.0, 0.12 * s);
		float r = 0.86 * s;
		return sd_tri(q - off, vec2(0.0, -r), vec2(0.866 * r, 0.5 * r), vec2(-0.866 * r, 0.5 * r)) - 0.05;
	} else if (symbol == 1) {
		return sd_box(q, vec2(0.6 * s), 0.08);
	} else if (symbol == 2) {
		return sd_star(q - vec2(0.0, 0.05 * s), 1.02 * s, 0.46 * s) - 0.025;
	} else if (symbol == 3) {
		return length(q) - 0.62 * s;
	} else if (symbol == 4) {
		vec2 a = abs(q);
		float b = 0.68 * s;
		float h = 1.0 * s;
		return (a.x * h + a.y * b - b * h) / sqrt(b * b + h * h) - 0.02;
	} else if (symbol == 6) {
		return abs(length(q) - 0.62 * s) - 0.16 * s;
	} else if (symbol == 7) {
		return sd_box(q, vec2(1.0 * s, 0.24 * s), 0.05);
	} else if (symbol == 8) {
		return max(length(q) - 0.84 * s, 0.68 * s - length(q - vec2(0.38 * s, -0.22 * s)));
	}
	// 5 and -1: the cross.
	return min(sd_box(q, vec2(0.98 * s, 0.24 * s), 0.04), sd_box(q, vec2(0.24 * s, 0.98 * s), 0.04));
}

vec2 turn(vec2 p) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / a, a);
}

void fragment() {
	vec2 p = lp / radius;
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.0001);
	float r = length(p);

	float dsh = length(p - shadow_off) - 1.0;
	vec4 col = vec4(shadow_color.rgb, shadow_alpha * (1.0 - smoothstep(-shadow_blur, shadow_blur, dsh)));

	if (r < 1.0 + px) {
		vec3 l3 = normalize(vec3(-0.5, -0.8, 1.0));
		vec3 h3 = normalize(l3 + vec3(0.0, 0.0, 1.0));
		float edge = smoothstep(1.0 - rim, 1.0, r);
		vec2 radial = r > 0.0001 ? p / r : vec2(0.0);
		vec3 n = normalize(vec3(p * dome + radial * edge * 1.4, 1.0));
		float diff = max(dot(n, l3), 0.0);
		float spec = pow(max(dot(n, h3), 0.0), spec_power);

		// Bare metal rim with brushed marks that turn with the screw.
		float theta = atan(p.y, p.x) + angle;
		float brushed = 0.5 + 0.5 * sin(theta * 9.0);
		vec3 metal = mix(metal_dark.rgb, metal_light.rgb, clamp(diff * 0.9 + 0.08 * brushed, 0.0, 1.0));
		metal += vec3(spec * 0.9);

		// The colored cap.
		vec3 cap = head_color.rgb * (0.5 + 0.62 * diff);
		cap += vec3(spec * gloss);
		cap += head_color.rgb * paint_sheen * smoothstep(0.4, 1.0, diff);
		float cap_cover = 1.0 - smoothstep(1.0 - rim - px, 1.0 - rim + px, r);
		vec3 headc = mix(metal, cap, cap_cover);
		// A thin dark groove where the cap meets the rim.
		headc *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, px * 1.5, abs(r - (1.0 - rim))));

		// The recess, in the shape of the symbol.
		vec2 q = turn(p);
		float sd = sd_symbol(q);
		if (sd < 0.12) {
			float e = 0.02;
			vec2 g = vec2(sd_symbol(turn(p + vec2(e, 0.0))) - sd_symbol(turn(p - vec2(e, 0.0))),
				sd_symbol(turn(p + vec2(0.0, e))) - sd_symbol(turn(p - vec2(0.0, e))));
			g = g / max(length(g), 0.0001);
			vec3 floor_c = mix(head_color.rgb * 0.16 + vec3(0.02), metal_light.rgb * 0.82, recess_light);
			float wall = 1.0 - smoothstep(0.0, 0.11, -sd); // 1 at the wall, 0 deep inside
			float lit = clamp(dot(-g, l3.xy) * 1.2, -1.0, 1.0);
			vec3 wall_c = lit > 0.0 ? mix(floor_c, metal_light.rgb, lit * 0.85) : floor_c * (1.0 + lit * 0.6);
			vec3 inside = mix(floor_c, wall_c, wall);
			// A shadow cast into the recess from its lit side.
			float into = sd_symbol(turn(p + l3.xy * 0.1));
			inside *= mix(1.0, 0.55, (1.0 - smoothstep(-0.02, 0.04, -into)) * (1.0 - recess_light * 0.5));
			// A thin outline just outside the recess keeps the symbol crisp on any cap color.
			float lip = (1.0 - smoothstep(0.0, 0.07, sd)) * step(0.0, sd);
			headc = mix(headc, headc * (recess_light > 0.5 ? 0.75 : 0.6), lip);
			headc = mix(headc, inside, 1.0 - smoothstep(-px, px, sd));
		}
		col = over(vec4(headc, 1.0 - smoothstep(1.0 - px, 1.0 + px, r)), col);
	}
	COLOR = col;
}
