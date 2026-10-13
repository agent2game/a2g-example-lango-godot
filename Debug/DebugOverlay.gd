extends CanvasLayer

const ENEMY_SCRIPTS = ["res://Enemies/Enemy.gd", "res://Enemies/Bee.gd", "res://Enemies/Boss.gd"]
const STATES = ["IDLE", "WANDER", "CHASE", "FLEE"]
const ACCENT = Color("ff63eb")
const STATE_COLORS = ["8bd5ff", "ffd166", "ff758f", "bba0ff"]

var infinite_health = false
var damage_multiplier = 1.0
var god_mode_button: CheckButton
var damage_spin: SpinBox
var mode_selector: OptionButton
var labels_toggle: CheckButton
var offscreen_toggle: CheckButton
var show_labels = false
var show_offscreen = false

var enabled = false
var root: Control
var panel: PanelContainer
var summary: Label
var mode_banner: RichTextLabel
var rows: VBoxContainer
var enemies: Dictionary = {}
var player_node: Node2D
var refresh_elapsed = 0.0
var connectors: Node2D
var connections: Array = []

func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.scale = Vector2(0.25, 0.25)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	connectors = Node2D.new()
	connectors.draw.connect(_draw_connections)
	root.add_child(connectors)
	panel = PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(300, 640)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme = Theme.new()
	theme.default_font_size = 14
	panel.theme = theme
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.015, 0.04, 0.78)
	background.set_content_margin_all(12)
	background.set_border_width_all(1)
	background.border_color = ACCENT
	panel.add_theme_stylebox_override("panel", background)
	root.add_child(panel)
	var contents = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(contents)
	summary = make_label()
	contents.add_child(summary)
	mode_selector = OptionButton.new()
	mode_selector.add_item("FSM: original behavior")
	mode_selector.add_item("AI: OpenAI Decisions")
	mode_selector.item_selected.connect(func(index): A2G.set_ai_enabled(index == 1))
	contents.add_child(mode_selector)
	labels_toggle = CheckButton.new()
	labels_toggle.text = "Show enemy labels"
	labels_toggle.toggled.connect(func(on): show_labels = on)
	contents.add_child(labels_toggle)
	offscreen_toggle = CheckButton.new()
	offscreen_toggle.text = "Include outside view"
	offscreen_toggle.toggled.connect(func(on): show_offscreen = on)
	contents.add_child(offscreen_toggle)
	god_mode_button = CheckButton.new()
	god_mode_button.text = "Infinite player HP"
	god_mode_button.toggled.connect(func(on): infinite_health = on)
	contents.add_child(god_mode_button)
	var damage_label = make_label()
	damage_label.text = "Damage multiplier (both sides)"
	contents.add_child(damage_label)
	damage_spin = SpinBox.new()
	damage_spin.min_value = 0.01
	damage_spin.max_value = 10.0
	damage_spin.step = 0.01
	damage_spin.value = 1.0
	damage_spin.suffix = "x"
	damage_spin.value_changed.connect(func(value): damage_multiplier = value)
	contents.add_child(damage_spin)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	mode_banner = make_rich_label()
	mode_banner.custom_minimum_size.x = 450
	mode_banner.text = "[color=#8bd5ff][b]CONTROL: FSM[/b][/color]  |  AI NOT CONNECTED"
	mode_banner.add_theme_stylebox_override("normal", card_background())
	root.add_child(mode_banner)
	panel.visible = false
	mode_banner.visible = false
	connectors.visible = false
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		track_enemy(node.get_instance_id())

func make_label() -> Label:
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ACCENT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

func card_background() -> StyleBoxFlat:
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.025, 0.04, 0.9)
	background.set_content_margin_all(7)
	background.set_corner_radius_all(5)
	background.set_border_width_all(1)
	background.border_color = Color("60768a")
	return background

func make_rich_label() -> RichTextLabel:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = 240
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	label.add_theme_color_override("default_color", Color("f3e9f3"))
	return label

func _on_node_added(node: Node):
	# A node may be freed before the deferred call; resolve its ID at execution time.
	track_enemy.call_deferred(node.get_instance_id())

