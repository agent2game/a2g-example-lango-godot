extends Control

var already_paused
var selected_menu

func change_menu_color():
	$Resume.color              = Color.GRAY
	$Restart.color             = Color.GRAY
	$Save.color                = Color.GRAY
	$Load.color                = Color.GRAY
	$MusicOn.color             = Color.GRAY
	$MusicOff.color            = Color.GRAY
	$ShowCredits.color         = Color.GRAY

	match selected_menu:
		0:
			$Resume.color      = Color.GREEN_YELLOW
		1:
			$Restart.color     = Color.GREEN_YELLOW
		2:
			$Save.color        = Color.GREEN_YELLOW
		3:
			$Load.color        = Color.GREEN_YELLOW
		4:
			$MusicOn.color     = Color.GREEN_YELLOW
		5:
			$MusicOff.color    = Color.GREEN_YELLOW
		6:
			$ShowCredits.color = Color.GREEN_YELLOW

func resume_restart_quit():
	match selected_menu:

		0:
			# Resume game
			if not already_paused:
				get_tree().paused = false
			$Save/Label.text      = "SAVE"
			hide()

		1:
			# Restart game
			get_tree().paused     = false
			Global.reset()

		2:
			#Save game
			Global.save_game()
			$Save/Label.text      = "SAVED"

		3:
			#Load game
			Global.load_game()

		4:
			#Music On
			Global.play_music()

		5:
			#Music On
			Global.stop_music()

		6:
			#Show Credits
# warning-ignore:return_value_discarded
			get_tree().call_deferred("change_scene_to_file", "res://UI/Credits.tscn")

func _input(_event):
	if not visible:
		if Input.is_action_just_pressed("ui_menu"):
			# Pause game
			already_paused      = get_tree().paused
			get_tree().paused   = true
			# Reset the popup
			selected_menu       = 0
			change_menu_color()
			# Show popup
			show()
	else:
		if Input.is_action_just_pressed("ui_menu"):
			# Resume game
			if not already_paused:
				get_tree().paused = false
			$Save/Label.text      = "SAVE"
			hide()
		if Input.is_action_just_pressed("ui_down"):
			selected_menu = (selected_menu + 1) % 7;
			change_menu_color()
		elif Input.is_action_just_pressed("ui_up"):
			if selected_menu > 0:
				selected_menu = selected_menu - 1
			else:
				selected_menu = 6
			change_menu_color()
		elif Input.is_action_just_pressed("ui_attack"):
			resume_restart_quit()
		elif _event is InputEventKey:
			if _event.keycode == KEY_ENTER:
				resume_restart_quit()
