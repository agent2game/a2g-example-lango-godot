extends SceneTree
## Offline checks of the generic A2G client with the Lango adapter. Add --live to also make one billable Decisions call.

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	var a2g = root.get_node("A2G")
	var lango = root.get_node("LangoA2G")
	var scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = load("res://Player/Player.tscn").instantiate()
	var bat = load("res://Enemies/Bat.tscn").instantiate()
	player.position = Vector2(1000, 1000)
	scene.add_child(player)
	scene.add_child(bat)
	await process_frame
	await process_frame
	assert(bat.get_meta("a2g_type") == "bat" and bat in a2g.entities(), "Enemy registered through the Lango adapter")
	assert(lango.legal_actions(bat) == ["idle", "wander"], "Unseen player allows only idle/wander")
	a2g.set_physics_process(false)
	a2g.set_ai_enabled(true)
	bat.playerDetectionZone.player = player
	assert(lango.legal_actions(bat).has("flee"))
	var observation = lango.observe(bat)
	assert(observation.hp_fraction == 1.0 and observation.sees_player)
	var fresh = func(action): return {"source": "AI", "action": action, "decision_id": "d_test", "ttl_ms": 12000, "received_at": Time.get_ticks_msec(), "start_observation": lango.observe(bat), "start_world": a2g.world()}

	bat.set_meta("a2g_decision", fresh.call("flee"))
	assert(a2g.execute(bat, 0.1))
	assert(bat.state == 3)
	assert(bat.velocity.dot(player.global_position - bat.global_position) < 0, "FLEE moves away from the player")
	bat.playerDetectionZone.player = null
	assert(a2g.execute(bat, 0.1))
	assert(bat.state == 0 and bat.get_meta("a2g_decision").blocked, "Lost target turns flee into idle and marks it blocked")
	player.global_position = bat.global_position + Vector2(100, 0)
	assert(not lango.legal_actions(bat).has("chase"), "Without native detection the player is unknown, however close")
	player.global_position = Vector2(1000, 1000)
	bat.playerDetectionZone.player = player
	root.get_node("Global").repellent = true
	bat.set_meta("a2g_decision", fresh.call("chase"))
	assert(a2g.execute(bat, 0.1))
	assert(bat.state == 0, "Repellent blocks chasing")
	root.get_node("Global").repellent = false

	var expired = fresh.call("flee")
	expired.received_at -= 13000
	bat.set_meta("a2g_decision", expired)
	bat.state = 3
	assert(not a2g.execute(bat, 0.1), "Expired decisions return control to the native FSM")
	assert(bat.state == 0 and expired.reported, "Native control releases FLEE and reports the expired decision")

	var batch = [{"id": str(bat.get_instance_id()), "type": "bat", "observation": lango.observe(bat), "legal_actions": ["idle", "wander"]}]
	a2g.inflight = 1
	a2g._on_decisions(200, {"epoch": a2g.epoch, "decisions": [{"id": batch[0].id, "source": "AI", "action": "chase", "decision_id": "d_1"}]}, batch, a2g.epoch, Time.get_ticks_msec())
	assert(bat.get_meta("a2g_decision").source == "FALLBACK", "Actions outside the requested legal set cannot execute")
	bat.set_meta("a2g_decision", {})
	a2g._on_decisions(200, {"epoch": a2g.epoch - 1, "decisions": [{"id": batch[0].id, "source": "AI", "action": "idle", "decision_id": "d_2"}]}, batch, a2g.epoch - 1, Time.get_ticks_msec())
	assert(bat.get_meta("a2g_decision").is_empty(), "Replies from a previous epoch are ignored")
	a2g._on_decisions(200, {"epoch": a2g.epoch, "decisions": [{"id": batch[0].id, "source": "AI", "action": "wander", "decision_id": "d_3"}]}, batch, a2g.epoch, Time.get_ticks_msec())
	assert(bat.get_meta("a2g_decision").source == "AI" and bat.get_meta("a2g_decision").ttl_ms == 12000, "Missing ttl_ms defaults to 12 s")
	a2g._on_decisions(200, {"epoch": a2g.epoch, "decisions": [{"id": batch[0].id, "source": "AI", "action": "wander"}]}, batch, a2g.epoch, Time.get_ticks_msec())
	assert(bat.get_meta("a2g_decision").source == "FALLBACK", "AI decisions without decision_id are not executed")
	a2g._on_decisions(200, {"epoch": a2g.epoch, "decisions": [{"id": batch[0].id, "source": "FALLBACK", "code": "budget", "reason": "Too long"}]}, batch, a2g.epoch, Time.get_ticks_msec())
	assert(bat.get_meta("a2g_decision").code == "budget", "Fallback code is kept for the overlay and telemetry")
	a2g._on_decisions(200, {"epoch": a2g.epoch, "decisions": [{"id": batch[0].id, "source": "AI", "action": "wander", "label": "Patrol", "confidence": 0.7, "ttl_ms": 5000, "decision_id": "d_4", "cached": true}]}, batch, a2g.epoch, Time.get_ticks_msec())
	var decision = bat.get_meta("a2g_decision")
	assert(decision.source == "AI" and decision.ttl_ms == 5000 and decision.cached and decision.decision_id == "d_4" and a2g.is_fresh(decision), "Valid reply is applied with TTL, decision_id and cached flag")

	# Events, groups and profiles reach the decide request.
	lango.trigger(bat)  # remember the current state
	bat.HEALTH -= 1.0
	assert(lango.trigger(bat) == "hit", "HP loss is the hit event")
	bat.playerDetectionZone.player = null
	assert(lango.trigger(bat) == "player_lost")
	bat.playerDetectionZone.player = player
	assert(lango.trigger(bat) == "player_spotted")
	assert(lango.trigger(bat) == "", "No event without a change")
	var friends = []
	for offset in [Vector2(10, 0), Vector2(-10, 0)]:
		var friend = load("res://Enemies/Bat.tscn").instantiate()
		scene.add_child(friend)
		friend.set_physics_process(false)
		friend.global_position = bat.global_position + offset
		friends.append(friend)
	await process_frame
	assert(lango.trigger(bat) == "allies_gathered", "Two allies arriving is the allies_gathered event")
	for friend in friends:
		friend.queue_free()
	await process_frame
	lango.trigger(bat)
	a2g.set_parent(bat, "squad-1")
	bat.set_meta("a2g_trigger", "hit")
	var request = a2g._decide_entity(bat)
	assert(request.parent == "squad-1" and request.trigger == "hit" and request.observation.has("allies_near") and request.has("position"))
	bat.remove_meta("a2g_trigger")
	a2g.set_parent(bat, null)

	# Protocol errors: 403 stops asking, 429 backs off for Retry-After, 409 reopens the session.
	a2g.session_ready = true
	a2g._handle_status(409, {"error": "Unknown session"}, PackedStringArray())
	assert(not a2g.session_ready)
	a2g._handle_status(429, {"error": "Slow down"}, PackedStringArray(["Retry-After: 7"]))
	assert(a2g.backoff_until > Time.get_ticks_msec() + 6000)
	a2g._handle_status(403, {"error": "Unregistered manifest"}, PackedStringArray())
	assert(a2g.forbidden)
	a2g.forbidden = false
	a2g.backoff_until = 0
	assert(a2g.inflight == 0)

	a2g.session_ready = true
	bat.set_meta("a2g_next", 0)
	paused = true
	a2g._physics_process(1.0)
	assert(a2g.inflight == 0 and not bat.get_meta("a2g_pending"), "A paused game requests no decisions")
	paused = false
	a2g.session_ready = false

	bat.state = 3
	a2g.set_ai_enabled(false)
	assert(bat.state == 0 and bat.get_meta("a2g_decision").is_empty())
	assert(not a2g.execute(bat, 0.1))

	if "--live" in OS.get_cmdline_user_args():
		a2g.set_physics_process(true)
		a2g.set_ai_enabled(true)
		bat.HEALTH = 1.0
		await create_timer(6.0).timeout
		decision = bat.get_meta("a2g_decision", {})
		print("Live decision: ", decision.get("source"), " ", decision.get("action"), " ", decision.get("confidence"))
		if decision.get("source") != "AI":
			push_error("Live Decisions request did not return AI: " + str(decision))
			quit(1)
			return
		assert(bat.state == lango.ACTIONS.find(decision.action) or decision.get("blocked", false), "Live action is executed by Godot")
		a2g.set_ai_enabled(false)
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: adapter registration, legal actions, flee/blocked/expired, epoch and legal-set validation, mode reset")
	quit()
