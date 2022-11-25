extends RigidBody2D

export (float) var radius = 30.0 setget set_radius
# Main molecule is the one controlled by the player
export (bool) var is_main = false

onready var shape = $Shape
onready var area_node = $Area
onready var area_shape = $Area/Shape
onready var mesh = $Mesh

# this is a hack for mobile
onready var cam = utils.get_main_node().get_node("cam")
onready var world = utils.get_main_node()
onready var dim = cam.get_viewport_rect().size

const MIN_PROPELLING_MASS = 0.0008
const MAX_PROPELLING_MASS = 0.0016
const SMALL_PROPELLING_FORCE = 150
const LARGE_PROPELLING_FORCE = 3
const COLOR_VECTOR_MIN = Color(1, 0.25, 0)
const COLOR_VECTOR_MAX = Color(0, 0.75, 1)

# Using RigidBody2D.mass has some undesired implications
var molecule_mass
var molecule_scene = load("res://scenes/Molecule.tscn")


func _ready():
	mesh.material = mesh.material.duplicate()
	mesh.material.set_shader_param("offset", randf())
	
	var world = utils.get_main_node()
	world.connect("touchTap", self, "_on_touchTap")
	
	shape.shape = CircleShape2D.new()
	area_shape.shape = CircleShape2D.new()
	if is_main:
		global.main_molecule = self
		set_radius(radius)
	else:
		global.connect("main_molecule_resized", self, "adjust_color")
		set_radius(radius)
		adjust_color()


func adjust_color() -> void:
	"""
	Changes color saturation depending on how much bigger or smaller
	the given molecule is compared to the main molecule
	"""
	var c = 1
	if global.main_molecule and global.main_molecule.radius > 0:
		c = self.radius / (global.main_molecule.radius * 2)
		c = clamp(c, 0, 1)
	var color_vector = COLOR_VECTOR_MIN * c + COLOR_VECTOR_MAX * (1 - c)
	mesh.material.set_shader_param("color", color_vector)


func set_radius(value):
	radius = value
	self.molecule_mass = _radius_to_mass(value)
	if is_inside_tree():
		shape.shape.radius = value
		area_shape.shape.radius = value
		var scale = value * 2
		mesh.scale = Vector2(scale, scale)
		
		if is_main:
			# TODO: improve resized signal
			global.emit_signal("main_molecule_resized")
	
	if radius <= 0:
		queue_free()
		if is_main:
			global.main_molecule = null


func _mass_to_radius(a: float) -> float:
	assert(a >= 0)
	return sqrt(a/PI)


func _radius_to_mass(r: float) -> float:
	assert(r >= 0)
	return PI * pow(r, 2)


func add_mass(added_mass: float, mass_linear_velocity: Vector2) -> void:
	"""
	Adds mass and changes the velocity depending on how much mass was added
	and how fast it was moving.
	"""
	if added_mass <= 0:
		return
	var new_mass = self.molecule_mass + added_mass
	var new_velocity = (
		self.linear_velocity * self.molecule_mass / new_mass +
		mass_linear_velocity * added_mass / new_mass
	)
	var new_radius = _mass_to_radius(new_mass)
	self.radius = new_radius
	self.linear_velocity = new_velocity


func _physics_process(_delta):
	pass
	#if is_main and Input.is_action_pressed("propel"):
	#	var p3 = event.position * dim
		#self.propel(p3 - self.position)
	#	self.propel(p3)
	#	print(p3)
		#self.propel(get_viewport().get_mouse_position() - self.position)

func _on_touchTap(event):
	#print('got it')
	if is_main:
		#var p3 = event.position * dim
		#print(self.position * dim)
		#print(p3)
		self.propel(event.relative)
	pass
	
func propel_me(_position):
	self.propel(_position - self.position)
	
#func _input(event):
#	#var label = Utils.get_main_node().get_node("HUD/uifb")
#	if is_main and event is InputEventScreenDrag:
#		var p3 = event.position * dim
#		self.propel(event.relative)
		#print(event.relative)

		#self.propel(get_viewport().get_mouse_position() - self.position)
		#print(event.relative)
#		pass

func _process(_delta):
	var overlapping_molecules = []
	for a in area_node.get_overlapping_areas():
		var molecule = a.get_parent()
		if molecule.radius < self.radius and molecule.radius >= 0:
			overlapping_molecules.append(molecule)
	
	for small in overlapping_molecules:
		var distance = self.position.distance_to(small.position)
		var radius_difference = self.radius + small.radius - distance
		# TODO: this should not happen, but it happens sometimes
		if radius_difference < 0:
			continue
		
		var small_radius_reduced = max(
			0, small.radius - radius_difference
		)
		
		var small_mass_reduced = _radius_to_mass(small_radius_reduced)
		var mass_delta = small.molecule_mass - small_mass_reduced
		
		small.radius = small_radius_reduced
		self.add_mass(mass_delta, small.linear_velocity)


func propel(direction: Vector2) -> void:
	if self.radius <= 0:
		return
	
	direction = direction.normalized()
	var propelling_mass = self.molecule_mass * rand_range(
		MIN_PROPELLING_MASS, MAX_PROPELLING_MASS
	)
	var new_mass = self.molecule_mass - propelling_mass
	
	self.radius = _mass_to_radius(new_mass)
	
	var propelling_molecule = molecule_scene.instance()
	propelling_molecule.radius = _mass_to_radius(propelling_mass)
	# TODO: use a constant here
	propelling_molecule.position = self.position + direction * (
		self.radius + propelling_molecule.radius + 5
	)
	
	propelling_molecule.apply_central_impulse(
		direction * SMALL_PROPELLING_FORCE
	)
	self.apply_central_impulse(
		-direction * LARGE_PROPELLING_FORCE
	)
	get_parent().call_deferred(
		"add_child_below_node", self, propelling_molecule
	)
