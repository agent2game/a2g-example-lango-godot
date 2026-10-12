extends CharacterBody2D

const EnemyDeathEffect          = preload("res://Effects/EnemyDeathEffect.tscn")
const Drop                      = preload("res://World/Item.tscn")
const Bee                       = preload("res://Enemies/Bee.tscn")

@export var ACCELERATION         = 300
@export var MAX_SPEED            = 75
@export var FRICTION             = 200
@export var WANDER_TARGET_RANGE  = 4
@export var HEALTH               = 50.0

@onready var playerDetectionZone = $PlayerDetectionZone
@onready var wanderController    = $WanderController
@onready var animationPlayer     = $AnimationPlayer
@onready var hurtbox             = $HurtBox
@onready var sprite              = $AnimatedSprite2D

var knockback                   = Vector2.ZERO
var rng                         = RandomNumberGenerator.new()
var dead                        = false
var my_number

enum{ IDLE, WANDER, CHASE }
var state = CHASE 

signal boss_is_dead

func _ready():
	LangoA2G.track(self)
	state = pick_random_state([IDLE, WANDER])

	# warning-ignore:return_value_discarded
	self.connect("boss_is_dead", Callable(get_parent().get_parent(), "drop_key"))

func _physics_process(delta):

	knockback = knockback.move_toward(Vector2.ZERO, FRICTION * delta)
	var own_velocity = velocity
	velocity = knockback
	move_and_slide()
	knockback = velocity
	velocity = own_velocity

	if A2G.execute(self, delta):
		return

	match state:
		
		IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
			seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
		WANDER:
			seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
			accelerate_towards_point(wanderController.target_position, delta)
			
			if global_position.distance_to(wanderController.target_position) <= WANDER_TARGET_RANGE:
				update_wander()
		CHASE:
			var player = playerDetectionZone.player
			if player != null:
				accelerate_towards_point(player.global_position, delta)
			else:
				state = IDLE
				
	move_and_slide()

func update_wander():
	state = pick_random_state([IDLE, WANDER])
	wanderController.start_wander_timer(randf_range(1, 3))

func accelerate_towards_point(point, delta):
	var direction = global_position.direction_to(point)
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	sprite.flip_h = velocity.x < 0

func seek_player():
	if playerDetectionZone.can_see_player():
		$AudioStreamPlayer.play()
		state = CHASE

func _on_HurtBox_area_entered(area):
	HEALTH = maxf(0.0, snappedf(HEALTH - area.damage * DebugOverlay.damage_multiplier, 0.000001))
	if HEALTH > 0:
		knockback = area.knockback_vector * 120
		hurtbox.create_hit_effect()
		hurtbox.start_invincibility(0.4)
		$AudioStreamPlayer.play()
	if HEALTH <= 0:
		dead = true
		queue_free()
		var enemyDeathEffect = EnemyDeathEffect.instantiate()
		get_parent().add_child(enemyDeathEffect)
		enemyDeathEffect.global_position = global_position

func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()

func _on_HurtBox_invincibility_started():
	animationPlayer.play("Start")

func _on_HurtBox_invincibility_ended():
	animationPlayer.play("Stop")

func _on_HurtBox_area_exited(_area):
	if dead == true:
		for x in randf_range(15,30):
			var drop = Drop.instantiate()
			drop.type = 2
			get_parent().add_child.call_deferred(drop)
			drop.global_position = global_position + Vector2(randf_range(-16,16),randf_range(-16,16))
			emit_signal("boss_is_dead")

func _on_Timer_timeout():
	var bee = Bee.instantiate()
	get_parent().add_child(bee)
	bee.position = position
	LangoA2G.link(bee, self)
