extends Node3D

@onready var aim_raycast: RayCast3D = %AimRayCast
signal mesh_destroy(hit: Node3D)

func shoot():
	if aim_raycast.is_colliding():
		var hit = aim_raycast.get_collider()
		print("Hit object:", hit.name)
		
		if hit.is_in_group("enemy"):
			dying(hit)

			
func dying(hit: Node3D):
	var particle: GPUParticles3D = hit.get_child(2)
	if particle:
		particle.emitting = true

	if hit:
		hit.get_child(0).visible = false
		hit.get_child(1).visible = false
		emit_signal("mesh_destroy", hit)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	hit.add_child(timer)  # Add timer to scene tree so it works
	timer.start()
	
	timer.timeout.connect(func():
		hit.queue_free()
	)
	
	
