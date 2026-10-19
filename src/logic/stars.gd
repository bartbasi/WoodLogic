# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Stars
extends RefCounted
## The stars an attempt earns (GDD S1 to S8).


## Vector3i(cleared, fast, clean), each 0 or 1. Nothing without a win, and nothing in Relaxed,
## which has no stars. Fast: the elapsed time, in milliseconds, at most the par time in whole
## seconds (S2, S6). Clean: tray uses at most tray par, which already holds its slack (S7),
## and no helper of any kind (S3, R32). Each star is independent of the others (S4).
static func award(level: LevelData, won: bool, elapsed_ms: int, tray_uses: int, helpers_used: PackedStringArray) -> Vector3i:
	if not won or level.kind == LevelData.RELAXED:
		return Vector3i.ZERO
	var fast := 1 if elapsed_ms <= level.par_time_s * 1000 else 0
	var clean := 1 if tray_uses <= level.tray_par and helpers_used.is_empty() else 0
	return Vector3i(1, fast, clean)


## S8: par time is 5 x ceil((10 + k x screws) / 5) seconds. k is in tenths of a second per
## screw (30 for 3.0) so the sum stays in whole numbers.
static func par_time(screws: int, tenths_per_screw: int, base_s: int = 10, round_to_s: int = 5) -> int:
	var tenths := base_s * 10 + tenths_per_screw * screws
	var step := round_to_s * 10
	@warning_ignore("integer_division")
	var steps := (tenths + step - 1) / step
	return steps * round_to_s
