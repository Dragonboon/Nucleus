extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var forest := NucleusBiomeProfile3D.new()
	forest.biome_id = &"forest"
	forest.moisture_range = Vector2(0.45, 1.0)
	var desert := NucleusBiomeProfile3D.new()
	desert.biome_id = &"desert"
	desert.moisture_range = Vector2(0.0, 0.45)
	var composer := NucleusBiomeComposer3D.new()
	composer.biomes = [forest, desert]
	expect_true(composer.validate().is_empty(), "Biome profiles validate.")
	expect_equal(composer.resolve_values(0.5, 0.75, 0.0, 0.0)["biome_id"],
		&"forest", "Humid location resolves to forest.")
	expect_equal(composer.resolve_values(0.5, 0.2, 0.0, 0.0)["biome_id"],
		&"desert", "Dry location resolves to desert.")
	expect_true(composer.resolve_values(NAN, 0.5, 0.0, 0.0).is_empty(),
		"Nonfinite climate never selects a biome.")
	var poi := NucleusPOIType3D.new()
	poi.poi_id = &"camp"
	var recipe := NucleusPOIDistributionProfile3D.new()
	recipe.seed = 123
	recipe.grid_spacing = 16.0
	recipe.density = 1.0
	recipe.minimum_separation = 10.0
	recipe.types = [poi]
	expect_true(recipe.validate().is_empty(), "POI recipe validates.")
	var surface := func(_xz: Vector2) -> Dictionary:
		return {"height": 3.0, "slope": 0.0}
	var full: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2(-64, -32), Vector2(128, 64), recipe, composer, surface
	)
	expect_equal(full["error"], OK, "Full region succeeds.")
	var left: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2(-64, -32), Vector2(64, 64), recipe, composer, surface
	)
	var right: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2(0, -32), Vector2(64, 64), recipe, composer, surface
	)
	expect_equal(left["error"], OK, "Left region succeeds.")
	expect_equal(right["error"], OK, "Right region succeeds.")
	var joined: Array = left["points"] + right["points"]
	expect_equal(joined.size(), (full["points"] as Array).size(),
		"Split and full plans have the same number of POIs.")
	var identities: Dictionary = {}
	for descriptor: Dictionary in full["points"]:
		identities[descriptor["id"]] = descriptor["position"]
	for descriptor: Dictionary in joined:
		expect_true(identities.has(descriptor["id"]),
			"Split and full worlds share stable IDs.")
		if identities.has(descriptor["id"]):
			expect_equal(identities[descriptor["id"]], descriptor["position"],
				"Split regions never move landmarks.")
	var repeat: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2(-64, -32), Vector2(128, 64), recipe, composer, surface
	)
	expect_equal(repeat["points"], full["points"],
		"Repeat build returns byte-equivalent descriptors.")
	recipe.max_cells_per_region = 2
	expect_equal(NucleusPOIPlanner3D.plan(
		Vector2(-64, -32), Vector2(128, 64), recipe, composer, surface
	)["error"], ERR_OUT_OF_MEMORY, "Region cell budget is enforced.")
	return finish()
