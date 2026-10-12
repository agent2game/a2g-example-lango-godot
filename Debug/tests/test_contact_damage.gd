extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = load("res://Player/Player.tscn").instantiate()
	var bee = load("res://Enemies/Bee.tscn").instantiate()
	scene.add_child(player)
	scene.add_child(bee)
	bee.set_physics_process(false)
	root.get_node("DebugOverlay").infinite_health = true
	root.get_node("DebugOverlay").damage_multiplier = 0.1
	await create_timer(0.8).timeout
	print("Idle contact: bee HP=", bee.HEALTH, " sword Ledi disabled=", player.swordHitbox.get_node("Ledi").disabled)
	if not is_equal_approx(bee.HEALTH, 3.0):
		push_error("Idle contact damaged enemy without an attack")
		quit(1)
		return
	# The default attack faces down; place the bee's elevated hurtbox in its arc.
	bee.position = Vector2(0, 22)
	player.animationTree.set("parameters/PlayerAttack/blend_position", Vector2.DOWN)
	await physics_frame
	player.state = player.ATTACK
	player.attack_state()
	await create_timer(0.65).timeout
	print("After attack: bee HP=", bee.HEALTH)
	if not bee.HEALTH < 3.0:
		push_error("Actual attack failed to damage overlapping enemy")
		quit(1)
		return
	var after_attack = bee.HEALTH
	await create_timer(0.8).timeout
	if not is_equal_approx(bee.HEALTH, after_attack):
		push_error("Damage continued after attack ended")
		quit(1)
		return
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("PASS: idle contact does no damage, actual attack damages enemy, damage stops after attack")
	quit()
