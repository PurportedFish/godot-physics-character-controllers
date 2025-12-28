extends FloatingRigidCharacterBody3D


const MOUSE_SENS: float = 0.08
const MAX_JUMP_BUFFER: int = 3
const JUMP_VELOCITY: float = 5
const WALK_SPEED: float = 3.0
const RUN_SPEED: float = 5.0
const GROUND_ACCEL: float = 15.0
const AIR_ACCEL: float = 3.0

var input_dir: Vector2 = Vector2.ZERO
var speed: float = 3.0
var wants_to_jump: bool = false

@onready var body: Node3D = $Body
@onready var camera: Camera3D = $Body/Camera3D

@onready var _prev_height: float = 0.0

var _jump_frame_buffer: int = 0
var _jump_applied: bool = false


func _ready() -> void:
	super()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true


func _physics_process(_delta: float) -> void:
	detect_environment()
	
	if wants_to_jump:
		if is_on_floor() and not _jump_applied:
			apply_central_impulse(mass * JUMP_VELOCITY * Vector3.UP)
			_jump_applied = true
			_jump_frame_buffer = 0
		else:
			_jump_frame_buffer += 1
			if _jump_frame_buffer >= MAX_JUMP_BUFFER:
				wants_to_jump = false
	
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir: Vector3 = (body.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	
	if is_on_floor():
		try_float()
		acceleration = GROUND_ACCEL
	else:
		acceleration = AIR_ACCEL
		_jump_applied = false
	if dir:
		target_velocity.x = speed * dir.x
		target_velocity.z = speed * dir.z
	else:
		target_velocity.x = 0.0
		target_velocity.z = 0.0
	
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-deg_to_rad(event.relative.x * MOUSE_SENS))
		camera.rotate_x(-deg_to_rad(event.relative.y * MOUSE_SENS))
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))
	
	if event.is_action_pressed("jump"):
		wants_to_jump = true


func modify_move_force(move_force: Vector3) -> Vector3:
	if not is_on_floor():
		return move_force
	
	var curr_cast_height: float = shape_cast.global_position.distance_to(shape_cast.get_collision_point(0))
	var ratio: float = abs(curr_cast_height - _prev_height) / ride_height
	_prev_height = curr_cast_height
	return move_force * (1.0 - ratio)


func modify_drag_force(drag_force: Vector3) -> Vector3:
	if input_dir == Vector2.ZERO and (not is_on_floor() or wants_to_jump):
		return Vector3.ZERO
	return drag_force
