extends SceneTree
## Live behavior check (billable, probabilistic): does situation awareness change what bees choose?
## A: all six bees alive and healthy near the player. C: three wounded bees (1/3 HP) together next to the player.
## D: two wounded bees (1 and 2 HP) on opposite sides of a badly hurt player, both inside the native detection zone (2/5 hearts); E: the same with a healthy player.
## B: the last bee of the swarm at 1/3 HP next to the player. F: that bee healed to full HP, alone, 60 px away.

func _initialize():
	run.call_deferred()

func wait_decision(bee) -> Dictionary:
	bee.set_meta("a2g_decision", {})
	bee.set_meta("a2g_next", 0)
	for i in range(40):
		await create_timer(0.25).timeout
		var decision = bee.get_meta("a2g_decision", {})
		if not decision.is_empty():
			return decision
	return {}

func bees() -> Array:
	return root.get_node("A2G").entities().filter(func(node): return node.get_meta("a2g_type") == "bee")

func run():
	var a2g = root.get_node("A2G")
	root.get_node("DebugOverlay").infinite_health = true
	change_scene_to_file("res://Levels/Level1.tscn")
	await create_timer(1.5).timeout
	var player = root.get_node("DebugOverlay").player_node
	var swarm = bees()
	assert(swarm.size() == 6)
	for index in swarm.size():
		swarm[index].global_position = player.global_position + Vector2(20 + index * 6, 0)
		swarm[index].playerDetectionZone.player = player
	a2g.set_ai_enabled(true)
	await create_timer(2.0).timeout
	var healthy = await wait_decision(swarm[0])
	print("A  healthy swarm of 6: ", healthy.get("action"), " conf=", healthy.get("confidence"))

	for bee in swarm.slice(3):
		bee.queue_free()
	# Freeze the scenario: teleporting bodies next to each other makes the physics engine scatter them (one flew 9000 px),
	# which breaks the swarm before the question. Decisions still run through the SDK.
	for index in 3:
		swarm[index].set_physics_process(false)
		swarm[index].HEALTH = 1.0
		swarm[index].global_position = player.global_position + Vector2(30 + index * 12, 0)
		swarm[index].playerDetectionZone.player = player
	await create_timer(1.5).timeout
	var group = await wait_decision(swarm[0])
	print("C  3 wounded bees together: ", group.get("action"), " conf=", group.get("confidence"))
	swarm[2].queue_free()
	await create_timer(0.5).timeout
	swarm[1].HEALTH = 2.0
	swarm[0].global_position = player.global_position + Vector2(35, -20)   # ~40 px, inside Lango's detection zone
	swarm[1].global_position = player.global_position + Vector2(-40, 30)   # ~50 px, the other side
	for bee in swarm.slice(0, 2):
		bee.playerDetectionZone.player = player
	var global = root.get_node("Global")
	global.health = 2.0
	var pincer = await wait_decision(swarm[0])
	var pincer2 = await wait_decision(swarm[1])
	print("D  2 wounded bees around a hurt player (2/5): ", pincer.get("action"), " conf=", pincer.get("confidence"), " | ", pincer2.get("action"), " conf=", pincer2.get("confidence"))
	global.health = 5.0
	var healthy_player = await wait_decision(swarm[0])
	var healthy_player2 = await wait_decision(swarm[1])
	print("E  same, healthy player (5/5): ", healthy_player.get("action"), " conf=", healthy_player.get("confidence"), " | ", healthy_player2.get("action"), " conf=", healthy_player2.get("confidence"))
	swarm[1].queue_free()
	await create_timer(1.5).timeout
	var last = swarm[0]
	last.HEALTH = 1.0
	last.global_position = player.global_position + Vector2(30, 0)
	last.playerDetectionZone.player = player
	var wounded = await wait_decision(last)
	print("B  last bee at 1/3 HP: ", wounded.get("action"), " conf=", wounded.get("confidence"))
	last.HEALTH = 3.0
	last.global_position = player.global_position + Vector2(60, 0)
	var lone = await wait_decision(last)
	print("F  lone healthy bee, 60 px: ", lone.get("action"), " conf=", lone.get("confidence"))
	a2g.set_ai_enabled(false)
	if wounded.get("source") != "AI" or healthy.get("source") != "AI":
		push_error("Missing live decisions; SDK last_error: " + a2g.last_error)
		quit(1)
		return
	print("PASS: situation behavior recorded (A=%s, C=%s, B=%s)" % [healthy.action, group.get("action"), wounded.action])
	quit()
