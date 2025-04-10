## The settings for the character's movement and feel. 
## Attribution to Quality First Person Controller v2 by Zakarya
## with some modification.
extends CharacterBody3D

# TODO: Set the options on dedicated settings GDScript file

#region Character Export Group
@export_group("Movement")
## The speed that the character moves at basic speed.
@export var speed_base : float = 3.0
## The speed that the character moves at when sprinting.
@export var speed_sprint : float = 6.0
## The speed that the character moves at when crouching.
@export var speed_crouch : float = 1.0

## How fast the character speeds up and slows down when Motion Smoothing is on.
@export var acceleration : float = 10.0
## How high the player jumps.
@export var jump_velocity : float = 4.5
## How far the player turns when the mouse is moved.
@export var mouse_sensitivity : float = 0.1
## Invert the X axis input for the camera.
@export var invert_camera_x_axis : bool = false
## Invert the Y axis input for the camera.
@export var invert_camera_y_axis : bool = false
## Whether the player can use movement inputs. 
## Does not stop outside forces or jumping. See Jumping Enabled.
@export var immobile : bool = false
## The reticle file to import at runtime. 
## By default are in res://addons/fpc/reticles/.
## Set to an empty string to remove
@export_file var default_reticle
#endregion

#region Nodes Export Group
@export_group("Nodes")
## A reference to the camera for use in the character script.
## This is the parent node to the camera and is rotated 
## instead of the camera for mouse input.
@export var HEAD : Node3D
## A reference to the camera for use in the character script.
@export var CAMERA : Camera3D
## A reference to the headbob animation for use in the character script.
@export var HEADBOB_ANIMATION : AnimationPlayer
## A reference to the jump animation for use in the character script.
@export var JUMP_ANIMATION : AnimationPlayer
## A reference to the crouch animation for use in the character script.
@export var CROUCH_ANIMATION : AnimationPlayer
## A reference to the the player's collision shape
## for use in the character script.
@export var COLLISION_MESH : CollisionShape3D
#endregion

#region Controls Export Group
# We are using UI controls because they are built into Godot Engine
# so they can be used right away.
@export_group("Controls")
## Use the Input Map to map a mouse/keyboard input to an action
## and add a reference to it to this dictionary to be used in the script.
@export var controls : Dictionary = {
	LEFT = "ui_left",
	RIGHT = "ui_right",
	FORWARD = "ui_up",
	BACKWARD = "ui_down",
	JUMP = "ui_accept",
	CROUCH = "crouch",
	SPRINT = "sprint",
	PAUSE = "ui_cancel"
	}
@export_subgroup("Controller Specific")
## This only affects how the camera is handled, 
##the rest should be covered by adding controller inputs 
##to the existing actions in the Input Map.
@export var controller_support : bool = true
## Use the Input Map to map a controller input to an action 
## and add a reference to it to this dictionary to be used in the script.
@export var controller_controls : Dictionary = {
	LOOK_LEFT = "look_left",
	LOOK_RIGHT = "look_right",
	LOOK_UP = "look_up",
	LOOK_DOWN = "look_down"
	}
## The sensitivity of the analog stick that controls camera rotation. 
## Lower is less sensitive and higher is more sensitive.
@export_range(0.001, 1, 0.001) var look_sensitivity : float = 0.035
#endregion

#region Feature Settings Export Group
@export_group("Feature Settings")
## Enable or disable jumping. Useful for restrictive storytelling environments.
@export var jumping_enabled : bool = true
## Whether the player can move in the air or not.
@export var in_air_momentum : bool = true
## Smooths the feel of walking.
@export var motion_smoothing : bool = true
## Enables or disables sprinting.
@export var sprint_enabled : bool = true
## Toggles the sprinting state when button is pressed 
## or requires the player to hold the button down to remain sprinting.
@export_enum("Hold to Sprint", "Toggle Sprint") var sprint_mode : int = 0
## Enables or disables crouching.
@export var crouch_enabled : bool = true
## Toggles the crouch state when button is pressed 
## or requires the player to hold the button down to remain crouched.
@export_enum("Hold to Crouch", "Toggle Crouch") var crouch_mode : int = 0
## Wether sprinting should effect FOV.
@export var dynamic_fov : bool = true
## If the player holds down the jump button, should the player keep hopping.
@export var continuous_jumping : bool = true
## Enables the view bobbing animation.
@export var view_bobbing : bool = true
## Enables an immersive animation when the player jumps and hits the ground.
@export var jump_animation : bool = true
## This determines wether the player can use the pause button, 
## not wether the game will actually pause.
@export var pausing_enabled : bool = true
## Use with caution.
@export var gravity_enabled : bool = true
## If your game changes the gravity value during gameplay, 
## check this property to allow the player to experience the change in gravity.
@export var dynamic_gravity : bool = false
## To determines if the player can grab edges of the platform 
## for climbing over it (hasn't been used yet)
@export var ledge_grab : bool = true
# TODO: Think more ideas for variables
#endregion

