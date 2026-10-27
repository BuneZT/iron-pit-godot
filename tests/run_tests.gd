extends SceneTree


func _init() -> void:
	call_deferred("_run_all_suites")


func _run_all_suites() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("Failed to open res://tests directory")
		quit(1)
		return

	var test_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			test_files.append("res://tests/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()

	var total_tests := 0
	var passed_tests := 0
	var failed_tests := 0

	print("==================================================")
	print("IRON PIT (Godot 4.7) — Headless Test Suite Runner")
	print("==================================================")

	for path in test_files:
		var script: GDScript = load(path)
		if script == null:
			printerr("[ERROR] Failed to load test script: %s" % path)
			failed_tests += 1
			continue

		var suite: TestCase = script.new()
		suite.scene_tree = self
		var methods := script.get_script_method_list()
		var test_methods: Array[String] = []
		for m in methods:
			var m_name: String = m["name"]
			if m_name.begins_with("test_"):
				test_methods.append(m_name)
		test_methods.sort()

		print("\nSuite: %s" % path.get_file())
		for m_name in test_methods:
			total_tests += 1
			suite.clear_failures()
			if suite.has_method("before_each"):
				await suite.call("before_each")
			await suite.call(m_name)
			if suite.has_method("after_each"):
				await suite.call("after_each")

			if suite.has_failures():
				failed_tests += 1
				print("  [FAIL] %s" % m_name)
				for err in suite.get_failures():
					print("         -> %s" % err)
			else:
				passed_tests += 1
				print("  [PASS] %s" % m_name)

	print("\n==================================================")
	print("Summary: %d passed, %d failed, %d total" % [passed_tests, failed_tests, total_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)
