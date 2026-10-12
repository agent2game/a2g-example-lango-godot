extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var overlay = root.get_node("DebugOverlay")
	assert(not overlay.enabled)
	assert(not overlay.show_labels and not overlay.show_offscreen)
	var scene = Node2D.new()
	scene.name = "OverlayTest"
	root.add_child(scene)
	current_scene = scene
	var bat = load("res://Enemies/Bat.tscn").instantiate()
	scene.add_child(bat)
	await process_frame
	await process_frame
	var entry = overlay.enemies[bat.get_instance_id()]
	assert(entry.max_health == 6, "Capture scene-specific maximum HP")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_QUOTELEFT
	key.pressed = true
	overlay._input(key)
	assert(overlay.enabled and overlay.panel.visible)
	overlay.labels_toggle.button_pressed = true
	overlay.offscreen_toggle.button_pressed = true
	bat.HEALTH = 2
	bat.state = 2
	overlay._process(0.2)
	assert(entry.marker.text.contains("HP 2.00/6.00"))
	assert(entry.row.text.contains("CHASE"))
	assert(overlay.summary.text.contains("Bats: 1"))
	assert(entry.marker.text.contains("[color=#ff758f][b]CHASE"))
	bat.position = Vector2(10000, 10000)
	overlay._process(0.2)
	assert(entry.marker_box.visible, "Offscreen enemies still have a card")
	assert(entry.marker.text.contains("OUTSIDE VIEW"))
	overlay.offscreen_toggle.button_pressed = false
	overlay._process(0.2)
	assert(not entry.marker_box.visible and not entry.row.visible, "Offscreen checkbox filters labels and list")
	overlay.offscreen_toggle.button_pressed = true
	overlay._process(0.2)
	assert(entry.marker.text.contains("FSM"))
	assert(entry.marker_box.get_theme_stylebox("panel").bg_color.a > 0.0)
	var other_level = Node2D.new()
	root.add_child(other_level)
	var outside_enemy = load("res://Enemies/Bee.tscn").instantiate()
	other_level.add_child(outside_enemy)
	await process_frame
	await process_frame
	overlay._process(0.2)
	assert(not overlay.enemies[outside_enemy.get_instance_id()].marker_box.visible)
	assert(not overlay.enemies[outside_enemy.get_instance_id()].row.visible)
	assert(overlay.summary.text.contains("Bees: 0"), "Only current-level enemies are counted")
	other_level.queue_free()
	await process_frame
	key.echo = true
	overlay._input(key)
	assert(overlay.enabled, "Holding the key must not toggle repeatedly")
	key.echo = false
	paused = true
	overlay._input(key)
	assert(not overlay.enabled and not overlay.panel.visible)
	overlay._process(0.2)
	assert(entry.marker_box.visible, "Labels remain visible with debug panel closed")
	overlay.labels_toggle.button_pressed = false
	overlay._process(0.2)
	assert(not entry.marker_box.visible)
	overlay.labels_toggle.button_pressed = true
	paused = false
	bat.queue_free()
	await process_frame
	await process_frame
	overlay._process(0.2)
	assert(overlay.enemies.is_empty(), "Remove labels for freed enemies")
	scene.queue_free()
	await process_frame
	var next_scene = Node2D.new()
	next_scene.name = "NextLevel"
	root.add_child(next_scene)
	current_scene = next_scene
	var bee = load("res://Enemies/Bee.tscn").instantiate()
	next_scene.add_child(bee)
	await process_frame
	await process_frame
	overlay._input(key)
	root.get_node("Global").health = 3
	overlay._process(0.2)
	assert(overlay.enemies.size() == 1)
	assert(overlay.enemies[bee.get_instance_id()].max_health == 3)
	assert(overlay.summary.text.contains("Scene: NextLevel"))
	assert(overlay.summary.text.contains("Player HP: 3.00/5.00"))
	next_scene.queue_free()
	print("PASS: HP, states, counts, toggle, key repeat, pause, enemy cleanup")
	quit()
