class_name Fx
extends RefCounted
## Integer math helpers. Percentages are basis points: 10000 bp = 100%.


static func bp(value: int, basis_points: int) -> int:
	@warning_ignore("integer_division")
	return value * basis_points / 10000


## Repeated multiplication with flooring at each step, so it is exact and
## platform-independent (unlike pow() on floats).
static func compound_bp(growth_bp: int, steps: int) -> int:
	var result := 10000
	for i in maxi(steps, 0):
		@warning_ignore("integer_division")
		result = result * growth_bp / 10000
	return result
