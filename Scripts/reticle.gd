extends CenterContainer


@export_category("Reticle")
@export_group("Nodes")
@export var character : CharacterBody3D

@export_group("Settings")
@export var dot_size : int = 1
@export var dot_color : Color = Color.WHITE


func _process(_delta):
	if visible: # If the reticle is disabled (not visible), don't bother updating it
		update_reticle_settings()

func update_reticle_settings():
	$Dot.scale.x = dot_size
	$Dot.scale.y = dot_size
	$Dot.color = dot_color
