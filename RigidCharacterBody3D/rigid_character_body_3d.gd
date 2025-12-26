class_name RigidCharacterBody3D
extends RigidBody3D
## A 3D physics body specialized for characters moved by physics simulation and scripts.
##
## [RigidCharacterBody3D] is a [RigidBody3D] intended to be user-controlled. The body
## is moved by calling [method move_and_slide] after setting [member acceleration] 
## and [member target_velocity].


## A vertical position on the body. Collision points above the [member neck_height] is the first
## requirement to be considered a ceiling collision.
@export var neck_height: float = 1.5
## The minimum angle of a collision to be considered a ceiling if the contact position also occurs
## above [member neck_height]
@export_range(0.0, 180, 1.0, "radians_as_degrees") var ceiling_min_angle: float = deg_to_rad(105.0)
@export_group("Floor", "floor")
## If [code]true[/code], the body will not slide on slopes when calling [method move_and_slide]
## when the body is standing still. [br][br]
## If [code]false[/code], the body will slide on floor's slopes when velocity applies a downward force.
@export var floor_stop_on_slope: bool = true
## If [code]false[/code] (by default), the body will move faster on downward slopes and slower on upward slopes. [br][br]
## If [code]true[/code], the body will always move at the same speed on the ground no matter the slope.
@export var floor_constant_speed: bool = false
## A vertical position on the body. Collision points below the [member knee_height] is the first
## requirement to be considered a floor collision.
@export var floor_knee_height: float = 0.5
## The maximum angle of a collision to be considered a floor if the contact position also occurs
## below [member knee_height].
@export_range(0.0, 180, 1.0, "radians_as_degrees") var floor_max_angle: float = deg_to_rad(45.0)
## If [code]true[/code], the body will move in the same velocity while on top of an [AnimatableBody3D]. [br][br]
## If [code]false[/code], the body will not be affected while on top of an [AnimatableBody3D].
@export var move_with_moving_platform: bool = true

## Vector pointing upwards, used for slope behavior calculations.
var up_direction: Vector3 = Vector3.UP
## The body's X and Z velocities only in units per second.
var lateral_velocity: Vector3 = Vector3.ZERO:
	get:
		return Vector3(linear_velocity.x, 0.0, linear_velocity.z)
## The target velocity (typically in meters per second) that the body tries to reach. Used and modified
## during calls to [method move_and_slide].
var target_velocity: Vector3 = Vector3.ZERO
## Used to calculate forces. The higher the acceleration, the faster the body reaches
## [member target_velocity]. It is important to note that a high acceleration and high target speed
## results in a high calculated force being applied to the body. Therefore, collisions with heavier objects
## can result in unrealistic behavior such as a 1 kg [RigidCharacterBody3D] pushing a 100 kg [RigidBody3D].
## If a high acceleration and speed are intended for the body but with alternative collision behavior,
## consider modifying [member acceleration_magnitude] in [method _integrate_forces] to detect if any
## collisions body objects are [RigidBody3D]s and modify the acceleration accordingly.
var acceleration: float = 15.0

var _platform_velocity: Vector3
var _floor_friction: float = 1.0
var _highest_floor_normal: Vector3 = Vector3.ZERO
var _is_on_ceiling: bool = false
var _is_on_floor: bool = false
var _is_on_wall: bool = false


func _ready() -> void:
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	
	can_sleep = false
	
	contact_monitor = true
	max_contacts_reported = 32


## Applies forces to the body to reach [member target_velocity].
func move_and_slide() -> void:
	_detect_environment()
	
	var move_force = Vector3.ZERO
	var drag_force = Vector3.ZERO
	var relative_velocity: Vector3
	
	if target_velocity != Vector3.ZERO:
		move_force = mass * acceleration * target_velocity.normalized() * _floor_friction
		move_force = modify_move_force(move_force)
		relative_velocity = lateral_velocity - _platform_velocity
		
		if is_on_floor():
			if move_force.normalized().dot(_highest_floor_normal) > 0.1:
				move_force = move_force.slide(_highest_floor_normal)
			if not floor_constant_speed and target_velocity.normalized().dot(_highest_floor_normal) < -0.1:
				move_force *= clampf(_highest_floor_normal.dot(up_direction), -1.0, 1.0)
		
		var speed_radio: float = relative_velocity.length() / target_velocity.length()
		var drag_scalar: float = speed_radio * _floor_friction
		drag_force = mass * acceleration * -relative_velocity.normalized() * drag_scalar
	else:
		relative_velocity = linear_velocity - _platform_velocity
		drag_force = mass * acceleration * -relative_velocity * _floor_friction
	
	drag_force = modify_drag_force(drag_force)
	
	apply_central_force(move_force + drag_force)


