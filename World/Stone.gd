extends Sprite2D

func _on_Area2D_body_entered(_body):
	Global.stone += 1
	$AudioStreamPlayer.play()
	await $AudioStreamPlayer.finished
	queue_free()

func _on_Timer_timeout():
	queue_free()
