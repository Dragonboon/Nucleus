class_name NucleusNumberFormatter
extends RefCounted
## Stateless formatting for signed 64-bit quantities.
##
## Uses decimal text rather than float conversion, preserving exact integers.
## Suffixes follow the English short scale (K, M, B, T, Qa, Qi). The caller
## owns translated labels and locale-specific presentation policy.

const MAGNITUDE_SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T", "Qa", "Qi",
]


## Groups the original integer digits without changing their value.
## Invalid group sizes or empty separators return the ungrouped number.
static func grouped(
	value: int,
	separator: String = ",",
	group_size: int = 3,
) -> String:
	var original: String = str(value)

	if group_size <= 0 or separator.is_empty():
		return original

	var negative: bool = original.begins_with("-")
	var digits: String = original.substr(1) if negative else original
	var first_group: int = digits.length() % group_size

	if first_group == 0:
		first_group = group_size

	var result: String = digits.substr(0, first_group)

	for index: int in range(first_group, digits.length(), group_size):
		result += separator + digits.substr(index, group_size)

	return ("-" if negative else "") + result


## Abbreviates thousands and above, with decimal rounding (half up).
## Decimal places are constrained to 0..3; trailing zeroes may be removed.
## Rounding across 1000 units carries into the next magnitude (999.95K -> 1M).
static func compact(
	value: int,
	decimals: int = 1,
	decimal_separator: String = ".",
	trim_trailing_zeros: bool = true,
) -> String:
	var original: String = str(value)
	var negative: bool = original.begins_with("-")
	var digits: String = original.substr(1) if negative else original
	var magnitude: int = (digits.length() - 1) / 3

	if magnitude == 0:
		return original

	var precision: int = clampi(decimals, 0, 3)
	var integer_digits: int = digits.length() - magnitude * 3
	var whole: int = digits.substr(0, integer_digits).to_int()
	var remainder: String = digits.substr(integer_digits)
	var fractional: int = 0
	var decimal_factor: int = 1

	for _index: int in range(precision):
		decimal_factor *= 10

	if precision > 0:
		fractional = remainder.substr(0, precision).to_int()

	if remainder.length() > precision and remainder.unicode_at(precision) >= 53:
		fractional += 1

	if fractional >= decimal_factor:
		whole += 1
		fractional = 0

	if whole >= 1000 and magnitude < MAGNITUDE_SUFFIXES.size() - 1:
		magnitude += 1
		whole = 1
		fractional = 0

	var result: String = str(whole)

	if precision > 0:
		var fractional_text: String = str(fractional).pad_zeros(precision)
		if trim_trailing_zeros:
			fractional_text = fractional_text.rstrip("0")
		if not fractional_text.is_empty():
			var punctuation: String = "." if decimal_separator.is_empty() else decimal_separator
			result += punctuation + fractional_text

	result += MAGNITUDE_SUFFIXES[magnitude]
	return ("-" if negative else "") + result
