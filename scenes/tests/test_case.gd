class_name TestCase
extends Node

const PERCENT_TOLERANCE: float = 5.0
const RELATIVE_TOLERANCE: float = 0.15

var _check_count: int = 0
var _failures: PackedStringArray = []


func check(passed: bool, description: String) -> void:
	_check_count += 1

	if passed:
		print("ok: %s" % description)
	else:
		_failures.append(description)
		push_error("FAILED: %s" % description)


func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	check(
		absf(actual - expected) <= tolerance,
		"%s (expected %s ± %s, got %s)" % [description, expected, tolerance, actual]
	)


# For seeded 2,000-run rates such as win percentages, which shift slightly with balance changes.
func check_percent(actual: float, expected: float, description: String) -> void:
	check_near(actual, expected, PERCENT_TOLERANCE, description)


# For seeded 2,000-run counts and averages, such as dodges or loot gold.
func check_relative(actual: float, expected: float, description: String) -> void:
	check_near(actual, expected, expected * RELATIVE_TOLERANCE, description)


func finish() -> void:
	for failure: String in _failures:
		print("FAILED: %s" % failure)

	print("%d checks run." % _check_count)
	print("PASS" if _failures.is_empty() else "FAIL %d" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
