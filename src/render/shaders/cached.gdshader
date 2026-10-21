// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Lays down a cached view's texture (CachedDrawing). The texture holds premultiplied color, so it
// is drawn premultiplied, and the node's modulate is applied to color and alpha alike, so a
// modulate fade works.
shader_type canvas_item;
render_mode blend_premul_alpha;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb * tint.rgb * tint.a, t.a * tint.a);
}
