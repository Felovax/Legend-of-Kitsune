class_name Fx
extends RefCounted
## Integer math helpers. Percentages are basis points: 10000 bp = 100%.
## Idle-RPG numbers grow exponentially, so these are written to avoid 64-bit
## overflow: results are exact in normal ranges and saturate at MAX_VALUE.

## Ceiling for exponential curves (1e15); keeps every product below 2^63.
const MAX_VALUE := 1_000_000_000_000_000


## floor(value * basis_points / 10000), without the intermediate overflowing.
static func bp(value: int, basis_points: int) -> int:
	@warning_ignore("integer_division")
	var q := value / 10000
	var r := value % 10000
	@warning_ignore("integer_division")
	return q * basis_points + r * basis_points / 10000


## Repeated multiplication with flooring at each step, so it is exact and
## platform-independent (unlike pow() on floats). Saturates at MAX_VALUE.
static func compound_bp(growth_bp: int, steps: int) -> int:
	var result := 10000
	for i in maxi(steps, 0):
		result = bp(result, growth_bp)
		if result >= MAX_VALUE:
			return MAX_VALUE
	return result
