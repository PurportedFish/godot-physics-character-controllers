extends FloatingRigidCharacterBody3D


const MOUSE_SENS: float = 0.08

var input_dir: Vector2 = Vector2.ZERO
var speed: float = 3.0
var wants_to_jump: bool = false

@onready var body: Node3D = $Body
@onready var camera: Camera3D = $Body/Camera3D

@onready var _prev_height: float = 0.0


func _ready() -> void:
	super()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true


func _physics_process(_delta: float) -> void:
	detect_environment()
	try_float()
	
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir: Vector3 = (body.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	
	acceleration = 15.0
	if dir:
		target_velocity.x = speed * dir.x
		target_velocity.z = speed * dir.z
	else:
		target_velocity.x = 0.0
		target_velocity.z = 0.0
	
	move_and_slide()
	
	print(lateral_velocity.length())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-deg_to_rad(event.relative.x * MOUSE_SENS))
		camera.rotate_x(-deg_to_rad(event.relative.y * MOUSE_SENS))
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(90.0))


func modify_move_force(move_force: Vector3) -> Vector3:
	if not is_on_floor():
		return move_force
	
	var curr_cast_height: float = shape_cast.global_position.distance_to(shape_cast.get_collision_point(0))
	var ratio: float = abs(curr_cast_height - _prev_height) / _ride_height
	_prev_height = curr_cast_height
	return move_force * (1.0 - ratio)


func modify_drag_force(drag_force: Vector3) -> Vector3:
	if input_dir == Vector2.ZERO and (not is_on_floor() or wants_to_jump):
		return Vector3.ZERO
	return drag_force
