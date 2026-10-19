# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotStats
extends RefCounted
## What one bot did over some games (one level many times, or many levels pooled).

var games: int = 0
var wins: int = 0
var losses: int = 0
var sum_taps: int = 0
var sum_failed: int = 0
var sum_tray_uses: int = 0
var sum_peak: int = 0
var worst_peak: int = 0
var sum_near_full: int = 0
var sum_time_ms: int = 0
## Games that ended with 0, 1, 2 and 3 stars.
var star_hist := PackedInt32Array([0, 0, 0, 0])
var sum_cleared: int = 0
var sum_fast: int = 0
var sum_clean: int = 0
var violations: int = 0


func add(r: BotResult) -> void:
	games += 1
	wins += 1 if r.won else 0
	losses += 1 if r.lost else 0
	sum_taps += r.taps
	sum_failed += r.failed_calls
	sum_tray_uses += r.tray_uses
	sum_peak += r.peak_tray
	worst_peak = maxi(worst_peak, r.peak_tray)
	sum_near_full += r.near_full
	sum_time_ms += r.elapsed_ms
	star_hist[r.star_total()] += 1
	sum_cleared += r.stars.x
	sum_fast += r.stars.y
	sum_clean += r.stars.z
	violations += r.violation_count


func merge(other: BotStats) -> void:
	games += other.games
	wins += other.wins
	losses += other.losses
	sum_taps += other.sum_taps
	sum_failed += other.sum_failed
	sum_tray_uses += other.sum_tray_uses
	sum_peak += other.sum_peak
	worst_peak = maxi(worst_peak, other.worst_peak)
	sum_near_full += other.sum_near_full
	sum_time_ms += other.sum_time_ms
	for i: int in 4:
		star_hist[i] += other.star_hist[i]
	sum_cleared += other.sum_cleared
	sum_fast += other.sum_fast
	sum_clean += other.sum_clean
	violations += other.violations


func _per_game(total: int) -> float:
	return float(total) / games if games > 0 else 0.0


func win_rate() -> float:
	return _per_game(wins)


func mean_taps() -> float:
	return _per_game(sum_taps)


func mean_failed() -> float:
	return _per_game(sum_failed)


func mean_tray_uses() -> float:
	return _per_game(sum_tray_uses)


func mean_peak() -> float:
	return _per_game(sum_peak)


func mean_near_full() -> float:
	return _per_game(sum_near_full)


func mean_time_s() -> float:
	return _per_game(sum_time_ms) / 1000.0


func mean_stars() -> float:
	return _per_game(star_hist[1] + 2 * star_hist[2] + 3 * star_hist[3])


## The share of games that ended with this many stars.
func star_share(count: int) -> float:
	return _per_game(star_hist[count])
