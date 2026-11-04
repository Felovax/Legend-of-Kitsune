class_name TestCase
extends RefCounted
## Base class for headless unit tests.
## Every method whose name starts with "test_" is run by tests/run_tests.gd.
## A test fails if any assertion fails, if it makes no assertions, or if the
## engine logs an error or script error while it runs.

var _failures: PackedStringArray = []
var _assertions: int = 0


func before_each() -> void:
	pass


func fail(message: String) -> void:
	_assertions += 1
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	_assertions += 1
	if not condition:
		_failures.append("expected true. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	_assertions += 1
	if condition:
		_failures.append("expected false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions += 1
	if not _equals(actual, expected):
		_failures.append("expected <%s> but got <%s>. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assertions += 1
	if _equals(actual, unexpected):
		_failures.append("did not expect <%s>. %s" % [str(unexpected), message])


func assert_gt(actual: Variant, bound: Variant, message: String = "") -> void:
	_assertions += 1
	if not (_is_number(actual) and _is_number(bound) and actual > bound):
		_failures.append("expected <%s> > <%s>. %s" % [str(actual), str(bound), message])


func assert_gte(actual: Variant, bound: Variant, message: String = "") -> void:
	_assertions += 1
	if not (_is_number(actual) and _is_number(bound) and actual >= bound):
		_failures.append("expected <%s> >= <%s>. %s" % [str(actual), str(bound), message])


func assert_lt(actual: Variant, bound: Variant, message: String = "") -> void:
	_assertions += 1
	if not (_is_number(actual) and _is_number(bound) and actual < bound):
		_failures.append("expected <%s> < <%s>. %s" % [str(actual), str(bound), message])


func assert_lte(actual: Variant, bound: Variant, message: String = "") -> void:
	_assertions += 1
	if not (_is_number(actual) and _is_number(bound) and actual <= bound):
		_failures.append("expected <%s> <= <%s>. %s" % [str(actual), str(bound), message])


func assert_between(actual: Variant, low: Variant, high: Variant, message: String = "") -> void:
	_assertions += 1
	if not (_is_number(actual) and actual >= low and actual <= high):
		_failures.append("expected <%s> in [%s, %s]. %s" % [str(actual), str(low), str(high), message])


func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	_assertions += 1
	var found := false
	if container is Array or container is PackedStringArray:
		found = item in container
	elif container is Dictionary:
		found = (container as Dictionary).has(item)
	elif container is String:
		found = (container as String).contains(str(item))
	if not found:
		_failures.append("expected container to have <%s>. %s" % [str(item), message])


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _equals(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return a == b
	if typeof(a) != typeof(b):
		return false
	return a == b
