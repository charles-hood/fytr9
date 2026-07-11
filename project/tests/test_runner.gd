## Dependency-free headless test runner (plan §12).
##
## Run (verified against Godot 4.7.stable.official — see README.md):
##   godot --headless --path project --script res://tests/test_runner.gd
##
## Discovers test_*.gd scripts in TEST_DIRS, instantiates each, and calls
## every method whose name starts with "test_". Exit code 0 on success,
## 1 on any failure.
##
## Tests run only after the first processed frame: nodes added to the tree
## during _initialize never receive NOTIFICATION_READY (no @onready vars),
## which silently breaks any test that instances scenes.
##
## A test method that records zero checks is reported as a failure — a
## GDScript runtime error aborts the method silently, and "no assertions
## ran" is the only observable trace of that.
extends SceneTree

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	await process_frame

	var total_checks := 0
	var suites := 0
	var all_failures: Array[String] = []

	for dir_path in TEST_DIRS:
		var scripts := _find_test_scripts(dir_path)
		# An unreadable/empty configured directory is a broken harness, not a
		# green run — never let discovery failure produce PASS: 0 suites.
		if scripts.is_empty():
			all_failures.append("%s: no test scripts found (missing or unreadable directory?)"
					% dir_path)
		for script_path in scripts:
			suites += 1
			var script: GDScript = load(script_path)
			# A parse error yields a non-null script that can't instantiate;
			# calling new() on it would hard-abort this coroutine and hang
			# the run with quit() unreached (see docs/DECISIONS.md).
			if script == null or not script.can_instantiate():
				all_failures.append("%s: failed to load/parse" % script_path)
				continue
			var case = script.new()
			case.scene_tree = self
			var ran := 0
			for method in script.get_script_method_list():
				var method_name: String = method["name"]
				if not method_name.begins_with("test_"):
					continue
				case.current_test = "%s::%s" % [script_path.get_file(), method_name]
				var checks_before: int = case.checks
				var failures_before: int = case.failures.size()
				case.call(method_name)
				ran += 1
				if case.checks == checks_before and case.failures.size() == failures_before:
					case.failures.append("%s: no assertions ran (runtime abort?)"
							% case.current_test)
			total_checks += case.checks
			all_failures.append_array(case.failures)
			print("%s — %d tests, %d checks, %d failures" % [
					script_path, ran, case.checks, case.failures.size()])

	if suites == 0 or total_checks == 0:
		all_failures.append("harness: no suites or no checks ran — discovery is broken")

	print("")
	if all_failures.is_empty():
		print("PASS: %d suites, %d checks, 0 failures" % [suites, total_checks])
		quit(0)
	else:
		for failure in all_failures:
			printerr("FAIL: " + failure)
		printerr("FAILED: %d failures, %d checks, %d suites" % [
				all_failures.size(), total_checks, suites])
		quit(1)


func _find_test_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
