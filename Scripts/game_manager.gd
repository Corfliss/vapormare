extends Node3D

#region Nodes Export Group
@export_group("Nodes")
## For instantiating the blue enemies to spawn
@export var enemy_blue : PackedScene
## For getting the level nodes
@export var level : Node3D
## Character to be played with
@export var character : CharacterBody3D
#endregion

#region Dynamic Parameters Export
@export_group("Variables")
## How long (in seconds) we wait between spawns
@export var spawn_interval : float = 1.0
## Caps the number of enemies appearing at once
## We don't want a performance issue
@export var max_enemies : int = 10000
## Maximum attempts to find a valid spawn position
@export var max_spawn_attempts : int = 10
## Minimum range to spawn the enemies
@export var spawn_minimum_range : float = 7.5
## Maximum play time
@export var difficulty_ramp_duration : float = 60.0
## For starting spawn interval_start
@export var spawn_interval_start : float = 2.0
## For what is the fastest spawn time
@export var spawn_interval_min : float = 0.1
#endregion

#region Member Variables Initialization
## Non-exposed spawn timer tracker
var spawn_timer : float = 0.0
## Non-exposed track on how many enemies are there
var enemy_count : int = 0
# Non-exposed ground radius to get
var ground_radius : int = 0
# Camera to get
var camera : Camera3D
# Game time duration
var game_time : float = 0.0

#endregion

func _ready() -> void:
	ground_radius = level.get_node("Ground").radius
	camera = character.get_node("Head/Camera")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Calculate the spawn and game time
	spawn_timer += _delta
	game_time += _delta
	
	# Calculate interpolated spawn interval
	var t = clamp(game_time/difficulty_ramp_duration, 0.0, 1.0)
	spawn_interval = lerp(spawn_interval_start, spawn_interval_min, t)
	
	# Check if enough time has passed and under the maximum enemy cap
	if spawn_timer >= spawn_interval and enemy_count < max_enemies:
		# spawn an enemy within view
		var spawn_success : bool = spawn_enemy_visible()
		
		if spawn_success:
			spawn_timer = 0.0
			enemy_count += 1

# Spawn enemy in visible camera location without getting too close
func spawn_enemy_visible() -> bool:
	# Check if the camera exists of the character exists
	# Might sacrifice modularity
	if camera == null:
		push_warning("Camera not set in spawner.")
		return false
	
	# Check the spawn attempts
	for i in max_spawn_attempts:
		# Get a random angle
		var angle = randf() * TAU
		
		# Get the proper pseudorandomization of the distance to spawn
		var distance = randf_range(spawn_minimum_range, ground_radius - 2.0)
		
		# Convert polar coordinates (angle, distance) into a 3D position
		# on the XZ plan
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = global_transform.origin + local_pos
		
		# Cast ray downward the spawn point, ensuring on the ground spawn
		var ray_params = PhysicsRayQueryParameters3D.new()
		ray_params.from = world_pos + Vector3.UP * 10
		ray_params.to = world_pos + Vector3.DOWN * 10
		

		# Shoots a ray downward to detect if there's something (ground) beneath.
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(ray_params)
		
		# If result of detection exists
		if result and "position" in result:
			# converts a 3D point into a 2D position on camera
			var screen_pos = camera.unproject_position(result.position)
			
			# This is going too many nests, and I will going bananas
			
			# To check if the spawn point is in the camera view 
			if screen_pos.x > 0 and screen_pos.x < camera.get_viewport().size.x and \
				screen_pos.y > 0 and screen_pos.y < camera.get_viewport().size.y:
				
				# Spawn the enemy
				var enemy = enemy_blue.instantiate()
				enemy.transform.origin = result.position
				add_child(enemy)
				return true
	
	# And return false if it is not exists
	return false
	
# TODO: Optimization pattern for better performance
func hurt_character(amount: int):
	if character and character.is_inside_tree():
		character.take_damage(amount)