## Override this method to modify the move force before it is applied to the body. [param move_force]
## is equal to [code]mass * acceleration_magnitude * target_velocity.normalized()[/code]
func modify_move_force(move_force: Vector3) -> Vector3:
	return move_force

## Override this method to modify the drag force before it is applied to the body. [param drag_force]
## is equal to [code]mass * acceleration_magnitude * -relative_velocity.normalized() * drag_scalar[/code]
## where [code]relative_velocity = lateral_velocity - platform_velocity[/code] if
## [code]target_velocity != Vector3.ZERO[/code] else [code]relative_velocity = linear_velocity - platform_velocity[/code]
## and [code]drag_scalar = relative_velocity.lengt() / target_velocity.length() * _floor_friction [/code]
func modify_drag_force(drag_force: Vector3) -> Vector3:
	return drag_force


## Returns [code]true[/code] if the body collided with the ceiling on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member neck_height] and [member ceiling_min_angle] are used
## to determine whether a surface is "ceiling" or not.
func is_on_ceiling() -> bool:
	return _is_on_ceiling


## Returns [code]true[/code] if the body collided only with the ceiling on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member neck_height] and [member ceiling_min_angle] are used
## to determine whether a surface is "ceiling" or not.
func is_on_ceiling_only() -> bool:
	return _is_on_ceiling and not (_is_on_floor or _is_on_wall)


## Returns [code]true[/code] if the body collided with the floor on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member up_direction], [member knee_height] and [member floor_max_angle] are used
## to determine whether a surface is "floor" or not.
func is_on_floor() -> bool:
	return _is_on_floor

## Returns [code]true[/code] if the body collided only with the floor on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member up_direction], [member knee_height] and [member floor_max_angle] are used
## to determine whether a surface is "floor" or not.
func is_on_floor_only() -> bool:
	return _is_on_floor and not (_is_on_ceiling or _is_on_wall)

## Returns [code]true[/code] if the body collided with the wall on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member knee_height] and [member neck_height] are used
## to determine whether a surface is "wall" or not.
func is_on_wall() -> bool:
	return _is_on_wall

## Returns [code]true[/code] if the body collided only with the wall on the last call of [method move_and_slide]. 
## Otherwise, returns [code]false[/code]. The [member knee_height] and [member neck_height] are used
## to determine whether a surface is "wall" or not.
func is_on_wall_only() -> bool:
	return _is_on_wall and not (_is_on_ceiling or _is_on_floor)


func _detect_environment() -> void:
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(get_rid())
	_platform_velocity = Vector3.ZERO
	_highest_floor_normal = Vector3.ZERO
	_is_on_floor = false
	_is_on_ceiling = false
	_is_on_wall = false
	
	for i in state.get_contact_count():
		var collider: Object = state.get_contact_collider_object(i)
		var contact_position: Vector3 = to_local(state.get_contact_local_position(i))
		var contact_normal: Vector3 = state.get_contact_local_normal(i)
		var contact_angle: float = acos(contact_normal.dot(up_direction))
		
		if _is_wall(contact_position, contact_angle):
			_is_on_wall = true
			continue
		
		if _is_ceiling(contact_position, contact_angle):
			_is_on_ceiling = true
			continue
		
		if _is_floor(contact_position, contact_angle):
			_is_on_floor = true
			
			if move_with_moving_platform and collider is AnimatableBody3D:
				_platform_velocity = PhysicsServer3D.body_get_state(collider.get_rid(), 
						PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
			
			if contact_normal.y > _highest_floor_normal.y:
				_highest_floor_normal = contact_normal
				
				if collider.physics_material_override:
					_floor_friction = collider.physics_material_override.friction
				else:
					_floor_friction = 1.0
			
			if not floor_stop_on_slope:
				continue
			
			_apply_floor_normal_force(contact_normal)


func _is_wall(contact_position: Vector3, contact_angle: float) -> bool:
	return (
			contact_position.y >= floor_knee_height
			and contact_position.y <= neck_height
			and contact_angle > floor_max_angle
			and contact_angle < ceiling_min_angle
	)


func _is_ceiling(contact_position: Vector3, contact_angle: float) -> bool:
	return contact_position.y >= neck_height and contact_angle >= ceiling_min_angle


func _is_floor(contact_position: Vector3, contact_angle: float) -> bool:
	return contact_position.y <= floor_knee_height and contact_angle <= floor_max_angle


func _apply_floor_normal_force(floor_normal: Vector3) -> void:
	apply_central_force(-get_gravity().length() * mass * Vector3.DOWN.slide(floor_normal))
