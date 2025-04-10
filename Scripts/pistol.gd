extends Node3D

func shoot(hit_info: Dictionary):
	if hit_info.has("collider"):
		print("Pistol hit:", hit_info.collider.name)
