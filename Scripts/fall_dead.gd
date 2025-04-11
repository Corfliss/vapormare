extends Area3D

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Character touched the pyramid!")
		body.take_damage(100)  # If your character has a take_damage function
