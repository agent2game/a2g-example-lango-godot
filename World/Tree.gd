extends StaticBody2D

@onready var Wood   = preload("res://World/Wood.tscn")
@onready var Winter = preload("res://World/WinterTree.png")

var cutted = false

func _ready():
	if get_parent().get_parent().get_parent().name == "Level4":
		$Sprite2D.texture = Winter

func _on_Area2D_area_entered(_area):
	if Global.axe_equipped == true:
		if _area.get_parent().get_parent().roll_vector.x < 0:
			_area.get_parent().get_parent().cut_left()
			await get_tree().create_timer(1.5).timeout
			drop()
		if _area.get_parent().get_parent().roll_vector.x > 0:
			_area.get_parent().get_parent().cut_right()
			await get_tree().create_timer(1.5).timeout
			drop()
		if _area.get_parent().get_parent().roll_vector.x == 0:
			pass
	else:
		pass

func drop():
	cutted = true
	$Sprite2D.frame = 1
	$Z_Index.monitoring = false
	$Area2D.monitoring = false
	for x in randf_range(0,5):
		var wood = Wood.instantiate()
		get_parent().add_child(wood)
		wood.global_position = global_position + Vector2(randf_range(-16,16),randf_range(-16,16))

func _on_Circles_body_entered(_body):
	if Global.axe_equipped == true:
		if cutted == false:
			if _body.roll_vector.x < 0:
				$Right.visible = true
				$Left.visible = false
			if _body.roll_vector.x > 0:
				$Right.visible = false
				$Left.visible = true
			if _body.roll_vector.x == 0:
				$Right.visible = true
				$Left.visible = true

func _on_Circles_body_exited(_body):
	$Left.visible = false
	$Right.visible = false
