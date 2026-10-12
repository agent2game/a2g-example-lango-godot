extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var overlay = root.get_node("DebugOverlay")
	var global = root.get_node("Global")
	var scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = load("res://Player/Player.tscn").instantiate()
	var bee = load("res://Enemies/Bee.tscn").instantiate()
	player.position = Vector2(1000, 1000)
	scene.add_child(player)
	scene.add_child(bee)
	await process_frame
	await process_frame
	var sword = player.swordHitbox
	sword.damage = 1
	overlay.damage_spin.value = 0.1
	assert(is_equal_approx(overlay.damage_multiplier, 0.1))
	bee._on_HurtBox_area_entered(sword)
	assert(is_equal_approx(bee.HEALTH, 2.9), "Fractional enemy damage")
	assert(is_equal_approx(bee.bar.size.x, bee.initial_bar_width * 2.9 / 3.0))
	player._on_HurtBox_area_entered(bee.get_node("HitBox"))
	assert(is_equal_approx(global.health, 4.9), "Fractional player damage")
	overlay.god_mode_button.button_pressed = true
	assert(overlay.infinite_health)
	player._on_HurtBox_area_entered(bee.get_node("HitBox"))
	assert(is_equal_approx(global.health, 4.9), "God mode blocks damage")
	overlay.god_mode_button.button_pressed = false
	player._on_HurtBox_area_entered(bee.get_node("HitBox"))
	assert(is_equal_approx(global.health, 4.8), "Disabling god mode restores damage")
	global.health += 1
	assert(is_equal_approx(global.health, 5.0), "Fractional healing must not exceed maximum HP")
	for hit in range(29):
		bee._on_HurtBox_area_entered(sword)
	assert(bee.dead and bee.is_queued_for_deletion(), "Repeated fractional hits must reach death")
	var bat = load("res://Enemies/Bat.tscn").instantiate()
	scene.add_child(bat)
	await process_frame
	overlay.damage_spin.value = 1.0
	sword.damage = 2
	bat._on_HurtBox_area_entered(sword)
	assert(is_equal_approx(bat.HEALTH, 4.0), "Normal multiplier preserves weapon damage")
	await create_timer(1.0).timeout
	scene.queue_free()
	await process_frame
	print("PASS: fractional damage, HP bar, god mode on/off, fractional death, normal weapon damage")
	quit()
