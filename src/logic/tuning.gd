# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Tuning
extends RefCounted
## The designer's numbers from data/tuning.json (docs/ARCHITECTURE.md 3.3). Until
## LevelCatalog.load_all() reads the file at startup these hold the GDD's values. They are
## written only then, on the main thread, before any worker thread starts, and only read
## after that, so worker threads may read them freely.
##
## Milestone 1 holds just the rule counts the play state and the solver need. Loading the
## file, and the rest of its numbers, come with the generator.

## Tray slots at the start of an attempt (GDD R1).
static var tray_size: int = 5
## Open box positions (GDD R2, R4).
static var open_boxes: int = 2
## Screws per box (GDD R3, R18).
static var box_slots: int = 3
## Queue boxes shown after the open ones (GDD R4).
static var preview: int = 2
