# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The level clock (GDD S6): starts at the first action, stops while paused or held, and at the
## win or the loss. It is driven with made up millisecond counts.


func test_s6_the_clock_waits_for_the_first_action() -> void:
	var c := LevelClock.new()
	check_eq(c.elapsed_ms(5000), 0, "nothing runs before the first action")
	check(not c.is_running(), "not running")
	check(c.start(1000), "the first start reports that it started the clock")
	check(not c.start(2000), "a second start does nothing")
	check_eq(c.elapsed_ms(1500), 500, "counts from the first action")
	check_eq(c.elapsed_ms(4000), 3000, "and goes on")


func test_s6_pause_and_hold_stop_it() -> void:
	var c := LevelClock.new()
	c.start(0)
	c.set_paused(true, 1000)
	check_eq(c.elapsed_ms(9000), 1000, "no time passes while paused")
	c.set_paused(false, 9000)
	check_eq(c.elapsed_ms(9500), 1500, "it goes on from where it stopped")
	c.set_held(true, 10000)
	c.set_paused(true, 10500)
	c.set_paused(false, 11000)
	check_eq(c.elapsed_ms(20000), 2000, "a held clock stays stopped after a pause ends")
	c.set_held(false, 20000)
	check_eq(c.elapsed_ms(20500), 2500, "and runs when the hold ends")
	c.set_paused(true, 21000)
	c.set_paused(true, 22000)
	c.set_paused(false, 23000)
	check_eq(c.elapsed_ms(23000), 3000, "pausing twice counts the paused time once")


func test_s6_a_win_or_loss_stops_it_for_good_and_a_cleared_loss_resumes_it() -> void:
	var c := LevelClock.new()
	c.start(0)
	c.stop(4000)
	check_eq(c.elapsed_ms(9000), 4000, "stopped at the win")
	var lost := LevelClock.new()
	lost.start(0)
	lost.stop(3000)
	lost.resume_after_stop(8000)
	check_eq(lost.elapsed_ms(8500), 3500, "a cleared loss restarts it from where it stopped (R37)")


func test_retry_resets_it() -> void:
	var c := LevelClock.new()
	c.start(0)
	c.set_paused(true, 500)
	c.reset()
	check(not c.started and not c.is_running(), "back to waiting")
	check_eq(c.elapsed_ms(3000), 0, "zero")
	check(c.start(3000), "starts again at the next first action")
