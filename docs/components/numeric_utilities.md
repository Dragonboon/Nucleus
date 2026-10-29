# Numeric Utilities Contract

## Scope and ownership

Two **stateless**, game-agnostic helpers live under `addons/nucleus/core/utils/`:

- `NucleusBoundedIntMath` (`addons/nucleus/core/utils/math/bounded_int_math.gd`) performs saturating
  signed 64-bit arithmetic.
- `NucleusNumberFormatter` (`addons/nucleus/core/utils/format/number_formatter.gd`) presents
  signed 64-bit quantities as grouped or abbreviated decimal text.

Both extend `RefCounted` and expose static methods. No Node, Autoload, settings
entry, plugin, economic model, or third-party package is required. These helpers
are **not** arbitrary-precision numbers or a replacement for Godot `int` / `float`.

## Bounded integer arithmetic

```gdscript
var capped_total: int = NucleusBoundedIntMath.add(total, gain, 0, 1000000)
var remaining: int = NucleusBoundedIntMath.subtract(total, cost, 0, 1000000)
var production: int = NucleusBoundedIntMath.multiply(units, rate, 0, 1000000)
```

The methods `add(left, right, minimum, maximum)`, `subtract(...)`, and
`multiply(...)` use an inclusive result range. By default the range is the
full signed 64-bit interval. Bounds in reverse order are normalized, and input
operands are **not** clamped before evaluating the operation. Overflow is
checked before arithmetic; no float conversions or `abs(INT64_MIN)` are used.

For a result greater than the maximum, return the maximum. For a result smaller
than the minimum, return the minimum. This also applies to custom ranges that
exclude zero. These are pure deterministic calculations and intentionally do
not mutate an inventory, an attribute, a `NucleusValuePool`, or saved state.

`NucleusValuePool` continues to own bounded *float* values for health, stamina,
energy, etc. Use these helpers for discrete quantities where exact integer
calculations matter. Higher-level code remains responsible for authorization,
transactions, insufficient-resource checks, and balance rules.

## Presenting quantities

```gdscript
NucleusNumberFormatter.grouped(123456789)                 # "123,456,789"
NucleusNumberFormatter.grouped(-1234567, ".")             # "-1.234.567"
NucleusNumberFormatter.compact(1234567)                  # "1.2M"
NucleusNumberFormatter.compact(999950)                   # "1M"
NucleusNumberFormatter.compact(1234567, 2, ",")          # "1,23M"
```

`grouped(value, separator = ",", group_size = 3)` adds separators only. A
non-positive group size or empty separator yields the original numeric text.

`compact(value, decimals = 1, decimal_separator = ".",
trim_trailing_zeros = true)` abbreviates thousands and above. `decimals` is
clamped to 0..3. Rounding is **half up**, based on decimal digits, and carries
to the next tier when appropriate (999.95K -> 1M at one decimal). No floating
point conversion is performed, including for `INT64_MIN`.

Suffixes use the English **short scale**: `K`, `M`, `B`, `T`, `Qa`, `Qi` for
powers of 10 from 3 through 18. Custom decimal separators support simple
presentation needs but **do not automatically localize** suffixes, grouping
rules, decimal conventions, or pluralization. Localized label policy remains
in the consuming game.

These abbreviations are intentionally approximate presentation values; preserve
the original `int` for saving, comparisons, gameplay, or financial correctness.

## Verification

`tests/headless/numeric_utilities_test.gd` is registered in
`tests/headless/test_manifest.gd` and covers signed extrema, overflow, custom
bounds, zero, near-overflow multiplication, rounding carry, separators,
precision, and `INT64_MIN` formatting.

Run the repository's native headless test scene using Godot 4.7.2-stable:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
```

No Godot `.uid` files should be invented; let the editor generate identifiers
for newly imported scripts if needed.
