## Dependency-free headless test runner (plan §12).
##
## Run (verified against Godot 4.7.stable.official — see README.md):
##   godot --headless --path project --script res://tests/test_runner.gd
##
## Discovers test_*.gd scripts in TEST_DIRS, instantiates each, and calls
## every method whose name starts with "test_". Exit code 0 on success,
## 1 on any failure.
extends SceneTree

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	var total_checks := 0
	var suites := 0
	var all_failures: Array[String] = []

	for dir_path in TEST_DIRS:
		for script_path in _find_test_scripts(dir_path):
			suites += 1
			var script: GDScript = load(script_path)
			if script == null:
				all_failures.append("%s: failed to load" % script_path)
				continue
			var case = script.new()
			var ran := 0
			for method in script.get_script_method_list():
				var method_name: String = method["name"]
				if method_name.begins_with("test_"):
					case.current_test = "%s::%s" % [script_path.get_file(), method_name]
					case.call(method_name)
					ran += 1
			total_checks += case.checks
			all_failures.append_array(case.failures)
			print("%s — %d tests, %d checks, %d failures" % [
					script_path, ran, case.checks, case.failures.size()])

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
