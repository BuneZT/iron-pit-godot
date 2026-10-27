class_name TestCase
extends RefCounted

var _failures: Array[String] = []
var scene_tree: SceneTree = null


func has_failures() -> bool:
	return not _failures.is_empty()


func get_failures() -> Array[String]:
	return _failures


func clear_failures() -> void:
	_failures.clear()


func fail(msg: String) -> void:
	_failures.append(msg)


func assert_true(cond: bool, msg := "Expected true, got false") -> void:
	if not cond:
		_failures.append(msg)


func assert_false(cond: bool, msg := "Expected false, got true") -> void:
	if cond:
		_failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		var detail := msg if msg != "" else "Expected %s, got %s" % [str(expected), str(actual)]
		_failures.append(detail)


func assert_ne(actual: Variant, unexpected: Variant, msg := "") -> void:
	if actual == unexpected:
		var detail := msg if msg != "" else "Expected value to not equal %s" % str(unexpected)
		_failures.append(detail)


func assert_near(actual: float, expected: float, tolerance := 0.001, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		var detail := msg if msg != "" else "Expected %f +/- %f, got %f" % [expected, tolerance, actual]
		_failures.append(detail)


func assert_gt(actual: float, threshold: float, msg := "") -> void:
	if not (actual > threshold):
		var detail := msg if msg != "" else "Expected %f > %f" % [actual, threshold]
		_failures.append(detail)


func assert_gte(actual: float, threshold: float, msg := "") -> void:
	if not (actual >= threshold - 0.00001):
		var detail := msg if msg != "" else "Expected %f >= %f" % [actual, threshold]
		_failures.append(detail)


func assert_lt(actual: float, threshold: float, msg := "") -> void:
	if not (actual < threshold):
		var detail := msg if msg != "" else "Expected %f < %f" % [actual, threshold]
		_failures.append(detail)


func assert_lte(actual: float, threshold: float, msg := "") -> void:
	if not (actual <= threshold + 0.00001):
		var detail := msg if msg != "" else "Expected %f <= %f" % [actual, threshold]
		_failures.append(detail)


func assert_not_null(val: Variant, msg := "Expected non-null value") -> void:
	if val == null:
		_failures.append(msg)


func assert_contains(haystack: String, needle: String, msg := "") -> void:
	if not haystack.contains(needle):
		var detail := msg if msg != "" else "Expected '%s' to contain '%s'" % [haystack, needle]
		_failures.append(detail)
