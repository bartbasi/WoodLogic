// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// A baked plank, every frame (docs/DESIGN.md 7, 8 and 10): its soft shadow on what is behind,
// the edge that shows its thickness, then the face lit from the upper left. The edge and the
// shadow are offset in screen space (turned into plank space by the caller), so a swinging
// plank keeps its edge at the bottom and its shadow down right. Seven texture samples a pixel,
// a few dozen operations, no loops over the outline.
shader_type canvas_item;

uniform sampler2D face_tex : filter_linear, repeat_disable;
uniform sampler2D shape_tex : filter_linear, repeat_disable;
uniform vec4 area = vec4(0.0, 0.0, 100.0, 100.0); // what the textures cover, plank local units
uniform vec2 depth_vec = vec2(2.1, 7.0); // the visible edge, plank local units
uniform vec2 shadow_vec = vec2(5.0, 8.0);
uniform float shadow_alpha = 0.55;
uniform vec4 shadow_color : source_color = vec4(0.1, 0.05, 0.02, 1.0);
uniform vec2 light_local = vec2(-0.55, -0.83); // toward the light, plank local
uniform vec4 edge_color : source_color = vec4(0.54, 0.35, 0.17, 1.0);
uniform float tone = 1.0;

varying vec2 lp;
// The node's modulate and self_modulate (Godot folds them into the vertex color), so fades
// with modulate work although this shader writes COLOR itself.
varying vec4 tint;

void vertex() {
	lp = VERTEX;
	tint = COLOR;
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / a, a);
}

void fragment() {
	vec2 uv = (lp - area.xy) / area.zw;
	vec2 duv = depth_vec / area.zw;
	vec4 face = texture(face_tex, uv);
	vec4 shape = texture(shape_tex, uv);

	vec4 col = vec4(shadow_color.rgb, shadow_alpha * texture(shape_tex, uv - shadow_vec / area.zw).a);

	// The edge: where the face, pushed back along the depth, still covers this pixel.
	float side = 0.0;
	float f = 1.0;
	for (int k = 4; k >= 1; k--) {
		float a = texture(face_tex, uv - duv * (float(k) * 0.25)).a;
		if (a > 0.02) {
			f = min(f, float(k) * 0.25);
		}
		side = max(side, a);
	}
	if (side > 0.001) {
		vec3 sc = edge_color.rgb * tone * (1.0 - 0.3 * f);
		sc += vec3(0.05) * (1.0 - smoothstep(0.25, 0.5, f));
		col = over(vec4(sc, side), col);
	}

	if (face.a > 0.001) {
		vec2 slope = (shape.rg - 0.5) * 4.0;
		vec3 n3 = normalize(vec3(slope, 1.0));
		vec2 l2 = normalize(light_local);
		vec3 l3 = normalize(vec3(l2 * 0.75, 0.66));
		float shade = dot(n3, l3) / l3.z;
		vec3 c = face.rgb * (mix(0.55, 1.0, clamp(shade, 0.0, 1.6)) + max(shade - 1.0, 0.0) * 0.25);
		float facing = length(slope) > 0.0001 ? max(dot(normalize(slope), l2), 0.0) : 0.0;
		c += vec3(0.16) * shape.b * facing;
		col = over(vec4(c, face.a), col);
	}
	COLOR = col * tint;
}
