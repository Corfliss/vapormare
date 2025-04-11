extends Node3D

@onready var aim_raycast: RayCast3D = %AimRayCast

func shoot():
	if aim_raycast.is_colliding():
		var hit = aim_raycast.get_collider()
		print("Hit object:", hit.name)
		
		if hit.is_in_group("enemy"):
			hit.queue_free()
