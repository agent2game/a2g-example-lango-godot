extends ColorRect

func _ready():
	Global.get_node("ControlsHint").hide()  # the intro shows its own controls screen

func _process(_delta):
	$AnimationPlayer.speed_scale = 8.0 if Input.is_key_pressed(KEY_SPACE) else 1.0

func _on_AnimationPlayer_animation_finished(_anim_name):
	Global.get_node("ControlsHint").show()
# warning-ignore:return_value_discarded
	get_tree().call_deferred("change_scene_to_file", "res://UI/FirstMenu.tscn")
	Global.play_music()
