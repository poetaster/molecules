extends Node2D

onready var molecules = $Molecules
onready var main_menu = $MainMenu
onready var message_label = $Message/Label
onready var messages = $Message/Label2
onready var music = $Music

var molecule_scene = load("res://scenes/Molecule.tscn")
var screen_size = Vector2(
	ProjectSettings.get("display/window/size/width"),
	ProjectSettings.get("display/window/size/height")
)
var total_molecule_mass = 0
var main_molecule
var next_level = false

signal touchTap
signal touchMtap


# this is a hack for mobile
onready var cam = utils.get_main_node().get_node("cam")
onready var dim = cam.get_viewport_rect().size

func _ready():
	set_process_input(true)
	# Pause the game for tutorial
	#get_tree().paused = true
	randomize()
	main_menu.connect("request_new_level", self, "generate_molecules")
	main_menu.connect("request_music", self, "_on_request_music")
	global.connect("main_molecule_resized", self, "_on_main_molecule_resized")
	generate_molecules()
	for molecule in molecules.get_children():
		total_molecule_mass += molecule.molecule_mass
	# In tutorial, ensure that the biggest molecule has to be absorbed too
	#total_molecule_mass *= 1.5


func _input(event):
	if (event is InputEventMultiScreenDrag or
		event is InputEventMultiScreenSwipe or
		event is InputEventMultiScreenLongPress or
		event is InputEventSingleScreenTap or
		event is InputEventSingleScreenLongPress or
		event is InputEventSingleScreenTouch or
		event is InputEventSingleScreenSwipe):
			pass
			#messages.text = event.as_text().replace('|','\n')
			#emit_signal('touchTap', event)
	# Unpause the game in tutorial
	# TODO: figure out a cleaner way to check if this is tutorial
	if len(message_label.text) > 8:
		if Input.is_action_just_pressed("dismiss"):
			messages.text = ""
			main_menu.hide()
			get_tree().paused = false
	if event is InputEventMultiScreenTap:
		#messages.text = "Multitap"
		emit_signal('touchMtap', event)
	if event is InputEventSingleScreenDrag:
		#messages.text = "Singldrag"
		emit_signal('touchTap', event)
		#main_molecule.propel(event.relative)
		#print("ha")
		


func generate_molecules():
	next_level = false
	total_molecule_mass = 0
	message_label.text = ""
	
	for molecule in molecules.get_children():
		molecules.remove_child(molecule)
		molecule.queue_free()
	
	main_molecule = molecule_scene.instance()
	main_molecule.is_main = true
	main_molecule.position = screen_size * 0.5
	
	var placeholder_molecules = _generate_placeholder_molecules(main_molecule)
	for pm in placeholder_molecules:
		var molecule = molecule_scene.instance()
		molecule.position = pm[0]
		molecules.add_child(molecule)
		molecule.radius = float(pm[1])
		total_molecule_mass += molecule.molecule_mass
	
	molecules.add_child(main_molecule)
	total_molecule_mass += main_molecule.molecule_mass
	yield(utils.create_timer(2), "timeout")
	next_level = true

	


func _generate_placeholder_molecules(main_molecule):
	var generated_molecules = []
	# Add the main molecule, so it can be avoided
	generated_molecules.append([main_molecule.position, main_molecule.radius])
	
	for radius in range(71, 4, -1):
		var molecule = _generate_single_molecule(radius, generated_molecules)
		generated_molecules.append(molecule)
	
	# Remove the main molecule
	generated_molecules.pop_front()
	return generated_molecules


func _generate_single_molecule(radius, existing_molecules) -> Array:
	"""
	Generates a single molecule with the given radius, making sure
	that it doesn't overlap the existing ones. Results are returned
	as [position, radius]
	"""
	var position = null
	var found = false
	while not found:
		found = true
		var rand_x = rand_range(radius, screen_size.x - radius)
		var rand_y = rand_range(radius, screen_size.y - radius)
		position = Vector2(rand_x, rand_y)
		for molecule in existing_molecules:
			if position.distance_to(molecule[0]) <= radius + molecule[1]:
				found = false
				break
	return [position, radius]


func _on_main_molecule_resized() -> void:
	#print(total_molecule_mass - global.main_molecule.molecule_mass)
	if global.main_molecule.radius <= 0:
			messages.text = "You lost"
			yield(utils.create_timer(1), "timeout")
			messages.text = ""
			#get_tree().paused = false
			#$MainMenu.show_menu()
			next_level = false
			generate_molecules()

	else:
		if global.main_molecule.molecule_mass > total_molecule_mass * 0.5:
			if next_level:
				next_level = false
				messages.text = "You won!"
				yield(utils.create_timer(2), "timeout")
				#get_tree().paused = false
				#$MainMenu.show_menu()
				global.main_molecule.molecule_mass = 0
				messages.text = ""
				generate_molecules()
				



func _on_request_music(enabled: bool) -> void:
	music.stream_paused = not enabled



