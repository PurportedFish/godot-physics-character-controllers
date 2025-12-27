# RigidCharacterBody3D Class
A character controller class for Godot 4.5 similar to the CharacterBody3D class except moved through force and impulse application.
The class script includes:
 * Full documentation
 * Floor, wall, and ceiling detection
 * Slope handling
 * AnimatableBody3D handling
 * A basic floor snapping implementation
# FloatinRigidCharacterBody3D Class (Based on Toyful Games' Very Very Valet Character Controller)
A character controller class for Godot 4.5 similar to the CharacterBody3D class except moved through force and impulse application. It floats using a spring force based on a ShapeCast3D's collisions.
The class script includes:
 * Slope/small obstacle (e.g. stairs) handling
 * AnimatableBody3D handling
# The project includes:
 * A test range (textured using Kenney's Prototype Textures) for each character controller class
## Notes
 * The code does not particularly use anything specific from Godot 4.5, so it is possible to use the class for earlier versions.
 * The project uses Jolt
## TODO
 * Stair handling (Might not puruse)
 * More work on FRCB3D
