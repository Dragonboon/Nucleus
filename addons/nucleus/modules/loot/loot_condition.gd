class_name NucleusLootCondition
extends Resource
## Extension point for game-specific loot eligibility.
##
## Conditions must be side-effect free. The caller supplies any contextual data.

func check(_context: Dictionary) -> bool:
	return true
