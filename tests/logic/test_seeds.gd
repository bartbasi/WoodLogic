# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Seeds (docs/ARCHITECTURE.md 4.4): our own 32 bit integer hash, never hash().


func test_seeds_stay_in_32_bits_and_repeat() -> void:
	for n: int in range(0, 2000):
		var v := Seeds.numbered(n)
		check(v >= 0 and v <= 0xFFFFFFFF, "numbered(%d) in 32 bits" % n)
		check_eq(Seeds.numbered(n), v, "numbered(%d) repeats" % n)
	check(Seeds.mix(0xFFFFFFFF, -1) <= 0xFFFFFFFF and Seeds.mix(0xFFFFFFFF, -1) >= 0, "mix of the largest values stays in 32 bits")
	check(Seeds.numbered(1 << 40) != Seeds.numbered(0), "high bits of a level number count")


func test_seeds_streams_differ() -> void:
	var seen := {}
	for n: int in range(1, 3001):
		seen[Seeds.numbered(n)] = true
	check(seen.size() >= 2995, "3000 numbered seeds are (nearly) all different: %d" % seen.size())
	check(Seeds.numbered(20261019) != Seeds.daily(2026, 10, 19), "numbered and daily streams differ")
	check(Seeds.relaxed("easy", 7) != Seeds.relaxed("medium", 7), "relaxed bands differ")
	check(Seeds.relaxed("easy", 7) != Seeds.numbered(7), "relaxed and numbered differ")
	check(Seeds.daily(2026, 10, 19) != Seeds.daily(2026, 10, 20), "days differ")
	check(Seeds.derive(5, 1, 2) != Seeds.derive(5, 2, 1), "derive keeps purpose and index apart")


func test_seeds_pinned_values() -> void:
	# Any change to the hash changes every level: it must come with a new GENERATOR_VERSION.
	check_eq(Seeds.mix(0, 0), _mix_reference(0, 0), "mix(0, 0) matches the reference steps")
	check_eq(Seeds.mix(123456789, 987654321), _mix_reference(123456789, 987654321), "mix matches the reference steps")
	check_eq(Seeds.numbered(9), Seeds.mix(Seeds.mix(Seeds.mix(Seeds.NUMBERED, Generator.GENERATOR_VERSION), 9), 0), "numbered(9) is built from mix")
	# Values worked out separately (a Python copy of the hash) for GENERATOR_VERSION 3.
	check_eq(Generator.GENERATOR_VERSION, 3, "these pins are for version 3 (work them out again for a new version)")
	check_eq(Seeds.numbered(9), 4234036603, "numbered(9)")
	check_eq(Seeds.numbered(100), 1203915924, "numbered(100)")
	check_eq(Seeds.daily(2026, 10, 19), 1879349264, "daily(2026, 10, 19)")
	check_eq(Seeds.relaxed("easy", 7), 2682991825, "relaxed(easy, 7)")


func test_day_number_counts_days_from_2000() -> void:
	check_eq(Seeds.day_number(2000, 1, 1), 0, "2000-01-01")
	check_eq(Seeds.day_number(2000, 3, 1), 60, "2000-03-01 (a leap year)")
	check_eq(Seeds.day_number(2026, 10, 19), 9788, "2026-10-19")
	check_eq(Seeds.day_number(1999, 12, 31), -1, "1999-12-31")
	check_eq(Seeds.day_number(2100, 3, 1), 36584, "2100-03-01 (2100 is not a leap year)")
	for date: int in [20000101, 20000229, 20000301, 19991231, 20261019, 20270101, 20280229, 21000301, 19700101]:
		@warning_ignore("integer_division")
		var dn := Seeds.day_number(date / 10000, (date / 100) % 100, date % 100)
		check_eq(Seeds.date_of_day(dn), date, "date_of_day undoes day_number for %d" % date)
	var last := Seeds.date_of_day(-400)
	for dn: int in range(-399, 40000):
		var date := Seeds.date_of_day(dn)
		if date <= last:
			check(false, "dates rise day by day (%d after %d)" % [date, last])
			break
		last = date


## The hash written out step by step, to pin Seeds.mix.
func _mix_reference(h: int, v: int) -> int:
	h = (h ^ (v & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = (h * 0x01000193) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
	h = (h ^ (h >> 12)) & 0xFFFFFFFF
	h = (h * 0x297A2D39) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	return h
