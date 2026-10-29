extends "res://tests/headless/test_case.gd"

const PatchBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_patch_builder.gd"
)


func run() -> Dictionary:
	_test_incremental_heightmap_patch_build()
	_test_terrain_job_cancellation()
	return finish()


func _test_incremental_heightmap_patch_build() -> void:
	var profile := _terrain_profile()
	var material := StandardMaterial3D.new()
	var job := NucleusTerrainBuildJob.new()
	job.rows_per_step = 2

	expect_equal(
		job.configure(
			profile,
			material,
			Vector3.ZERO,
			1.0,
			false,
			0,
			true,
			true,
		),
		OK,
		"Terrain build job should accept a valid profile.",
	)

	var queue := NucleusMaterializationQueue.new()
	queue.set_automatic_processing(false)
	queue.max_steps_per_frame = 1
	queue.frame_budget_usec = 0

	expect_true(
		queue.enqueue(job) > 0,
		"Terrain build job should enter the generic materialization queue.",
	)

	var pump_count := 0

	while not job.is_terminal() and pump_count < 256:
		queue.pump()
		pump_count += 1

	expect_true(
		job.get_state() == NucleusMaterializationJob.State.COMPLETED,
		"Incremental terrain job should complete under bounded pumping.",
	)
	expect_true(
		pump_count > 4,
		"Terrain construction should be spread across multiple bounded steps.",
	)
	expect_float(
		job.get_progress_ratio(),
		1.0,
		"Completed terrain job should report full progress.",
	)

	var result: Dictionary = job.get_result()
	var patch: Node3D = result.get("node") as Node3D

	expect_true(
		patch != null,
		"Completed terrain materialization should return an unattached patch.",
	)

	var mesh_instance := patch.get_node_or_null(
		"TerrainMesh"
	) as MeshInstance3D
	var collision := patch.get_node_or_null(
		"TerrainCollision/CollisionShape3D"
	) as CollisionShape3D

	expect_true(
		mesh_instance != null and mesh_instance.mesh != null,
		"Incremental terrain job should create the visual ArrayMesh.",
	)
	expect_true(
		collision != null and collision.shape is HeightMapShape3D,
		"Incremental terrain job should build heightmap collision in batches.",
	)

	var synchronous := PatchBuilder.build_patch(
		profile,
		material,
		Vector3.ZERO,
		1.0,
		false,
		0,
		false,
		true,
	)
	var sync_patch: Node3D = synchronous["node"]
	var sync_mesh := sync_patch.get_node("TerrainMesh") as MeshInstance3D
	var job_vertices: PackedVector3Array = (
		mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var sync_vertices: PackedVector3Array = (
		sync_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)

	expect_equal(
		job_vertices,
		sync_vertices,
		"Incremental and synchronous terrain paths should preserve topology.",
	)

	sync_patch.free()
	patch.free()
	queue.free()


func _test_terrain_job_cancellation() -> void:
	var job := NucleusTerrainBuildJob.new()
	job.rows_per_step = 1

	expect_equal(
		job.configure(
			_terrain_profile(),
			null,
			Vector3.ZERO,
		),
		OK,
		"Cancellation fixture should configure normally.",
	)

	var queue := NucleusMaterializationQueue.new()
	queue.set_automatic_processing(false)
	queue.max_steps_per_frame = 1
	queue.frame_budget_usec = 0
	queue.enqueue(job)
	queue.pump()

	expect_equal(
		queue.cancel_job(job),
		OK,
		"Queued terrain work should support explicit cancellation.",
	)
	expect_equal(
		job.get_state(),
		NucleusMaterializationJob.State.CANCELLED,
		"Cancelled terrain work should become terminal without a patch result.",
	)

	queue.free()


func _terrain_profile() -> NucleusTerrainProfile:
	var profile := NucleusTerrainProfile.new()
	profile.size = Vector2(16.0, 16.0)
	profile.resolution = 8
	profile.height_source = NucleusTerrainProfile.HeightSource.FAST_NOISE
	profile.noise = FastNoiseLite.new()
	profile.height_scale = 4.0
	profile.shape_mode = NucleusTerrainProfile.ShapeMode.RECTANGLE
	profile.collision_mode = NucleusTerrainProfile.CollisionMode.HEIGHTMAP
	profile.collision_resolution = 4
	profile.lod_levels = 1
	profile.lod_reduction_factor = 2
	return profile
