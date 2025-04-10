extends PanelContainer

var character = null

func _ready():
	await get_tree().process_frame  # Wait for one frame to ensure the level is loaded
	character = get_tree().get_first_node_in_group("player")

func _process(_delta):
	update_debug_menu_per_frame()
	update_debug_menu_per_tick()

func add_property(title : String, value, order : int): # This can either be called once for a static property or called every frame for a dynamic property
	var target
	target = $MarginContainer/VBoxContainer.find_child(title, true, false) # I have no idea what true and false does here, the function should be more specific
	if !target:
		target = Label.new() # Debug lines are of type Label
		$MarginContainer/VBoxContainer.add_child(target)
		target.name = title
		target.text = title + ": " + str(value)
	elif visible:
		target.text = title + ": " + str(value)
		$MarginContainer/VBoxContainer.move_child(target, order)

#region Debug Menu
func update_debug_menu_per_frame():
	if not character:
		add_property("State", "No Character Found", 4)
		return

	add_property("FPS", Performance.get_monitor(Performance.TIME_FPS), 0)
	var status : String = character.state
	if !character.is_on_floor():
		status += " in the air"
	add_property("State", status, 4)


func update_debug_menu_per_tick():
	if not character:
		return
	# Big thanks to github.com/LorenzoAncora for the concept of the improved debug values
	character.speed_current = Vector3.ZERO.distance_to(character.get_real_velocity())
	add_property("Speed", snappedf(character.speed_current, 0.001), 1)
	add_property("Target speed", character.speed, 2)
	var cv : Vector3 = character.get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001)
	]
	var readable_velocity : String = "X: " + str(vd[0]) + " Y: " + str(vd[1]) + " Z: " + str(vd[2])
	add_property("Velocity", readable_velocity, 3)