#region Member Variable Initialization
# These are variables used in this script that 
# don't need to be exposed in the editor.
var speed : float = speed_base
var speed_current : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
# This is for when the ceiling is too low and the player needs to crouch.
var low_ceiling : bool = false 
# Was the player on the floor last frame (for landing animation)
var was_on_floor : bool = true 

# The reticle should always have a Control node as the root
var RETICLE : Control
# Stores mouse input for rotating the camera in the physics process
var mouseInput : Vector2 = Vector2(0,0)
# Get the gravity from the project settings to be synced with RigidBody nodes
# Don't set this as a const, see the gravity section in _physics_process
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity") 
#endregion

#region Main Control Flow
func _ready():
	# It is safe to comment this line if your game doesn't 
	# start with the mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# If the controller is rotated in a certain direction for game design 
	# purposes, redirect this rotation into the head.
	HEAD.rotation.y = rotation.y
	rotation.y = 0

	# Change the default recticle
	if default_reticle:
		change_reticle(default_reticle)

	# Initialize the condition for the first tick
	initialize_animations()
	check_controls()
	enter_normal_state()

# Handle pause
func _process(_delta):
	if pausing_enabled:
		handle_pausing()

	# For debug update, will be on another document
	#update_debug_menu_per_frame()

# Zakarya: Most things happen here
func _physics_process(delta): 
	# Gravity with its dynamics, now in Jolt Physics
	if dynamic_gravity:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Check if you are still floating mid-air
	if not is_on_floor() and gravity and gravity_enabled:
		velocity.y -= gravity * delta

	# To handle jumping, just like its name
	handle_jumping()

	# Initilize input diretion if nothing happened
	var input_dir = Vector2.ZERO
	
	# Zakarya: Immobility works by interrupting user input, 
	# so other forces can still be applied to the player
	if not immobile: 
		input_dir = Input.get_vector(
			controls.LEFT,
			controls.RIGHT,
			controls.FORWARD,
			controls.BACKWARD)

	# To handle movement
	handle_movement(delta, input_dir)

	# to handle head rotation, like from mouse input
	handle_head_rotation()

	# The player is not able to stand up if the ceiling is too low
	low_ceiling = $CrouchCeilingDetection.is_colliding()

	# Handling state
	handle_state(input_dir)
	
	# This may be changed to an AnimationPlayer
	if dynamic_fov: 
		update_camera_fov()
	if view_bobbing:
		play_headbob_animation(input_dir)
	if jump_animation:
		play_jump_animation()

	# Debug menu is for game settings later on
	#update_debug_menu_per_tick()

	# This must always be at the end of physics_process
	was_on_floor = is_on_floor() 
#endregion

#region Input Handling
## Using ChatGPT to simplify the code using extraction and inversion
## from: https://www.youtube.com/watch?v=CFRhGnuXG-4
## Uhh...
## Actually, I use the term to be used by ChatGPT
## https://chatgpt.com/share/67e1720e-7858-8002-ac7a-0532cc30ad43
## This is perhaps one of some tries that Corfliss tried to avoid vibe coding 
## but failed LUL
func handle_jumping():
	# Check for any negative state to jumping
	if not jumping_enabled or low_ceiling or not is_on_floor():
		return
	
	# Check for any positive state to jumping
	if Input.is_action_pressed(controls.JUMP) if continuous_jumping else \
		Input.is_action_just_pressed(controls.JUMP):
		if jump_animation:
			JUMP_ANIMATION.play("jump", 0.25)
		velocity.y += jump_velocity

func velocity_adjustment(delta, direction):
	if not motion_smoothing:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		return

	velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
	
func handle_movement(delta, input_dir):
	var direction = input_dir.rotated(-HEAD.rotation.y)
	direction = Vector3(direction.x, 0, direction.y)

	if is_on_floor() or not in_air_momentum:
		velocity_adjustment(delta, direction)

	move_and_slide()

