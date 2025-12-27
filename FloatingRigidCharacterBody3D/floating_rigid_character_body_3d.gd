class_name FloatingRigidCharacterBody3D
extends RigidBody3D


@export var shape_cast: ShapeCast3D
@export var ride_spring_strength: float = 200.0
@export var ride_spring_damper: float = 15.0
@export var ride_height: float = 1.25
@export_group("Floor", "floor")
@export var floor_stop_on_slope: bool = true
@export var floor_constant_speed: bool = false
@export var floor_knee_height: float = 0.5
@export_range(0.0, 180, 1.0, "radians_as_degrees") var floor_max_angle: float = deg_to_rad(45.0)
@export var move_with_moving_platform: bool = true

var up_direction: Vector3 = Vector3.UP
var lateral_velocity: Vector3 = Vector3.ZERO:
	get:
		return Vector3(linear_velocity.x, 0.0, linear_velocity.z)
var target_velocity: Vector3 = Vector3.ZERO
var acceleration: float = 15.0


var _platform_velocity: Vector3 = Vector3.ZERO
var _floor_friction: float = 1.0
var _highest_floor_normal: Vector3 = Vector3.ZERO
var _is_on_floor: bool = false


func _ready() -> void:
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0


func detect_environment() -> void:
	_platform_velocity = Vector3.ZERO
	_highest_floor_normal = Vector3.ZERO
	_is_on_floor = false
	
	if not shape_cast.is_colliding():
		return
	
	for i in shape_cast.get_collision_count():
		var collider: Object = shape_cast.get_collider(i)
		var contact_position: Vector3 = to_local(shape_cast.get_collision_point(i))
		var contact_normal: Vector3 = shape_cast.get_collision_normal(i)
		var contact_angle: float = acos(contact_normal.dot(up_direction))
		
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


func try_float() -> void:
	if not shape_cast.is_colliding():
		return
	
	var closest_collision_point: Vector3 = shape_cast.get_collision_point(0)
	var closest_collision_distance: float = shape_cast.global_position.distance_to(
			closest_collision_point)
	
	for i in shape_cast.get_collision_count():
		var contact_position: Vector3 = to_local(shape_cast.get_collision_point(i))
		
		if contact_position.y >= floor_knee_height:
			continue
		
		var collision_point: Vector3 = shape_cast.get_collision_point(i)
		var collision_distance: float = shape_cast.global_position.distance_to(collision_point)
		
		if collision_distance < closest_collision_distance:
			closest_collision_point = collision_point
			closest_collision_distance = collision_distance
	
	var x: float = closest_collision_distance - ride_height
	
	var spring_force: float = -ride_spring_strength * x * mass
	var damping_force: float = -ride_spring_damper * Vector3.UP.dot(linear_velocity)
	
	apply_central_force((spring_force + damping_force) * up_direction)
	
	shape_cast.global_rotation = Vector3.ZERO


func move_and_slide() -> void:
	var move_force = Vector3.ZERO
	var drag_force = Vector3.ZERO
	var relative_velocity: Vector3
	
	if target_velocity != Vector3.ZERO:
		move_force = mass * acceleration * target_velocity.normalized() * _floor_friction
		move_force = modify_move_force(move_force)
		relative_velocity = lateral_velocity - _platform_velocity
		
		if _is_on_floor:
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


func is_on_floor():
	return _is_on_floor


func modify_move_force(move_force: Vector3) -> Vector3:
	return move_force


func modify_drag_force(drag_force: Vector3) -> Vector3:
	return drag_force


func _is_floor(contact_position: Vector3, contact_angle: float) -> bool:
	return contact_position.y <= floor_knee_height and contact_angle <= floor_max_angle
