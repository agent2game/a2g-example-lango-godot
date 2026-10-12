extends Node
## Lango-specific A2G glue (autoload "LangoA2G"): the only code a game developer writes to plug a game into A2G.
## Observations, legal actions, events, scopes and execution for bees, bats and bosses; behavior lives in a2g_manifest.json.

const ACTIONS = ["idle", "wander", "chase", "flee"]  # index == enemy.state; 3 (FLEE) exists only under A2G control
const STATES = ["IDLE", "WANDER", "CHASE", "FLEE"]
const ALLY_RADIUS = 120.0
# The adapter reports what the game knows: perception of the player is Lango's native detection zone, unchanged.
# Behavior belongs in the manifest; bending the game's rules to help the model would change the game.
const AWARE_RADIUS = 140.0  # only for counting allies fighting the player (allies_near_player)
const BOSS_ARENA = {"parent": "dungeon", "text": "The queen's throne room: a closed arena with no exit until the boss dies. She keeps spawning bees that defend her.", "fields": {"boss_phase": [1, 2, 3]}}

## Observe-only adapter for the player: never decided, but visible to creatures (position, health, what it is doing).
class PlayerAdapter:
	const STATES = ["move", "roll", "attack", "transition"]

	func observe(player) -> Dictionary:
		return {"hp_fraction": snappedf(Global.health / Global.max_health, 0.001), "action": STATES[player.state] if player.state >= 0 and player.state < STATES.size() else "move"}

	func legal_actions(_player) -> Array:
		return []

	func state(player) -> String:
		return observe(player).action.to_upper()

	func position(player) -> Vector2:
		return player.global_position

func _ready():
	A2G.world_provider = world
	A2G.scope_provider = scope
	for type in ["bee", "bat", "boss"]:
		A2G.register_adapter(type, self)
	A2G.register_adapter("player", PlayerAdapter.new())
	get_tree().node_added.connect(_on_node_added)
	# A main scene given on the command line can be in the tree before this autoload subscribes.
	(func(): for node in get_tree().root.find_children("*", "CharacterBody2D", true, false): _on_node_added(node)).call_deferred()

func _on_node_added(node: Node):
	var script = node.get_script()
	if script != null and script.resource_path == "res://Player/Player.gd":
		A2G.track(node, "player")

func world() -> Dictionary:
	return {"player_hp_fraction": snappedf(Global.health / Global.max_health, 0.001), "repellent": Global.repellent}

## Active scope from the current scene. The boss arena is registered at runtime through /v1/context.
func scope() -> Dictionary:
	var scene = get_tree().current_scene
	var name = str(scene.name) if scene else ""
	if name == "Boss":
		if not A2G.context_updates.scopes.has("boss_arena"):
			A2G.update_context({"boss_arena": BOSS_ARENA})
		if not A2G.scope_ready("boss_arena"):
			return {"scope": "dungeon"}
		return {"scope": "boss_arena", "state": {"boss_phase": boss_phase()}}
	if name.begins_with("CaveLevel"):
		return {"scope": "caves"}
	if name.begins_with("Dangeon"):
		return {"scope": "dungeon"}
	if name.begins_with("Level") or name in ["Entrace", "InsideHouse", "NPCInsideHouse", "PandaShop", "PolarShop"]:
		return {"scope": "overworld"}
	return {}

func boss_phase() -> int:
	for node in A2G.entities():
		if node.get_meta("a2g_type") == "boss":
			var fraction = node.HEALTH / node.get_meta("a2g_max_health", 1.0)
			return 1 if fraction > 0.66 else (2 if fraction > 0.33 else 3)
	return 3

## Called from enemy _ready().
func track(enemy: Node):
	var boss = enemy.get_script().resource_path == "res://Enemies/Boss.gd"
	var type = "boss" if boss else ("bee" if enemy.enemy_type == 0 else "bat")
	enemy.set_meta("a2g_max_health", float(enemy.HEALTH))
	A2G.track(enemy, type, {"profile": "queen_bee"} if boss else {})

## Bees spawned by the boss belong to her group: they see her decision, she sees them as members.
func link(minion: Node, leader: Node):
	A2G.set_parent(minion, leader)

func sees_player(enemy) -> bool:
	return is_instance_valid(enemy.playerDetectionZone.player) and not Global.repellent

