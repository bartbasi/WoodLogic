# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RenderFonts
extends RefCounted
## Godot's default font made heavier, for numbers the renderers draw (map badges). Only its
## instance id is kept, so nothing static holds a resource when the game quits.

## The instance id of the shared object, so nothing static holds it (not even a WeakRef).
static var _id := 0


static func bold() -> Font:
	if _id != 0 and is_instance_id_valid(_id):
		var held: Object = instance_from_id(_id)
		if held is FontVariation:
			return held
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	_id = fv.get_instance_id()
	return fv
