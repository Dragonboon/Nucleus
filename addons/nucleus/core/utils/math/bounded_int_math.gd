class_name NucleusBoundedIntMath
extends RefCounted
## Saturating signed 64-bit arithmetic without intermediate integer overflow.
##
## Results are clamped to the inclusive [minimum, maximum] interval. Bounds
## are normalized if supplied in reverse order. Inputs are not pre-clamped.
## This is fixed-width arithmetic, not arbitrary-precision integer math.

const INT64_MIN: int = -9223372036854775807 - 1
const INT64_MAX: int = 9223372036854775807


## Saturating addition. Checks the machine range before calculating a + b.
static func add(
	left: int,
	right: int,
	minimum: int = INT64_MIN,
	maximum: int = INT64_MAX,
) -> int:
	var lower: int = mini(minimum, maximum)
	var upper: int = maxi(minimum, maximum)

	if right > 0 and left > INT64_MAX - right:
		return upper

	if right < 0 and left < INT64_MIN - right:
		return lower

	return clampi(left + right, lower, upper)


## Saturating subtraction, including subtraction of INT64_MIN.
static func subtract(
	left: int,
	right: int,
	minimum: int = INT64_MIN,
	maximum: int = INT64_MAX,
) -> int:
	var lower: int = mini(minimum, maximum)
	var upper: int = maxi(minimum, maximum)

	if right < 0 and left > INT64_MAX + right:
		return upper

	if right > 0 and left < INT64_MIN + right:
		return lower

	return clampi(left - right, lower, upper)


## Saturating multiplication. No abs(INT64_MIN), floating point or overflow.
static func multiply(
	left: int,
	right: int,
	minimum: int = INT64_MIN,
	maximum: int = INT64_MAX,
) -> int:
	var lower: int = mini(minimum, maximum)
	var upper: int = maxi(minimum, maximum)

	if left == 0 or right == 0:
		return clampi(0, lower, upper)

	if left > 0:
		if right > 0 and left > INT64_MAX / right:
			return upper
		if right < 0 and right < INT64_MIN / left:
			return lower
	else:
		if right > 0 and left < INT64_MIN / right:
			return lower
		if right < 0 and left < INT64_MAX / right:
			return upper

	return clampi(left * right, lower, upper)
