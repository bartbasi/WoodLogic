// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// One plank (or the back board) on one quad: its soft shadow on whatever is behind, the edge
// that shows its thickness, the bevel that catches the light, and procedural grain. The shape
// is a signed distance function, so edges are smooth at any scale without MSAA. All lengths are
// in plank local units (the quad's own coordinates, origin at the plank center).
// Cost per pixel: about 8 shape evaluations and 5 samples of one small noise texture.
shader_type canvas_item;

uniform int shape = 0; // 0 box, 1 L (two boxes), 2 disc, 3 ring, 4 triangle
uniform vec4 rect_a = vec4(0.0, 0.0, 50.0, 20.0); // box: center xy, half size zw
uniform vec4 rect_b = vec4(0.0); // second box of an L
uniform vec2 radii = vec2(40.0, 15.0); // disc radius, ring outer and inner radius
uniform vec4 tri_ab = vec4(0.0);
uniform vec2 tri_c = vec2(0.0);
uniform float corner = 8.0;
uniform vec4 holes[6]; // xy center, z radius
uniform int hole_count = 0;

uniform vec2 depth_vec = vec2(1.5, 5.0); // local direction and length of the visible edge
uniform vec2 shadow_vec = vec2(4.0, 7.0);
uniform float shadow_blur = 6.0;
uniform float shadow_alpha = 0.4;
uniform vec4 shadow_color : source_color = vec4(0.1, 0.06, 0.03, 1.0);
uniform vec2 light_local = vec2(-0.5, -0.85); // toward the light, local space

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 wood_light : source_color = vec4(0.85, 0.66, 0.42, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.62, 0.42, 0.22, 1.0);
uniform vec4 edge_color : source_color = vec4(0.5, 0.33, 0.18, 1.0);
uniform vec4 ply_dark : source_color = vec4(0.4, 0.3, 0.2, 1.0);
uniform float plies = 0.0; // stripes on the edge, for plywood; 0 for solid wood
uniform float ring_freq = 0.12;
uniform float ring_contrast = 0.6;
uniform float figure = 30.0;
uniform float fiber = 0.35;
uniform float pores = 0.0;
uniform float seed = 1.0;
uniform float grain_angle = 0.0;
uniform float pith = 0.0;
uniform float tone = 1.0;
uniform float bevel = 4.0;
uniform float bevel_strength = 1.2;
uniform float gloss = 0.0;
uniform float face_light = 0.0; // a gentle lamp falloff across the face, 0 for none
uniform float extent = 100.0;

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

// A union that leaves a small fillet in the inside corner of an L.
float soft_union(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

float outline(vec2 p) {
	if (shape == 1) {
		return soft_union(sd_box(p - rect_a.xy, rect_a.zw, corner), sd_box(p - rect_b.xy, rect_b.zw, corner), corner);
	} else if (shape == 2) {
		return length(p) - radii.x;
	} else if (shape == 3) {
		float l = length(p);
		return max(l - radii.x, radii.y - l);
	} else if (shape == 4) {
		return sd_tri(p, tri_ab.xy, tri_ab.zw, tri_c) - corner;
	}
	return sd_box(p - rect_a.xy, rect_a.zw, corner);
}

float solid(vec2 p) {
	float d = outline(p);
	for (int i = 0; i < hole_count; i++) {
		d = max(d, holes[i].z - length(p - holes[i].xy));
	}
	return d;
}

float noise(vec2 uv) {
	return texture(noise_tex, uv).r;
}

vec3 grain(vec2 p) {
	float ca = cos(grain_angle);
	float sa = sin(grain_angle);
	vec2 q = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y); // x along the grain
	vec2 so = vec2(seed * 0.137, seed * 0.291);
	float warp = noise(q * vec2(0.0008, 0.003) + so);
	float fig = noise(vec2(q.x * 0.0015 + q.y * 0.002, q.y * 0.005) + so * 1.7);
	float fib = noise(vec2(q.x * 0.003 + q.y * 0.011, q.y * 0.035) + so * 2.3);
	// Flat sawn rings: the face cuts the growth rings at a depth that wanders along the plank,
	// which draws the arches (cathedrals) of real boards.
	float v = q.y + pith + (warp - 0.5) * figure;
	float depth = 18.0 + 16.0 * sin(q.x * 0.011 + seed * 3.1) + 40.0 * warp;
	float r = sqrt(v * v + depth * depth);
	float ring = fract(r * ring_freq + fig * 0.15);
	float late = smoothstep(0.45, 0.9, ring) * (1.0 - smoothstep(0.9, 1.0, ring));
	float m = clamp(late * ring_contrast + (fib - 0.5) * fiber + (fig - 0.5) * 0.2, 0.0, 1.0);
	vec3 c = mix(wood_light.rgb, wood_dark.rgb, m);
	if (pores > 0.0) {
		float pn = noise(vec2(q.x * 0.02 + q.y * 0.013, q.y * 0.09) + so * 3.1);
		c *= 1.0 - pores * smoothstep(0.6, 0.78, pn);
	}
	return c * tone;
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / a, a);
}

