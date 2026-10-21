# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name CreditsScreen
extends LicenseScreen
## The Credits page (docs/UX.md 3.11): the engine's own license text and the notices of its
## third party parts, as the engine provides them at run time and shown unchanged.


static func make_credits() -> CreditsScreen:
	return new()


func _build_body() -> void:
	body.add_child(text_plaque("WoodLogic is made with the Godot Engine, a free and open source game engine."))
	body.add_child(text_plaque("Every picture and sound in WoodLogic is made by the game's own code."))
	body.add_child(group_heading("Godot Engine"))
	body.add_child(big_text(engine_text()))
	body.add_child(text_plaque(AboutScreen.ATTRIBUTION, "SmallLabel"))
	body.add_child(gap(8.0))


## The engine's license text, its copyright information and the licenses of its parts.
static func engine_text() -> String:
	var parts := PackedStringArray()
	parts.append(Engine.get_license_text())
	parts.append("Third party parts and their notices")
	for entry: Dictionary in Engine.get_copyright_info():
		parts.append(str(entry.get("name", "")))
		for part: Dictionary in entry.get("parts", []):
			var files := PackedStringArray()
			for f: Variant in part.get("files", []):
				files.append(str(f))
			var holders := PackedStringArray()
			for c: Variant in part.get("copyright", []):
				holders.append("Copyright " + str(c))
			parts.append("%s\n%s\nLicense: %s" % [", ".join(files), "\n".join(holders), str(part.get("license", ""))])
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: Variant in licenses:
		parts.append(str(license_name) + "\n" + str(licenses[license_name]))
	return "\n\n".join(parts)
