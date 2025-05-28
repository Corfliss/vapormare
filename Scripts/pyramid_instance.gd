extends CharacterBody3D

var player : Node3D = null
var mesh_instance: MeshInstance3D
@onready var pistol = get_node("/root/Level/Character/Head/Weapons/WeaponPistol")
@export var speed : float = 4.0
@onready var sfx = $AudioStreamPlayer3D

func _ready():
	print(pistol)
	pistol.connect("mesh_destroy", Callable(self, "_on_enemy_destroyed"))
	$Area3D.body_entered.connect(_on_body_entered)
	create_pyramid_mesh()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	

func create_pyramid_mesh():
	var pyramid = ArrayMesh.new()
	var arrays = []

	# Properly use PackedVector3Array
	var verts := PackedVector3Array([
		Vector3(0, 2, 0),         # Top
		Vector3(-1, 0, -1),   # Base
		Vector3(1, 0, -1),
		Vector3(1, 0, 1),
		Vector3(-1, 0, 1),
	])

	# Also needs to be PackedInt32Array
	var indices := PackedInt32Array([
		0, 1, 2, # Side 1
		0, 2, 3, # Side 2
		0, 3, 4, # Side 3
		0, 4, 1, # Side 4
		1, 2, 3, # Base triangle 1
		1, 3, 4  # Base triangle 2
	])

	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices

	pyramid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4444EE")
	material.emission_enabled = true
	material.emission = Color("4444EE") * 1.5     # Glow color boosted
	mesh_instance.material_override = material
	mesh_instance.mesh = pyramid
	add_child(mesh_instance)

func _physics_process(_delta):
	var direction = (player.global_transform.origin - global_transform.origin).normalized()
	direction.y = 0  # stay on the ground
	velocity = direction * speed
	move_and_slide()

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Character touched the pyramid!")
		body.take_damage(10)  # If your character has a take_damage function

func _on_enemy_destroyed(hit: Node3D):
	if hit == self:  # Make sure it's the pyramid being hit
		if mesh_instance:
			remove_child(mesh_instance)
	sfx.play(0.1)
