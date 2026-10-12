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
	_test_eligible_competition()
	return finish()


func _test_eligible_competition() -> void:
	var biome := NucleusBiomeProfile3D.new()
	biome.biome_id = &"land"
	var composer := NucleusBiomeComposer3D.new()
	composer.biomes = [biome]
	var kind := NucleusPOIType3D.new()
	kind.poi_id = &"camp"
	kind.height_range = Vector2(0, 10)
	var recipe := NucleusPOIDistributionProfile3D.new()
	recipe.types = [kind]
	recipe.grid_spacing = 8.0
	recipe.minimum_separation = 0.0
	recipe.density = 1.0
	var flat := func(_xz: Vector2) -> Dictionary:
		return {"height": 0.0, "slope": 0.0}
	var all_points: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(32, 32), recipe, composer, flat
	)
	recipe.minimum_separation = 8.0
	for descriptor: Dictionary in all_points["points"]:
		var point: Vector3 = descriptor["position"]
		var only_site := func(xz: Vector2) -> Dictionary:
			var suitable: bool = xz.is_equal_approx(Vector2(point.x, point.z))
			return {"height": 0.0 if suitable else 100.0, "slope": 0.0}
		var isolated: Dictionary = NucleusPOIPlanner3D.plan(
			Vector2.ZERO, Vector2(32, 32), recipe, composer, only_site
		)
		expect_equal((isolated["points"] as Array).size(), 1,
			"Unsuitable neighbors cannot suppress the only eligible landmark.")
	var absent := func(_xz: Vector2) -> Dictionary: return {}
	expect_equal(NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(32, 32), recipe, composer, absent
	)["error"], OK, "Missing surface is an empty site, not a failed region.")
	biome.maximum_slope_degrees = -1.0
	expect_false(biome.validate().is_empty(), "Negative biome slope is invalid.")
	kind.maximum_slope_degrees = 91.0
	expect_false(kind.validate().is_empty(), "POI slope above 90 is invalid.")

	var malformed := func(_xz: Vector2) -> Dictionary:
		return {"height": "not a number", "slope": 0.0}
	biome.maximum_slope_degrees = 90.0
	kind.maximum_slope_degrees = 45.0
	expect_equal(NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(32, 32), recipe, composer, malformed
	)["error"], ERR_INVALID_DATA, "Malformed surface data fails without unsafe conversion.")
	expect_equal(NucleusPOIPlanner3D.plan(
		Vector2(1e20, 0), Vector2(32, 32), recipe, composer, flat
	)["error"], ERR_INVALID_PARAMETER, "Cell coordinates cannot overflow Vector2i.")