## Lango's own perception: the detection zone, hidden by the repellent.
func aware_of_player(enemy) -> bool:
	return sees_player(enemy)

func allies_near(enemy) -> int:
	var count = 0
	for other in A2G.entities():
		if other != enemy and other.get_meta("a2g_type") == enemy.get_meta("a2g_type") and other.global_position.distance_to(enemy.global_position) <= ALLY_RADIUS:
			count += 1
	return count

## Same-type allies close to the player (excluding this enemy): who is engaging the player, wherever they stand.
func allies_near_player(enemy) -> int:
	var player = DebugOverlay.player_node
	if not is_instance_valid(player):
		return 0
	var count = 0
	for other in A2G.entities():
		if other != enemy and other.get_meta("a2g_type") == enemy.get_meta("a2g_type") and other.global_position.distance_to(player.global_position) <= AWARE_RADIUS:
			count += 1
	return count

func observe(enemy) -> Dictionary:
	var player = DebugOverlay.player_node
	var fields = {
		"hp_fraction": snappedf(enemy.HEALTH / enemy.get_meta("a2g_max_health", 1.0), 0.001),
		"distance_to_player": snappedf(enemy.global_position.distance_to(player.global_position), 0.1) if is_instance_valid(player) else 0.0,
		"sees_player": sees_player(enemy),
		"current_action": ACTIONS[enemy.state] if enemy.state >= 0 and enemy.state < ACTIONS.size() else "idle",
	}
	if enemy.get_meta("a2g_type") != "boss":
		fields["allies_near"] = allies_near(enemy)
		fields["allies_near_player"] = allies_near_player(enemy)
	return fields

func legal_actions(enemy) -> Array:
	return ACTIONS.duplicate() if aware_of_player(enemy) else ["idle", "wander"]

## Manifest events from changes since the last check: hit, player_spotted, player_lost, allies_gathered.
## The SDK drops events a type does not declare (only bees declare allies_gathered).
func trigger(enemy) -> String:
	var now = [enemy.HEALTH, aware_of_player(enemy), allies_near(enemy) if enemy.get_meta("a2g_type") != "boss" else 0]
	var before = enemy.get_meta("lango_a2g_last", now)
	enemy.set_meta("lango_a2g_last", now)
	if now[0] < before[0]:
		return "hit"
	if now[1] and not before[1]:
		return "player_spotted"
	if before[1] and not now[1]:
		return "player_lost"
	if now[2] >= 2 and before[2] < 2:
		return "allies_gathered"
	return ""

func position(enemy) -> Vector2:
	return enemy.global_position

func state(enemy) -> String:
	return STATES[enemy.state] if enemy.state >= 0 and enemy.state < STATES.size() else "UNKNOWN"

func interval_ms(enemy) -> int:
	return 3000 if aware_of_player(enemy) else 8000

func release(enemy):
	if enemy.state == 3:
		enemy.state = 0

func execute(enemy, action: String, delta: float) -> bool:
	var player = DebugOverlay.player_node
	var executed = true
	if action in ["chase", "flee"] and not aware_of_player(enemy):
		action = "idle"
		executed = false
	if action == "idle":
		enemy.state = 0
		enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.FRICTION * delta)
	elif action == "wander":
		enemy.state = 1
		if enemy.wanderController.get_time_left() == 0:
			enemy.wanderController.start_wander_timer(2.0)
		enemy.accelerate_towards_point(enemy.wanderController.target_position, delta)
	elif action == "chase":
		enemy.state = 2
		enemy.accelerate_towards_point(player.global_position, delta)
	else:
		enemy.state = 3
		var direction = player.global_position.direction_to(enemy.global_position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		enemy.accelerate_towards_point(enemy.global_position + direction * 64, delta)
	if enemy.has_node("Health"):
		enemy.get_node("Health").visible = true
	enemy.move_and_slide()
	keep_on_screen(enemy)
	return executed

## Same bounds as Lango's Player.move(): A2G-driven movement (notably flee, which Lango enemies never had)
## stays inside the level camera limits.
func keep_on_screen(enemy):
	var cam = enemy.get_viewport().get_camera_2d()
	if cam:
		enemy.global_position = enemy.global_position.clamp(Vector2(cam.limit_left + 6, cam.limit_top + 14), Vector2(cam.limit_right - 6, cam.limit_bottom - 4))