void fragment() {
	float px = max(length(vec2(dFdx(lp.x), dFdy(lp.x))), 0.0001);
	float aa = px * 0.8;
	float d = solid(lp);

	float ds = d;
	for (int k = 1; k <= 4; k++) {
		ds = min(ds, solid(lp - depth_vec * (float(k) * 0.25)));
	}
	float dsh = outline(lp - shadow_vec);
	float sa = shadow_alpha * (1.0 - smoothstep(-shadow_blur, shadow_blur, dsh));
	vec4 col = vec4(shadow_color.rgb, sa);

	vec2 l2 = normalize(light_local);
	if (ds < aa) {
		// The edge: end grain or plywood, darker toward the back.
		float thick = max(length(depth_vec), 0.001);
		float f = clamp(d / thick, 0.0, 1.0);
		vec2 along_dir = vec2(-depth_vec.y, depth_vec.x) / thick;
		float n = noise(vec2(dot(lp, along_dir) * 0.012, f * 0.2) + vec2(seed * 0.41, 0.0));
		vec3 side = edge_color.rgb * (1.0 - 0.28 * f) * (0.9 + 0.2 * n) * tone;
		if (plies > 0.0) {
			float s = fract(f * plies);
			side = mix(side, ply_dark.rgb, smoothstep(0.78, 0.92, s) * 0.85);
		}
		// A thin highlight where the edge meets the face.
		side += vec3(0.06) * (1.0 - smoothstep(0.0, 0.18, f)) * step(0.0, d);
		col = over(vec4(side, 1.0 - smoothstep(-aa, aa, ds)), col);
	}
	if (d < aa) {
		vec3 face = grain(lp);
		float e = 0.6;
		vec2 g = vec2(solid(lp + vec2(e, 0.0)) - solid(lp - vec2(e, 0.0)), solid(lp + vec2(0.0, e)) - solid(lp - vec2(0.0, e)));
		g = g / max(length(g), 0.0001);
		float t = clamp(-d / bevel, 0.0, 1.0);
		float slope = (1.0 - t) * (1.0 - t) * bevel_strength;
		vec3 n3 = normalize(vec3(g * slope, 1.0));
		vec3 l3 = normalize(vec3(l2 * 0.75, 0.66));
		float shade = dot(n3, l3) / l3.z;
		face *= mix(0.55, 1.0, clamp(shade, 0.0, 1.6)) + max(shade - 1.0, 0.0) * 0.25;
		// A crisp line of light on the lit rim.
		float rim = (1.0 - smoothstep(0.0, px * 2.5, -d)) * max(dot(g, l2), 0.0);
		face += vec3(0.16) * rim;
		if (gloss > 0.0) {
			vec3 h = normalize(l3 + vec3(0.0, 0.0, 1.0));
			float spec = pow(max(dot(n3, h), 0.0), 60.0) * (1.0 - t);
			// A broad lacquer sheen toward the lit corner.
			float sheen = smoothstep(0.2, 1.0, dot(lp / extent, l2)) * 0.5;
			face += vec3(gloss) * (spec + sheen * 0.25);
		}
		if (face_light > 0.0) {
			face *= 1.0 + face_light * dot(lp / extent, l2);
		}
		col = over(vec4(face, 1.0 - smoothstep(-aa, aa, d)), col);
	}
	COLOR = col;
}
