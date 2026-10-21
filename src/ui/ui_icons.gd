# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiIcons
extends RefCounted
## The one place the screens draw an icon (docs/ARCHITECTURE.md 11.1). Every icon comes from
## the graphic designer's `Icons`; the screens never draw icon art of their own.


static func draw(ci: CanvasItem, icon: String, center: Vector2, size: float, color: Color) -> void:
	Icons.draw(ci, icon, center, size, color)
