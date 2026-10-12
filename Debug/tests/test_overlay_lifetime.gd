extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var overlay = root.get_node("DebugOverlay")
	for cycle in range(3):
		var scene = Node2D.new()
		root.add_child(scene)
		current_scene = scene
		for index in range(4):
			var transient = Node2D.new()
			scene.add_child(transient)
			transient.free()
		var enemy = load("res://Enemies/Bee.tscn").instantiate()
		scene.add_child(enemy)
		scene.free()
		await process_frame
		await process_frame
		overlay._process(0.2)
		assert(overlay.enemies.is_empty(), "Destroyed scene must leave no tracked enemies")
	print("PASS: immediate node deletion and rapid scene replacement")
	quit()
