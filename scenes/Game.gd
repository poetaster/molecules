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
var wins = 0
var played = 0
var player
var best

signal touchTap
signal touchMtap


# this is a hack for mobile
onready var cam = utils.get_main_node().get_node("cam")
onready var dim = cam.get_viewport_rect().size

func _ready():
	set_process_input(true)
	# retrieve highscore
	player = load_data('user://player.res')
	if player.high_score > wins:
				best = player.high_score
	#game.connect("score_best_changed", self, "_on_score_best_changed")
	# set_number(game.score_best)
	print(player.high_score)
	
	randomize()
	main_menu.connect("request_new_level", self, "generate_molecules")
	main_menu.connect("request_music", self, "_on_request_music")
	global.connect("main_molecule_resized", self, "_on_main_molecule_resized")
	generate_molecules()
	for molecule in molecules.get_children():
		total_molecule_mass += molecule.molecule_mass
	# In tutorial, ensure that the biggest molecule has to be absorbed too
	#total_molecule_mass *= 1.5
	next_level = true


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
		
		# we add some random motion the larger the
		# main molecule gets. we limit selection
		# to the number of wins.
		randomize()
		if wins > 3:
			# select a random molecule
			var rMolecule = molecules.get_child(randi()% wins)
			if not rMolecule.is_main:
				# a small delay so that main move
				# and the other molecules aren't contemporary
				rMolecule.propel(Vector2(rand_range(-1,1), rand_range(-1, 1)))
		#main_molecule.propel(event.relative)
		


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

	if global.main_molecule.radius <= 0:
			messages.text = "You lost"
			played+=1
			save_score()
			yield(utils.create_timer(1), "timeout")
			messages.text = ""
			#get_tree().paused = false
			#$MainMenu.show_menu()
			next_level = false
			generate_molecules()

	else:
		if global.main_molecule.molecule_mass > total_molecule_mass * 0.5:
			if next_level:
				#get_tree().paused = false
				#$MainMenu.show_menu()
				next_level = false
				# increase the wins register
				# to start adding some random motion.
				wins+=1
				played+=1
				save_score()
				messages.set_text(str("You won! ", wins, " of ", played))
				yield(utils.create_timer(2), "timeout")
				player = load_data('user://player.res')
				if player.high_score > 0:
					messages.set_text(str("Best: ", player.high_score, " of ", player.played))
					yield(utils.create_timer(2), "timeout")
				
				global.main_molecule.molecule_mass = 0
				messages.text = ""
				generate_molecules()
				

func _on_request_music(enabled: bool) -> void:
	music.stream_paused = not enabled

# score saving logic
func _on_score_best_changed():
		player = load_data('user://player.res')
		if player.high_score > best:
			best = player.high_score
		else:
			save_score()
				
func save_score():
# we save state on this transition
	var player = load_data('user://player.res')
	var current_score = float(wins*100/played)
	var highest = float(player.high_score*100 /player.played)
	if ( current_score >= highest and played > player.played ) or player.high_score == 0:
		print("write")
		player.high_score = wins
		player.played = played
		var result = ResourceSaver.save('user://player.res', player)
		#print(result)
		assert(result == OK)

func load_data(file_name):
	if ResourceLoader.exists(file_name):
		var player = ResourceLoader.load(file_name)
		if player is Player: # Check that the data is valid
			return player
	else:
		#print("now")
		return Player.new()
