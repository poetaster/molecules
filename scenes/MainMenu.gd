extends Control

signal request_new_level
signal request_music

var music_enabled = true

func _ready():
	set_process_input(true)
	var world = utils.get_main_node()
	world.connect("touchMtap", self, "_on_touchTap")

#func _input(_event):
#	if Input.is_action_just_pressed("dismiss"):
#		toggle_visibility()
#	if _event is InputEventScreenDrag:
#		toggle_visibility()

func _on_touchTap(event):
	_on_New_pressed()
	
func _on_Quit_pressed():
	get_tree().paused = false
	visible = false

	#toggle_visibility()
	#get_tree().quit()


func _on_Back_pressed():
	toggle_visibility()


func toggle_visibility():
	get_tree().paused = false
	visible = false
	#utils.get_main_node().get_node("MainMenu").hide()



func show_menu():
	visible = true
	get_tree().paused = true


func _on_New_pressed():
	visible = false
	get_tree().paused = false
	emit_signal("request_new_level")



func _on_Music_pressed():
	music_enabled = not music_enabled
	var text = "Music: On" if music_enabled else "Music: Off"
	#$VBoxContainer/Music.text = text
	emit_signal("request_music", music_enabled)


