extends ColorRect

func _ready():
	get_tree().paused = false
	$AnimationPlayer.play("Credits")
	await $AnimationPlayer.animation_finished
# warning-ignore:return_value_discarded
	Global.reset()
	

