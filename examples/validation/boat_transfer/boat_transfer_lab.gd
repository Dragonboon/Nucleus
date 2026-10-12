extends Node3D
## Automatic composition fixture: dock -> buoyant moving body -> dock.
## Motor owns walking, native CharacterBody owns platform following, buoyancy owns lift.
## Flat water, locked hull rotation and scripted intent isolate this contract from vehicle policy.

signal completed(success: bool)

class Intent extends NucleusPlanarMotionSource3D:
	var velocity: Vector3 = Vector3.ZERO
	func get_desired_velocity(_body: CharacterBody3D, _speed: float) -> Vector3:
		return velocity

var hull: RigidBody3D
var rider: CharacterBody3D
var intent: Intent
var buoyancy: NucleusBuoyancy3D
var _tick: int = 0
var _phase: int = 0
var _ride_start: Vector3
var _ride_tick: int = 0
var _status: Label
var finished: bool = false
var succeeded: bool = false


func _ready() -> void:
	var water := NucleusPlaneSurfaceSampler3D.new()
	add_child(water)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 30)
	sea.mesh = plane
	sea.material_override = _paint(Color(0.1, 0.3, 0.45))
	sea.position.y = -0.05
	add_child(sea)
	for x in [-5.0, 5.0]:
		var dock := StaticBody3D.new()
		dock.position = Vector3(x, 0.0, 5)
		_box(dock, Vector3(4, 1, 24), Color(0.5, 0.45, 0.35))
		add_child(dock)
	hull = RigidBody3D.new()
	hull.name = "Hull"
	hull.mass = 200.0
	hull.lock_rotation = true
	hull.can_sleep = false
	hull.linear_damp = 0.0
	hull.position.y = -0.4
	_box(hull, Vector3(6, 1, 4), Color(0.7, 0.35, 0.12))
	buoyancy = NucleusBuoyancy3D.new()
	buoyancy.body = hull
	buoyancy.surface_sampler = water
	buoyancy.displacement_volume = 0.4
	buoyancy.linear_drag = 0.0
	hull.add_child(buoyancy)
	add_child(hull)
	rider = CharacterBody3D.new()
	rider.name = "Rider"
	rider.position = Vector3(-5, 1.7, 0)
	rider.floor_snap_length = 0.4
	var collision := CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	rider.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = CapsuleMesh.new()
	visual.material_override = _paint(Color(0.9, 0.85, 0.3))
	rider.add_child(visual)
	intent = Intent.new()
	rider.add_child(intent)
	var motor := NucleusCharacterMotor3D.new()
	motor.body = rider
	motor.motion_source = intent
	rider.add_child(motor)
	add_child(rider)
	var camera := Camera3D.new()
	camera.position = Vector3(15, 17, 23)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 3))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(20, 20)
	canvas.add_child(_status)
	_status.text = "Dock → moving buoyant hull → dock: settling"


func _physics_process(_delta: float) -> void:
	if finished:
		return
	_tick += 1
	if _tick > 1200:
		_finish(false, "Transfer timed out.")
		return
	match _phase:
		0:
			if _tick >= 90:
				if not rider.is_on_floor() or buoyancy.get_wet_fraction() <= 0.0:
					_finish(false, "Dock contact or buoyancy missing.")
					return
				intent.velocity = Vector3.RIGHT * 2.0
				_phase = 1
				_status.text = "Boarding with CharacterMotor3D"
		1:
			if rider.position.x >= -0.5:
				intent.velocity = Vector3.ZERO
				hull.linear_velocity.z = 1.5
				_ride_start = rider.global_position - hull.global_position
				_ride_tick = _tick
				_phase = 2
				_status.text = "Native platform following; no parenting or transform copy"
		2:
			if _tick - _ride_tick >= 150:
				var relative: Vector3 = rider.global_position - hull.global_position
				if not rider.is_on_floor() or absf(relative.z - _ride_start.z) > 0.35:
					_finish(false, "Rider did not follow the moving hull.")
					return
				intent.velocity = Vector3.RIGHT * 2.0
				_phase = 3
				_status.text = "Disembarking onto the second dock"
		3:
			if rider.position.x >= 4.2:
				intent.velocity = Vector3.ZERO
				_finish(rider.is_on_floor(), "Transfer complete; rider is on the second dock.")


func _finish(ok: bool, message: String) -> void:
	print("Boat transfer: ", message, " phase=", _phase)
	finished = true
	succeeded = ok
	_status.text = ("PASS: " if ok else "FAIL: ") + message
	completed.emit(ok)


func _box(parent: PhysicsBody3D, dimensions: Vector3, color: Color) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	parent.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.material_override = _paint(color)
	parent.add_child(visual)


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
