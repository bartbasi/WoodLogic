# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Seeds
extends RefCounted
## Seeds for the generator (docs/ARCHITECTURE.md 4.4), from our own integer hash so they are the
## same on every phone and every engine build. Every value stays in 32 bits: the hash only
## multiplies by constants below 2^31 (so a product stays below 2^63) and masks with
## 0xFFFFFFFF after every step. It never uses hash(). Each seed mixes in GENERATOR_VERSION.

const MASK := 0xFFFFFFFF
## Odd multipliers below 2^31.
const M1 := 0x2C1B3C6D
const M2 := 0x297A2D39
const M3 := 0x01000193
## Stream tags, so the streams never share a seed.
const NUMBERED := 0x6E756D62
const DAILY := 0x6461696C
const RELAXED := 0x72656C78
const BAND_CODES: Array[String] = ["easy", "medium", "hard"]


## Mixes one more value (any int; its low 32 bits are used) into a 32 bit hash.
static func mix(h: int, value: int) -> int:
	h = (h ^ (value & MASK)) & MASK
	h = (h * M3) & MASK
	h = (h ^ (h >> 15)) & MASK
	h = (h * M1) & MASK
	h = (h ^ (h >> 12)) & MASK
	h = (h * M2) & MASK
	h = (h ^ (h >> 15)) & MASK
	return h


static func numbered(n: int) -> int:
	return mix(mix(mix(NUMBERED, Generator.GENERATOR_VERSION), n), n >> 32)


static func daily(year: int, month: int, day: int) -> int:
	return mix(mix(DAILY, Generator.GENERATOR_VERSION), year * 10000 + month * 100 + day)


static func relaxed(band: String, index: int) -> int:
	return mix(mix(mix(RELAXED, Generator.GENERATOR_VERSION), BAND_CODES.find(band) + 1), index)


## A seed derived from another for a named purpose (an attempt number, a deal, a block).
static func derive(seed_value: int, purpose: int, index: int) -> int:
	return mix(mix(seed_value, purpose), index)


## Days since 1 January 2000 (a Saturday) for a calendar date, by integer arithmetic only.
static func day_number(year: int, month: int, day: int) -> int:
	return _days_from_civil(year, month, day) - _days_from_civil(2000, 1, 1)


## Howard Hinnant's days_from_civil: days since 1970-01-01 for a proleptic Gregorian date.
static func _days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	@warning_ignore("integer_division")
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var mp := (m + 9) % 12
	@warning_ignore("integer_division")
	var doy := (153 * mp + 2) / 5 + d - 1
	@warning_ignore("integer_division")
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
