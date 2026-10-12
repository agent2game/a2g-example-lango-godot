extends Area2D

const EDGE_INSET = 8  # trigger band = 16px strip along the screen edge

func _ready():
	# Exits sit just past the camera limits, so the player had to walk off-screen
	# blind. Pull the trigger onto the visible edge and mark it with an arrow.
	var cam = get_parent().get_node_or_null("Camera2D")
	if cam == null:
		return
	var rect = Rect2(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)
	if rect.has_point(position):
		return
	var outward = Vector2(sign(position.x - clamp(position.x, rect.position.x, rect.end.x)),
						  sign(position.y - clamp(position.y, rect.position.y, rect.end.y)))
	position = position.clamp(rect.position + Vector2.ONE * EDGE_INSET, rect.end - Vector2.ONE * EDGE_INSET)
	var shape = $CollisionShape2D.shape.duplicate()
	shape.size = Vector2(shape.size.x * 2.5, EDGE_INSET * 2)  # wider and thicker, no need to aim
	$CollisionShape2D.shape = shape
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(0, 3)])
	arrow.color = Color(0.1, 0.1, 0.1, 0.7)
	arrow.z_index = 10
	add_child(arrow)
	arrow.global_rotation = outward.angle() - PI / 2
	arrow.global_position = global_position - outward * 2
	var tween = arrow.create_tween().set_loops()
	tween.tween_property(arrow, "modulate:a", 0.2, 0.6)
	tween.tween_property(arrow, "modulate:a", 1.0, 0.6)

# warning-ignore:unused_argument
func _on_Entrace_body_entered(body):
	if body.state == body.TRANSITION:  # walking in from this exit
		return
	Global.direction = body.roll_vector
	Global.from = get_parent().name
	#print("Came from " + Global.from, " and go to " + Global.from + "Pos" + " on " + self.name + " Level")
# warning-ignore:return_value_discarded
	get_tree().call_deferred("change_scene_to_file", ("res://Levels/") + (self.name) + (".tscn"))
