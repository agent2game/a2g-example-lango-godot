extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	change_scene_to_file("res://Levels/Level1.tscn")
	await process_frame
	await process_frame
	await create_timer(1.5).timeout
	print("Preview: scene ready")
	root.get_node("A2G").set_ai_enabled(true)
	await create_timer(4.0).timeout
	print("Preview: AI replies ready")
	paused = true
	var overlay = root.get_node("DebugOverlay")
	overlay.labels_toggle.button_pressed = true
	overlay.god_mode_button.button_pressed = true
	overlay.damage_spin.value = 0.1
	var key = InputEventKey.new()
	key.physical_keycode = KEY_QUOTELEFT
	key.pressed = true
	overlay._input(key)
	overlay._process(0.2)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/lango-debug-overlay.png")
	overlay._input(key)
	overlay._process(0.2)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/lango-labels-panel-closed.png")
	print("Saved /tmp/lango-debug-overlay.png")
	quit()