func track_enemy(node_id: int):
	var node = instance_from_id(node_id)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var script = node.get_script()
	if script != null and script.resource_path == "res://Player/Player.gd":
		player_node = node
	if script == null or script.resource_path not in ENEMY_SCRIPTS:
		return
	var id = node.get_instance_id()
	if enemies.has(id):
		return
	var marker_box = PanelContainer.new()
	marker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_box.add_theme_stylebox_override("panel", card_background())
	var marker = make_rich_label()
	marker_box.add_child(marker)
	root.add_child(marker_box)
	marker_box.visible = false
	var row = make_rich_label()
	rows.add_child(row)
	enemies[id] = {"node": node, "max_health": node.HEALTH, "marker": marker, "marker_box": marker_box, "row": row}

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT or event.keycode in [KEY_QUOTELEFT, KEY_ASCIITILDE]:
			enabled = not enabled
			panel.visible = enabled
			refresh_elapsed = 1.0
			get_viewport().set_input_as_handled()

func state_name(value: int) -> String:
	return STATES[value] if value >= 0 and value < STATES.size() else "UNKNOWN(%d)" % value

func _draw_connections():
	for connection in connections:
		connectors.draw_line(connection[0], connection[1], Color("8bd5ff"), 1.5, true)
		connectors.draw_circle(connection[1], 3, Color("8bd5ff"))

