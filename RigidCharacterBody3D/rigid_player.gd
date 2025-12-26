extends RigidCharacterBody3D


const MOUSE_SENS: float = 0.08
const MAX_JUMP_BUFFER: int = 3
const JUMP_VELOCITY: float = 5
const WALK_SPEED: float = 3.0
const RUN_SPEED: float = 5.0
const GROUND_ACCEL: float = 15.0
const AIR_ACCEL: float = 3.0

@export var boost_curve: Curve

var input_dir: Vector2
var speed: float
var wants_to_jump: bool

@onready var body: Node3D = $Body
@onready var camera: Camera3D = $Body/Camera3D
@onready var floor_snap_cast: ShapeCast3D = $FloorSnapCast

# Jump is achieved through applying an impulse. Since it takes a couple of frames before the player
# is off the ground (about 2-3 frames), this variable is use to delay setting wants_to_jump to false
var _jump_frame_buffer: int = 0
var _jump_applied: bool = false


func _ready() -> void:
	super()
	
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	speed = WALK_SPEED


func _physics_process(_delta: float) -> void:
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
	_try_floor_snap()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-deg_to_rad(event.relative.x * MOUSE_SENS))
		camera.rotate_x(-deg_to_rad(event.relative.y * MOUSE_SENS))
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(90.0))
	
	if event.is_action_pressed("jump"):
		wants_to_jump = true
	
	if event.is_action_pressed("run"):
		speed = RUN_SPEED
	elif event.is_action_released("run"):
		speed = WALK_SPEED


func modify_move_force(move_force: Vector3) -> Vector3:
	var normalized_lateral_velocity: Vector3 = lateral_velocity.normalized()
	var normalized_target_velocity: Vector3 = target_velocity.normalized()
	
	var x_dot: float = normalized_lateral_velocity.x * normalized_target_velocity.x
	var z_dot: float = normalized_lateral_velocity.z * normalized_target_velocity.z
	
	if x_dot < 0.0:
		move_force *= boost_curve.sample(x_dot)
	
	if z_dot < 0.0:
		move_force *= boost_curve.sample(z_dot)
	
	return move_force


func modify_drag_force(drag_force: Vector3) -> Vector3:
	if input_dir == Vector2.ZERO and (not is_on_floor() or wants_to_jump):
		return Vector3.ZERO
	return drag_force


func _try_floor_snap() -> void:
	if is_on_floor() or linear_velocity.y > 0.0 or not floor_snap_cast.is_colliding():
		return
	
	var best_normal = Vector3.ZERO
	var shortest_distance = INF
	
	for i in range(floor_snap_cast.get_collision_count()):
		var normal = floor_snap_cast.get_collision_normal(i)
		var collision_point = floor_snap_cast.get_collision_point(i)
		
		if normal.dot(Vector3.UP) < cos(floor_max_angle):
			continue
		
		var dist = global_position.distance_to(collision_point)
		if dist < shortest_distance:
			shortest_distance = dist
			best_normal = normal
	
	if best_normal == Vector3.ZERO:
		return
	
	var down_velocity = linear_velocity.dot(-best_normal)
	if down_velocity > 0:
		return
	
	var snap_strength = mass * get_gravity().length() * min(1.0, shortest_distance * 10.0)
	apply_central_force(-best_normal * snap_strength)
