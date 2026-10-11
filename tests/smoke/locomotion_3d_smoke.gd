extends Node3D
## Exercises the motor across real Jolt physics frames, without production art.

class IntentSource extends NucleusPlanarMotionSource3D:
	var intent: Vector3 = Vector3.ZERO

	func get_desired_velocity(_body: CharacterBody3D, _speed: float) -> Vector3:
		return intent


var _body := CharacterBody3D.new()
var _motor := NucleusCharacterMotor3D.new()
var _source := IntentSource.new()
var _tick: int = 0
var _failures := PackedStringArray()
var _landings: int = 0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 1.0, 20.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var body_collision := CollisionShape3D.new()
	body_collision.shape = CapsuleShape3D.new()
	_body.add_child(body_collision)
	_body.position.y = 1.1
	_body.add_child(_source)
	_motor.body = _body
	_motor.motion_source = _source
	_motor.jump_action = &"nucleus_smoke_jump"
	InputMap.add_action(_motor.jump_action)
	_motor.landed.connect(func() -> void: _landings += 1)
	_body.add_child(_motor)
	add_child(_body)


func _physics_process(_delta: float) -> void:
	_tick += 1
	match _tick:
		30:
			_check(_body.is_on_floor(), "Character settles on a physical floor.")
			_jump_event(true)
			_jump_event(false)
		31:
			_check(_body.velocity.y > 1.0 and _body.velocity.y < 3.0, "Short tap jumps.")
		90:
			_check(_body.is_on_floor(), "Character lands after short tap.")
			_jump_event(true)
		91:
			_check(_body.velocity.y > 4.0, "Held jump retains full impulse.")
			var before_release: Vector3 = _body.velocity
			_jump_event(false)
			_check(_body.velocity == before_release, "Input release does not write velocity.")
		92:
			_check(_body.velocity.y > 0.0 and _body.velocity.y < 3.0, "Release cuts ascent.")
		150:
			_check(_body.is_on_floor(), "Character lands after held jump.")
			_check(_landings == 3, "Each landing emits exactly one transition.")
			_source.intent = Vector3.RIGHT * 2.0
		180:
			_check(is_equal_approx(_motor.get_ground_speed(), 2.0), "Analog intent reaches speed.")
			_source.intent = Vector3.ZERO
		210:
			_check(_motor.get_ground_speed() < 0.01, "Ground deceleration stops the body.")
			InputMap.erase_action(_motor.jump_action)
			if _failures.is_empty():
				print("Nucleus locomotion 3D physics smoke: PASS (10 checks).")
			else:
				for failure: String in _failures:
					push_error(failure)
			get_tree().quit(0 if _failures.is_empty() else 1)


func _jump_event(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = _motor.jump_action
	event.pressed = pressed
	_motor._on_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
