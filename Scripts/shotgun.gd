extends Node3D

## How many pellets to be shot
@export var pellet_count := 10

@export var max_distance := 100.0
@export var spread_angle := 5.0 # degrees
@onready var aim_raycast : RayCast3D = $AimRaycast

func _ready():
	if not aim_raycast:
		push_error("AimRaycast node is missing!")

func _input(event):
	if event.is_action_pressed("shoot"):
		shoot()

func shoot():
	var origin = $AimRaycast.global_transform.origin
	var base_dir = $AimRaycast.global_transform.basis.z.normalized()

	for i in pellet_count:
		var spread_dir = get_spread_direction(base_dir, spread_angle)
		var target = origin + spread_dir * max_distance

		var params = PhysicsRayQueryParameters3D.create(origin, target)
		var result = get_world_3d().direct_space_state.intersect_ray(params)

		if result:
			print("Pellet hit: ", result.collider.name)

func get_spread_direction(base: Vector3, angle_deg: float) -> Vector3:
	var angle_rad = deg_to_rad(angle_deg)
	var random_rotation = Basis()
	random_rotation = random_rotation.rotated(Vector3.RIGHT, randf_range(-angle_rad, angle_rad))
	random_rotation = random_rotation.rotated(Vector3.UP, randf_range(-angle_rad, angle_rad))
	return (random_rotation * base).normalized()
