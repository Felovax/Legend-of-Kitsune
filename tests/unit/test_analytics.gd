extends TestCase
## The local play log: writes JSON lines, summarizes, rotates and can be off.

var dir: String


func before_each() -> void:
	dir = "user://test_analytics/%d" % Time.get_ticks_usec()


func test_tracks_events_and_summarizes() -> void:
	var a := Analytics.new(dir)
	a.track("session_start", {"runs": 0})
	a.track("run_end", {"chapter": 1, "won": true})
	a.track("run_end", {"chapter": 2, "won": false})
	a.track("purchase", {"product": "gems_80"})
	var events := a.events()
	assert_eq(events.size(), 4)
	assert_eq(events[1]["e"], "run_end")
	assert_eq(events[1]["chapter"], 1)
	assert_true(int(events[0]["t"]) > 0, "has a timestamp")
	var s := a.summary()
	assert_eq(s["sessions"], 1)
	assert_eq(s["runs"], 2)
	assert_eq(s["wins"], 1)
	assert_eq(s["purchases"], 1)
	a.clear()
	assert_eq(a.events().size(), 0)


func test_disabled_log_writes_nothing() -> void:
	var a := Analytics.new(dir, false)
	a.track("session_start")
	assert_false(FileAccess.file_exists(a.path))


func test_large_log_rotates() -> void:
	var a := Analytics.new(dir)
	var filler := "x".repeat(1024)
	for i in 300:
		a.track("filler", {"pad": filler})
	a.track("after_rotation")
	assert_true(FileAccess.file_exists(a.path + ".1"), "old log kept once")
	assert_lt(a.events().size(), 100, "current log started over")
	assert_eq(a.events().back()["e"], "after_rotation")
	a.clear()
	assert_false(FileAccess.file_exists(a.path + ".1"))
