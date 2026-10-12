extends Node2D

var VC = preload("res://UI/VirtualControl.tscn")
var selected_menu = 0

func change_menu_color():
	$New.color = Color.GRAY
	$Load.color = Color.GRAY
	$Quit.color = Color.GRAY
	
	match selected_menu:
		0:
			$New.color = Color.GREEN_YELLOW
		1:
			$Load.color = Color.GREEN_YELLOW
		2:
			$Quit.color = Color.GREEN_YELLOW

func _ready():
	change_menu_color()
#	var canvas = CanvasLayer.new()
#	add_child(canvas)
	var control = VC.instantiate()
	add_child(control)

func _input(_event):
	if Input.is_action_just_pressed("ui_down"):
		selected_menu = (selected_menu + 1) % 3;
		change_menu_color()
	elif Input.is_action_just_pressed("ui_up"):
		if selected_menu > 0:
			selected_menu = selected_menu - 1
		else:
			selected_menu = 2
		change_menu_color()

	elif Input.is_action_just_pressed("ui_attack") or Input.is_action_just_pressed("ui_accept"):
		match selected_menu:
			0:
				# New game
# warning-ignore:return_value_discarded
				get_tree().call_deferred("change_scene_to_file", "res://Levels/InsideHouse.tscn")
			1:
				# Load game
				Global.load_game()
			2:
				# Quit game
				get_tree().quit()
