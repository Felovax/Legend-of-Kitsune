extends SceneTree
## Headless test runner.
##   godot --headless --path . --script res://tests/run_tests.gd
## Optional: TEST_FILTER=<substring> limits which test files or methods run.
## Exit code 0 = all passed, 1 = failures.

const TEST_ROOT := "res://tests/unit"


class ErrorCounter extends Logger:
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_errors.append("%s:%d %s %s" % [file, line, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out


func _initialize() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var filter := OS.get_environment("TEST_FILTER")
	var started := Time.get_ticks_msec()
	var passed := 0
	var failed := 0
	var report: PackedStringArray = []

	for path in _collect_files(TEST_ROOT):
		counter.take()
		var script := load(path) as GDScript
		var load_errors := counter.take()
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			failed += 1
			report.append("FAIL %s: could not load script %s" % [path, "; ".join(load_errors)])
			continue
		var names: PackedStringArray = []
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("test_") and not names.has(method_name):
				names.append(method_name)
		names.sort()
		for method_name in names:
			if filter != "" and not path.contains(filter) and not method_name.contains(filter):
				continue
			var test: TestCase = script.new()
			counter.take()
			test.before_each()
			test.call(method_name)
			var errors := counter.take()
			var label := "%s::%s" % [path.get_file().get_basename(), method_name]
			if test._failures.is_empty() and errors.is_empty() and test._assertions > 0:
				passed += 1
			else:
				failed += 1
				report.append("FAIL %s" % label)
				if test._assertions == 0 and errors.is_empty():
					report.append("    no assertions were made")
				for f in test._failures:
					report.append("    " + f)
				for e in errors:
					report.append("    engine error: " + e)

	OS.remove_logger(counter)
	for line in report:
		print(line)
	print("\n%d passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - started])
	quit(0 if failed == 0 and passed > 0 else 1)


func _collect_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_collect_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out
