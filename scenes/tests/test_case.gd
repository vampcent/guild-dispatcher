class_name TestCase
extends Node

var _check_count: int = 0
var _failures: PackedStringArray = []


func check(passed: bool, description: String) -> void:
	_check_count += 1

	if passed:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])


func finish() -> void:
	print("%d of %d checks passed." % [_check_count - _failures.size(), _check_count])

	for failure: String in _failures:
		print("FAILED: %s" % failure)

	get_tree().quit(0 if _failures.is_empty() else 1)
