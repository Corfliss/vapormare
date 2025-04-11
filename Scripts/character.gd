## The settings for the character's movement and feel. 
## Attribution to Quality First Person Controller v2 by Zakarya
## COPYRIGHT Colormatic Studios
## MIT license
## Quality Godot First Person Controller v2
## 
## (With some modification)
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
## Handles how fast you are flying:
@export var fly_speed : float = 7.0
### How fast to propel upwards when ledge-grabbing
#@export var ledge_grab_speed : float = 3.0
### How fast to propel forward after almost reaching over the ledge
#@export var ledge_forward_speed : float = 2.0
@export var max_health : int = 100
## The reticle file to import at runtime. 
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
## The collection of weapons used in the game
@export var WEAPONS : Node3D
## For health bar
@export var health_bar : ProgressBar
## To detect the ledge using raycast on the head
@export var HEAD_RAYCAST : Node3D
## To detect the ledge using raycast on the leg
@export var LEG_RAYCAST : Node3D
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
	PAUSE = "ui_cancel",
	SWITCH_RIGHT = "switch_right",
	SWITCH_LEFT = "switch_left",
	SHOOT = "shoot"
	}
@export_subgroup("Controller Specific")
## This only affects how the camera is handled, 
##the rest should be covered by adding controller inputs 
##to the existing actions in the Input Map.
@export var controller_support : bool = true
## Use the Input Map to map a controller input to an action 
## and add a reference to it to this dictionary to be used in the script.
@export var controller_controls : Dictionary = {
	LOOK_LEFT = "ui_left",
	LOOK_RIGHT = "ui_right",
	LOOK_UP = "ui_up",
	LOOK_DOWN = "ui_down"
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
## To enable a weapon switch or not
@export var weapon_switch : bool = true
## Flags for flying mechanics
@export var is_flying : bool = true
## Whether or not if you can shoot the gun
@export var can_shoot : bool = true
#endregion

#region Member Variable Initialization
# These are variables used in this script that 
# don't need to be exposed in the editor.
enum Weapons {PISTOL, SHOTGUN, RIFLE}
var speed : float = speed_base
var speed_current : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
# for initiating the max health
var current_health : int = max_health
# This is for when the ceiling is too low and the player needs to crouch.
var low_ceiling : bool = false 
# Was the player on the floor last frame (for landing animation)
var was_on_floor : bool = true
# Checking the state of the ledge_grab
#var is_grabbing : bool = false
#var is_climbing : bool = false
# For weapon switching using tween and input queue
var tween_weapon_running : bool = false
var weapon_input_queue: Array[int] = []
var weapon_state : int = Weapons.PISTOL
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
	
	 #Change the default recticle
	if default_reticle:
		change_reticle(default_reticle)

	# Initialize the condition for the first tick
	initialize_animations()
	check_controls()
	enter_normal_state()
	update_weapon_visibility(weapon_state)
	update_health_ui()
	
# Handle pause
func _process(_delta):
	if pausing_enabled:
		handle_pausing()

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

	# Uncomment this part for ledge grab	
	#handle_ledge_grab()

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

	# To handle flying
	handle_flying(delta)
	
	# To handle head rotation, like from mouse input
	handle_head_rotation()
	
	# To handle weapon switch
	handle_weapons_switch()

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
	
	# Move and slide at the end, as always
	move_and_slide()
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
	if not jumping_enabled:
		return

	var jump_pressed = false
	if continuous_jumping:
		jump_pressed = Input.is_action_pressed(controls.JUMP)
	else:
		jump_pressed = Input.is_action_just_pressed(controls.JUMP)

	if jump_pressed and is_on_floor() and not low_ceiling:
		if jump_animation:
			JUMP_ANIMATION.play("jump", 0.25)
		# I don't know why, but if I don't divide the velocity it will remain the same
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

	if in_air_momentum or is_on_floor():
		velocity_adjustment(delta, direction)

func is_inverse(current_state: bool) -> int:
	return -1 if current_state else 1

func handle_head_rotation():
	# Horizontal look (Yaw)
	HEAD.rotation_degrees.y -= mouseInput.x * mouse_sensitivity * is_inverse(invert_camera_x_axis)

	# Vertical look (Pitch) with clamping
	HEAD.rotation_degrees.x = clamp(
		HEAD.rotation_degrees.x - mouseInput.y * mouse_sensitivity * is_inverse(invert_camera_y_axis),
		-90,
		90
	)

	# Controller support (optional)
	if controller_support:
		var controller_view_rotation = Input.get_vector(
			controller_controls.LOOK_DOWN, 
			controller_controls.LOOK_UP, 
			controller_controls.LOOK_RIGHT, 
			controller_controls.LOOK_LEFT
		) * look_sensitivity

		HEAD.rotation_degrees.x = clamp(HEAD.rotation_degrees.x + controller_view_rotation.x * is_inverse(invert_camera_y_axis), -90, 90)
		HEAD.rotation_degrees.y += controller_view_rotation.y * is_inverse(invert_camera_x_axis)

	# Reset mouse input after applying it
	mouseInput = Vector2.ZERO

func update_weapon_visibility(current_state):
	for i in range(WEAPONS.get_child_count()):
		WEAPONS.get_child(i).visible = (i == current_state)
		
func rotate_weapon_wheel():
	if tween_weapon_running:
		return  # Prevent new tween from starting

	tween_weapon_running = true
	
	var target_rotation = deg_to_rad(120) * weapon_state

	# Force rotation to be set from clean base (no drift)
	WEAPONS.rotation.x = target_rotation - deg_to_rad(120)

	# Create a fresh tween each time
	var tween := create_tween()
	
	tween.tween_property(
		WEAPONS, "rotation:x", target_rotation, 0.15
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# TODO: Fix this stuff from triple/quadruple or even a lot of input buffer
	# I have to connect to a dedicated function for input buffer
	tween.finished.connect(
		func():
		tween_weapon_running = false
		if not weapon_input_queue.is_empty():
			var next_direction = weapon_input_queue.pop_front()
			weapon_state = (weapon_state + next_direction + 3) % 3
			update_weapon_visibility(weapon_state)
			rotate_weapon_wheel()
	)

func handle_weapons_switch():
	if not weapon_switch:
		return
	if Input.is_action_just_pressed(controls.SWITCH_RIGHT):
		weapon_state = (weapon_state + 1) % 3
		rotate_weapon_wheel()  # Pass previous state
		update_weapon_visibility(weapon_state)

	elif Input.is_action_just_pressed(controls.SWITCH_LEFT):
		weapon_state = (weapon_state - 1 + 3) % 3
		rotate_weapon_wheel()  # Pass previous state
		update_weapon_visibility(weapon_state)

func handle_flying(delta):
	if not is_flying:
		return

	# Smooth vertical flying
	var vertical_input := 0.0
	if Input.is_action_pressed(controls.JUMP):
		vertical_input = 1.0
	elif Input.is_action_pressed(controls.CROUCH):
		vertical_input = -1.0

	velocity.y = lerp(velocity.y, vertical_input * speed, acceleration * delta)

# TODO: Do this later, or not
#func handle_ledge_grab():
	#
	#if not ledge_grab or not Input.is_action_just_pressed("ui_accept") or not HEAD_RAYCAST.is_colliding():
		#return
		#
	#while true:
		#if not LEG_RAYCAST.is_colliding():
			#velocity.y = ledge_grab_speed
		#elif LEG_RAYCAST.is_colliding():
			#velocity.y = ledge_grab_speed * 0.5
			#velocity.z = ledge_forward_speed
		#else:
			#velocity = Vector3.ZERO
			#break  # Stop the function when ledge grab is complete
#
	#move_and_slide()

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
			"sprint_enabled", false],
		controls.SWITCH_RIGHT: ["No control mapped for switch right 
			Please add an input map control. Disabling weapon switch.", 
			"weapon_switch", false],
		controls.SWITCH_LEFT: ["No control mapped for switch left
			Please add an input map control. Disabling weapon switch.", 
			"weapon_switch", false],
		controls.SHOOT: ["No control mapped for shoot 
			Please add an input map control. Disabling shooting.", 
			"can_shoot", false]
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
	if not sprint_enabled and not crouch_enabled:
		return

	# --- Sprinting ---
	if sprint_enabled:
		var sprint_pressed = Input.is_action_pressed(controls.SPRINT)
		var sprint_just_pressed = Input.is_action_just_pressed(controls.SPRINT)

		if state == "sprinting" and (not sprint_pressed or not moving):
			return enter_normal_state()

		if sprint_mode == 0:
			if sprint_pressed and state != "crouching" and moving and state != "sprinting":
				return enter_sprint_state()

		if sprint_mode == 1:
			if moving and sprint_pressed and state == "normal":
				return enter_sprint_state()
			if moving and sprint_just_pressed:
				return enter_sprint_state() if state == "normal" else enter_normal_state()

	# --- Crouching ---
	if crouch_enabled:
		var crouch_pressed = Input.is_action_pressed(controls.CROUCH)
		var crouch_just_pressed = Input.is_action_just_pressed(controls.CROUCH)
		var can_uncrouch = not $CrouchCeilingDetection.is_colliding()

		# Hold-to-crouch
		if crouch_mode == 0:
			# Crouch when button is pressed
			if crouch_pressed and state == "normal":
				return enter_crouch_state()
			# Uncrouch when button is released AND currently crouching AND can uncrouch
			if not crouch_pressed and state == "crouching" and can_uncrouch:
				return enter_normal_state()

		# Toggle crouch
		if crouch_mode == 1 and crouch_just_pressed:
			if state == "normal":
				return enter_crouch_state()
			if state == "crouching" and can_uncrouch:
				return enter_normal_state()

# Helper function 1: normal state handler
func enter_normal_state():
	#print("entering normal state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "normal"
	speed = speed_base

# Helper function 2: crouch state handler
func enter_crouch_state():
	#print("entering crouch state")
	state = "crouching"
	speed = speed_crouch
	CROUCH_ANIMATION.play("crouch")
	
func enter_sprint_state():
	#print("entering sprint state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "sprinting"
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

	RETICLE.set_anchors_preset(Control.PRESET_CENTER)
	$Reticle.add_child(RETICLE)

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

func _input(event):
	if event.is_action_pressed(controls.SHOOT) and weapon_state == Weapons.PISTOL:
		$Head/Weapons/WeaponPistol.shoot()

func _unhandled_input(event : InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseInput.x += event.relative.x
		mouseInput.y += event.relative.y
#endregion

#region Health
func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	update_health_ui()
	if current_health == 0:
		die()
		
func update_health_ui() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die():
	print("Character is dead")
	# Play death animation, respawn, etc.
	get_tree().quit()
#endregion