func is_inverse(current_state: bool) -> int:
	return -1 if current_state else 1

func handle_head_rotation():
	HEAD.rotation_degrees.y -= mouseInput.x * \
		mouse_sensitivity * is_inverse(invert_camera_x_axis)
	HEAD.rotation_degrees.x -= mouseInput.y * \
		mouse_sensitivity * is_inverse(invert_camera_y_axis)

	if controller_support:
		var controller_view_rotation = Input.get_vector(
			controller_controls.LOOK_DOWN, 
			controller_controls.LOOK_UP, 
			controller_controls.LOOK_RIGHT, 
			controller_controls.LOOK_LEFT
		) * look_sensitivity

		HEAD.rotation.x += controller_view_rotation.x * \
			is_inverse(invert_camera_x_axis)
		HEAD.rotation.y += controller_view_rotation.y * \
			is_inverse(invert_camera_y_axis)

	mouseInput = Vector2(0,0)
	HEAD.rotation.x = clamp(HEAD.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func check_controls():
	var control_checks = {
		controls.JUMP: ["No control mapped for jumping. 
			Please add an input map control. Disabling jump.", 
			"jumping_enabled", false],
		controls.LEFT: ["No control mapped for move left. 
			Please add an input map control. Disabling movement.", 
			"immobile", true],
		controls.RIGHT: ["No control mapped for move right. 
			Please add an input map control. Disabling movement.", 
			"immobile", true],
		controls.FORWARD: ["No control mapped for move forward. 
			Please add an input map control. Disabling movement.", 
			"immobile", true],
		controls.BACKWARD: ["No control mapped for move backward. 
			Please add an input map control. Disabling movement.", 
			"immobile", true],
		controls.PAUSE: ["No control mapped for pause. 
			Please add an input map control. Disabling pausing.", 
			"pausing_enabled", false],
		controls.CROUCH: ["No control mapped for crouch. 
			Please add an input map control. Disabling crouching.", 
			"crouch_enabled", false],
		controls.SPRINT: ["No control mapped for sprint. 
			Please add an input map control. Disabling sprinting.", 
			"sprint_enabled", false]
	}

	# Check for error of input for each of the control input
	for action in control_checks:
		if not InputMap.has_action(action):
			# Error message
			push_error(control_checks[action][0])
			# Set property dynamically
			set(control_checks[action][1], control_checks[action][2])  
#endregion

#region State Handling
# Dang it, I have to use ChatGPT 
# because my mind can't comprehend the simplifaction technique
# https://chatgpt.com/share/67e1720e-7858-8002-ac7a-0532cc30ad43
func handle_state(moving):
	
	# Get the unhappy customer first, (check if the sprint and crouch enabled)
	if not sprint_enabled and not crouch_enabled:
		return
	
	# If sprint enabled...
	if sprint_enabled:
		# For changing from sprinting to normal
		if state == "sprinting" \
			and (not Input.is_action_pressed(controls.SPRINT) or not moving):
			return enter_normal_state()
		# For changing from normal to sprinting
		if Input.is_action_pressed(controls.SPRINT) and state == "normal":
			return enter_sprint_state()
		# Check what state is entered if moving and sprint is pressed
		if moving and Input.is_action_just_pressed(controls.SPRINT):
			return enter_sprint_state() if state == "normal" \
				else enter_normal_state()
			
	# If crouch enbaled
	if crouch_enabled:
		# Check if crouching and not hitting any ceiling
		if state == "crouching" and not $CrouchCeilingDetection.is_colliding():
			return enter_normal_state()
		# Check for crouching and not in sprint or even crouching itself
		if Input.is_action_pressed(controls.CROUCH) \
			and state not in ["sprinting", "crouching"]:
			return enter_crouch_state()
		# Check for crouch mode toggle
		if crouch_mode and Input.is_action_just_pressed(controls.CROUCH):
			return enter_crouch_state() if state == "normal" \
				else enter_normal_state()

# Helper function 1: normal state handler
func enter_normal_state():
	# Comments for printing debugging message
	#print("entering normal state")
	# Check the previous state
	var state_prev = state
	# If it is crouching, play crouch animation in backwards (read: standing)
	match state_prev:
		"crouching": CROUCH_ANIMATION.play_backwards("crouch")
	# State the normal state
	state = "normal"
	# Return speed to base value
	speed = speed_base

# Helper function 2: crouch state handler
func enter_crouch_state():
	# Comments for printing debugging message
	#print("entering crouch state")
	# Play crouch animation
	CROUCH_ANIMATION.play("crouch")
	# Turn the state into crouching
	state = "crouching"
	# Set the speed to crouching speed
	speed = speed_crouch
	
func enter_sprint_state():
	# Comments for printing debugging message
	#print("entering sprint state")
	# Check the previous state
	var state_prev= state
	# If it is crouching, play crouch animation in backwards (read: standing)
	match state_prev:
		"crouching": CROUCH_ANIMATION.play_backwards("crouch")
	# State the sprint state
	state = "sprinting"
	# Return speed to sprint value
	speed = speed_sprint
#endregion

#region Animation Handling
# Initialize animations
func initialize_animations():
	HEADBOB_ANIMATION.play("RESET")
	JUMP_ANIMATION.play("RESET")
	CROUCH_ANIMATION.play("RESET")

# Headbob animation
func play_headbob_animation(moving):
	# Check the negation condition for Headbob
	if not moving or not is_on_floor() \
		and HEADBOB_ANIMATION.current_animation in ["sprint", "walk"]:
		HEADBOB_ANIMATION.speed_scale = 1
		HEADBOB_ANIMATION.play("RESET", 1)
	
	# Initialize the string for which current headbob animation to play
	var use_headbob_animation : String
	
	# Assign the animation state with the regarded state
	match state:
		"normal", "crouching": use_headbob_animation = "walk"
		"sprinting": use_headbob_animation = "sprint"

	# Check for playing animation for the last tick
	var was_playing : bool = false
	if HEADBOB_ANIMATION.current_animation == use_headbob_animation:
		was_playing = true

	# Play the animation
	HEADBOB_ANIMATION.play(use_headbob_animation, 0.25)
	HEADBOB_ANIMATION.speed_scale = (speed_current / speed_base) * 1.75
	
	# Zakarya: Randomize the initial headbob direction
	if !was_playing:
		HEADBOB_ANIMATION.seek(float(randi() % 2)) 
		# Zakarya:
		# Let me explain that piece of code because it looks like it does the opposite of what it actually does.
		# The headbob animation has two starting positions. One is at 0 and the other is at 1.
		# randi() % 2 returns either 0 or 1, and so the animation randomly starts at one of the starting positions.
		# This code is extremely performant but it makes no sense.

# Jumpa animation
func play_jump_animation():
	# Zakarya: The player just landed
	if !was_on_floor and is_on_floor(): 
		var facing_direction : Vector3 = CAMERA.get_global_transform().basis.x
		var facing_direction_2D : Vector2 = Vector2(
			facing_direction.x, 
			facing_direction.z
			).normalized()
		var velocity_2D : Vector2 = Vector2(velocity.x, velocity.z).normalized()

		# Zakarya: Compares velocity direction against 
		# the camera direction (via dot product) 
		# to determine which landing animation to play.
		var side_landed : int = round(velocity_2D.dot(facing_direction_2D))

		# Land side condition
		# TODO: Make it more analogue?
		match sign(side_landed):
			1: JUMP_ANIMATION.play("land_right", 0.25)
			-1: JUMP_ANIMATION.play("land_left", 0.25)
			0: JUMP_ANIMATION.play("land_center", 0.25)
#endregion

#region Misc Function
# Zakarya: Yup, this function is kinda strange
func change_reticle(reticle): 
	if RETICLE:
		RETICLE.queue_free()

	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	$UserInterface.add_child(RETICLE)

# Update camera FOV
func update_camera_fov():
	CAMERA.fov = lerp(CAMERA.fov, 75.0 if state != "sprinting" else 85.0, 0.3)

# And another ChatGPT Help for simplifaction
# https://chatgpt.com/share/67e1720e-7858-8002-ac7a-0532cc30ad43
func handle_pausing():
	if not Input.is_action_just_pressed(controls.PAUSE):
		return
	
	var mode_map = {
		Input.MOUSE_MODE_CAPTURED: Input.MOUSE_MODE_VISIBLE,
		Input.MOUSE_MODE_VISIBLE: Input.MOUSE_MODE_CAPTURED
	}
	
	Input.mouse_mode = mode_map.get(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	#get_tree().paused = false
#endregion
