extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var global = root.get_node("Global")
	var debug = root.get_node("DebugOverlay")
	debug.infinite_health = true
	debug.damage_multiplier = 1.0
	var player = load("res://Player/Player.tscn").instantiate()
	scene.add_child(player)
	await create_timer(0.2).timeout
	for form in ["Player", "Ledi", "Legan", "Lyu"]:
		global.player = form
		player.transformation()
		for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			var bee = load("res://Enemies/Bee.tscn").instantiate()
			
			# Lyu fires a moving projectile; melee forms must also hit at body overlap.
			bee.position = direction * 15 + Vector2(0, 7) if form == "Lyu" else Vector2.ZERO
			scene.add_child(bee)
			bee.set_physics_process(false)
			player.animationTree.set("parameters/" + form + "Attack/blend_position", direction)
			await create_timer(0.5).timeout
			assert(is_equal_approx(bee.HEALTH, 3.0), "Contact without attacking must not damage enemies")
			var damage = player.swordHitbox.damage
			var hits = int(ceil(3.0 / damage))
			for hit in range(hits):
				player.state = player.ATTACK
				player.attack_state()
				await create_timer(0.7).timeout
				print(form, " direction ", direction, " hit ", hit + 1, " HP=", bee.HEALTH if is_instance_valid(bee) else "dead")
				if hit < hits - 1 and (not is_instance_valid(bee) or not is_equal_approx(bee.HEALTH, 3.0 - damage * (hit + 1))):
					push_error("Attack damage mismatch")
					quit(1)
					return
			if is_instance_valid(bee):
				push_error("Enemy did not die from overlapping melee attacks")
				quit(1)
				return

	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: enemies die after real attacks in all four directions")
	quit()
