extends SceneTree
## Live check (billable Decisions calls): Godot → A2G service session, telemetry, batched decisions, memory and reports.

func _initialize():
	run.call_deferred()

func fetch_client():
	var request = HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(request)
	request.request("http://127.0.0.1:8787/api/clients/" + root.get_node("A2G").client_id)
	var response = await request.request_completed
	request.queue_free()
	assert(response[1] == 200)
	return JSON.parse_string(response[3].get_string_from_utf8())

func run():
	var a2g = root.get_node("A2G")
	change_scene_to_file("res://Levels/Level1.tscn")
	await process_frame
	await process_frame
	paused = true
	await create_timer(4.5).timeout
	var snapshot = await fetch_client()
	assert(snapshot.telemetry.mode == "native")
	assert(snapshot.telemetry.paused)
	assert(snapshot.telemetry.entities.filter(func(e): return e.type != "player").size() == 6)
	assert(snapshot.telemetry.entities.any(func(e): return e.type == "player" and e.has("position")), "Player is reported as an observe-only entity with a position")
	assert(snapshot.manifest.entity_types.has("bee"), "Session sent the game manifest")
	assert(snapshot.telemetry.world.has("player_hp_fraction"))
	assert(snapshot.telemetry.entities[0].fields.has("hp_fraction"))
	print("PASS: paused native client registered with manifest, world, six creatures and the player")
	paused = false
	root.get_node("DebugOverlay").infinite_health = true
	a2g.set_ai_enabled(true)
	await create_timer(12.0).timeout
	snapshot = await fetch_client()
	assert(snapshot.telemetry.mode == "ai")
	assert(snapshot.stats.ai > 0)
	assert(snapshot.stats.questions > snapshot.stats.batches, "Several entities share one provider batch")
	assert(snapshot.logs.any(func(log): return log.kind == "request"))
	assert(snapshot.logs.any(func(log): return log.kind == "decision"))
	assert(not snapshot.memory.is_empty(), "Entity memory is recorded")
	assert(snapshot.population.bee.alive == 6, "Service computes population per type")
	assert(snapshot.context.values().any(func(c): return c.get("nearby") is Array and c.get("input_tokens", 0) > 0), "Service records nearby entities and token estimates per request")
	assert(snapshot.manifest_hash.begins_with("sha256:"), "Session returned a manifest hash")
	assert(snapshot.telemetry.get("scope") == "overworld", "Lango reports the active scope")
	print("PASS: live batched AI decisions (%d questions in %d batches), memory for %d entities, %d reports" % [snapshot.stats.questions, snapshot.stats.batches, snapshot.memory.size(), snapshot.stats.reports])
	a2g.set_ai_enabled(false)
	await create_timer(2.0).timeout
	snapshot = await fetch_client()
	assert(snapshot.telemetry.mode == "native")
	assert(snapshot.stats.pending == 0)
	print("PASS: mode switch reported and pending requests settled")
	quit()
