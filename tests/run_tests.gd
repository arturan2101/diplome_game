extends Node
## Runs every tests/test_*.gd (a TestCase) one after another and quits with the number
## of failed checks as the exit code. Runs as a scene, not with --script, so autoloads
## (GameManager, Telemetry) exist and their names resolve in every script.

const TESTS_DIR: String = "res://tests"
const ONLY_ARG_PREFIX: String = "--only="
const TEST_LOG_DIR: String = "user://test_logs"


func _ready() -> void:
	# Tests must not write into the real play logs.
	Telemetry.log_directory = TEST_LOG_DIR
	var only: String = _only_filter()
	var total_failures: int = 0
	var total_checks: int = 0
	for file_name: String in _test_files():
		if not _is_wanted(file_name, only):
			continue
		var script: GDScript = load(TESTS_DIR.path_join(file_name)) as GDScript
		if script == null or not script.can_instantiate():
			print("%s: FAILED TO LOAD" % file_name)
			total_failures += 1
			continue
		var test: TestCase = script.new() as TestCase
		if test == null:
			print("%s: NOT A TestCase" % file_name)
			total_failures += 1
			continue
		test.name = file_name.get_basename()
		add_child(test)
		await test.run()
		print("%s: %d checks, %d failed" % [test.name, test.checks, test.failures])
		total_failures += test.failures
		total_checks += test.checks
		test.queue_free()
		# Let freed nodes leave the tree and the physics space before the next test.
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("ALL PASSED (%d checks)" % total_checks if total_failures == 0 else "%d FAILED" % total_failures)
	get_tree().quit(total_failures)


func _test_files() -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			files.append(file_name)
	files.sort()
	return files


## only is a comma-separated list of name parts; empty means every test.
func _is_wanted(file_name: String, only: String) -> bool:
	if only == "":
		return true
	for part: String in only.split(",", false):
		if file_name.contains(part.strip_edges()):
			return true
	return false


func _only_filter() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ONLY_ARG_PREFIX):
			return arg.trim_prefix(ONLY_ARG_PREFIX)
	return ""
