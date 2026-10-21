// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Writes fully transparent pixels where it draws, to cut shapes out of a silhouette (the
// monochrome app icon). Only used by the icon tool.
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	COLOR = vec4(0.0);
}