func _process(delta):
	for id in enemies.keys():
		var entry = enemies[id]
		if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion():
			entry.marker_box.queue_free()
			entry.row.queue_free()
			enemies.erase(id)
	panel.visible = enabled
	mode_banner.visible = enabled or show_labels
	connectors.visible = show_labels
	if enabled or A2G.ai_enabled:
		A2G.check_service()
	if not enabled and not show_labels:
		for entry in enemies.values():
			entry.marker_box.visible = false
		return
	mode_selector.select(1 if A2G.ai_enabled else 0)
	var viewport_size = get_viewport().get_visible_rect().size * 4.0
	panel.size.y = maxf(160, viewport_size.y - 24)
	mode_banner.position = Vector2(panel.position.x + panel.size.x + 12 if enabled else maxf(8, (viewport_size.x - mode_banner.size.x) / 2), 12)
	var occupied: Array[Rect2] = []
	connections.clear()
	var current_scene = get_tree().current_scene
	refresh_elapsed += delta
	var update_text = refresh_elapsed >= 0.1
	if update_text:
		refresh_elapsed = 0.0
	var counts = {"Bee": 0, "Bat": 0, "Boss": 0}
	var ai_count = 0
	var fallback_count = 0
	for entry in enemies.values():
		var enemy = entry.node
		var on_level = current_scene != null and current_scene.is_ancestor_of(enemy)
		entry.row.visible = on_level
		entry.marker_box.visible = false
		if not on_level:
			continue
		var kind = "Boss" if enemy.get_script().resource_path == "res://Enemies/Boss.gd" else ("Bee" if enemy.enemy_type == 0 else "Bat")
		counts[kind] += 1
		var sprite_transform = enemy.sprite.get_global_transform_with_canvas()
		var texture = enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation, enemy.sprite.frame)
		var sprite_size = texture.get_size() if texture != null else Vector2(16, 16)
		var sprite_rect = sprite_transform * Rect2(enemy.sprite.offset - sprite_size / 2, sprite_size)
		var screen_position = (sprite_transform * enemy.sprite.offset) * 4.0
		var on_screen = Rect2(Vector2.ZERO, viewport_size).intersects(Rect2(sprite_rect.position * 4, sprite_rect.size * 4))
		entry.row.visible = on_screen or show_offscreen
		entry.marker_box.visible = show_labels and (on_screen or show_offscreen)
		var current_decision = enemy.get_meta("a2g_decision", {})
		if A2G.ai_enabled:
			if A2G.is_fresh(current_decision):
				ai_count += 1
			else:
				fallback_count += 1
		if update_text:
			var player = enemy.playerDetectionZone.player
			var detected = is_instance_valid(player) and not Global.repellent
			var distance = "%.0f px" % enemy.global_position.distance_to(player_node.global_position) if is_instance_valid(player_node) else "-"
			var state = state_name(enemy.state)
			var state_color = STATE_COLORS[enemy.state] if enemy.state >= 0 and enemy.state < STATE_COLORS.size() else "ffffff"
			var animation = str(enemy.sprite.animation)
			var status = "[color=#%s][b]%s[/b][/color]" % [state_color, state]
			var decision = enemy.get_meta("a2g_decision", {}) if A2G.ai_enabled else {}
			var source_name = decision.get("source", "FALLBACK" if A2G.ai_enabled else "FSM")
			if source_name == "AI" and not A2G.is_fresh(decision):
				source_name = "FALLBACK"
			var source_color = "8bd5ff" if source_name == "FSM" else ("83efa3" if source_name == "AI" else "ffd166")
			var source = "[color=#%s][b]%s[/b][/color]" % [source_color, source_name]
			var confidence = " | conf %d%%" % roundi(decision.confidence * 100) if decision.get("confidence") is float else ""
			var choice = str(decision.get("label", decision.get("reason", "Original game behavior"))).replace("[", "(")
			if decision.get("cached", false):
				choice += " (cached)"
			elif decision.get("code"):
				choice = "%s: %s" % [decision.code, choice]
			var details = "\nAction: %s | %d ms%s\nChoice: %s%s" % [decision.get("action", state.to_lower()), decision.get("latency_ms", 0), confidence, choice, "\nRequest: pending" if enemy.get_meta("a2g_pending", false) and A2G.ai_enabled else ""]
			entry.marker.text = "[b]%s[/b]  %s\nHP %.2f/%.2f  %s\nPlayer %s | seen %s\nAnim: %s | %.0f px/s%s" % [enemy.name, source, enemy.HEALTH, entry.max_health, status, distance, "yes" if detected else "no", animation, enemy.velocity.length(), "\n[color=#ffd166]OUTSIDE VIEW[/color]" if not on_screen else ""]
			entry.row.text = "[b]%s [%s][/b]  %s\nHP %.2f/%.2f  %s\nAnimation: %s\nPlayer detected: %s\nDistance: %s | %.1f px/s" % [enemy.name, kind, source, enemy.HEALTH, entry.max_health, status, animation, "yes" if detected else "no", distance, enemy.velocity.length()]
			entry.marker.text += details
			entry.row.text += details
		var marker_box: PanelContainer = entry.marker_box
		if not marker_box.visible:
			continue
		marker_box.reset_size()
		var lower = Vector2(panel.position.x + panel.size.x + 12 if enabled else 8, maxf(56, mode_banner.position.y + mode_banner.size.y + 8))
		var upper = viewport_size - marker_box.size - Vector2(8, 8)
		var desired = screen_position - Vector2(marker_box.size.x / 2, marker_box.size.y + 76)
		marker_box.position = desired.clamp(lower, upper.max(lower))
		# shortcut: crowded cards may overlap, use the full sidebar list until marker clustering is needed.
		if overlaps_cards(Rect2(marker_box.position, marker_box.size), occupied):
			var placed = false
			for y in range(int(lower.y), int(upper.y) + 1, int(marker_box.size.y) + 8):
				for x in range(int(lower.x), int(upper.x) + 1, int(marker_box.size.x) + 8):
					var candidate = Rect2(Vector2(x, y), marker_box.size)
					if not overlaps_cards(candidate, occupied):
						marker_box.position = candidate.position
						placed = true
						break
				if placed:
					break
		occupied.append(Rect2(marker_box.position, marker_box.size))
		if on_screen:
			connections.append([screen_position.clamp(marker_box.position, marker_box.position + marker_box.size), screen_position])
	connectors.queue_redraw()

	if update_text:
		var mode_color = "83efa3" if ai_count > 0 else "ffd166"
		var ai_status = "[color=#%s][b]AI: %d active / %d fallback[/b][/color] | %d pending" % [mode_color, ai_count, fallback_count, A2G.pending_count()]
		mode_banner.text = ai_status if A2G.ai_enabled else "[color=#8bd5ff][b]FSM: AI OFF[/b][/color]"
		mode_banner.text += "\nA2G service: " + A2G.service_status + (" | session ok" if A2G.session_ready else " | no session")
		if A2G.ai_enabled:
			mode_banner.text += " | OpenAI reply: %.0f s ago" % ((Time.get_ticks_msec() - A2G.last_ai_reply_ms) / 1000.0) if A2G.last_ai_reply_ms >= 0 else " | OpenAI: awaiting first reply"
		var scene = get_tree().current_scene
		var player_state = "-"
		var player_speed = 0.0
		if is_instance_valid(player_node):
			player_state = ["MOVE", "ROLL", "ATTACK", "TRANSITION"][player_node.state]
			player_speed = player_node.velocity.length()
		summary.text = "DEBUG  [~ close]\nScene: %s\nPlayer HP: %s/%s\nPlayer state: %s\nPlayer speed: %.1f px/s\nRepellent: %s\nEnemies: %d\nBees: %d  Bats: %d  Bosses: %d\nSwitch FSM / AI below" % [scene.name if scene else "-", ("%.2f" % Global.health), ("%.2f" % Global.max_health), player_state, player_speed, "on" if Global.repellent else "off", counts.Bee + counts.Bat + counts.Boss, counts.Bee, counts.Bat, counts.Boss]

func overlaps_cards(candidate: Rect2, occupied: Array[Rect2]) -> bool:
	for other in occupied:
		if candidate.grow(4).intersects(other):
			return true
	return false
