class_name Player extends CharacterBody2D

# Summons
@export var slime_summon: PackedScene 
@export var skeleton_summon: PackedScene
@export var ghost_summon: PackedScene

# Animations
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var e_key_animation: AnimatedSprite2D = $EKeyAnimation
@onready var dash_smoke: AnimatedSprite2D = $"../DashSmoke" # set in MainScene

# Hitboxes
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var vertical_hitbox: Area2D = $VerticalAttackHitbox
@onready var horizontal_hitbox: Area2D = $HorizontalAttackHitbox
@onready var hurtbox: PlayerHurtbox = $HurtBox

# Funcionality:
@onready var summon_component: Summon = $Summon

# Timers:
@onready var attack_timer: Timer = $Timers/AttackTimer
@onready var knockback_timer:= $Timers/KnockbackTimer
@onready var dash_timer:= $Timers/DashTimer
@onready var dash_cooldown: Timer = $Timers/DashCooldown

# Damage numbers
@onready var damage_numbers_origin := $DamageNumbersOrigin
@onready var damage_animation_player:= $DamageAnimationPlayer

# Canvas Layer objects
@onready var slime_summon_sprite: Sprite2D = $"../CanvasLayer/HUD/Q-summon/Slime"
@onready var skeleton_summon_sprite: Sprite2D = $"../CanvasLayer/HUD/R-summon/SkeletonHead"
@onready var ghost_summon_sprite: Sprite2D = $"../CanvasLayer/HUD/F-summon/GhostHead"
@onready var new_summon_label: Label = $"../CanvasLayer/NewSummonLabel"

#Player MP
@onready var mp_bar: HealthBar = $CanvasLayer/MPBar
const MAX_MP := 100
var mp := 100

# Sound Effects
@onready var sword_stream_player: AudioStreamPlayer2D = $SoundEffects/SwordStreamPlayer
@onready var dash_stream_player: AudioStreamPlayer2D = $SoundEffects/DashStreamPlayer

const ATTACK_POWER = 20.0
const NORMAL_SPEED = 100.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.1
var is_dashing = false
var can_dash = true

var last_real_direction := Vector2.DOWN

var speed = 100.0
var last_direction := Vector2.DOWN
var is_moving := false
var is_attacking := false

var can_arise_mob := false

# start these in false
var Q_summon_enabled := false
var R_summon_enabled := false
var F_summon_enabled := false

var is_casting_spell := false

var is_knocked_back := false

func _ready() -> void:
	animated_sprite_2d.play("idle_back")
	vertical_hitbox.set_deferred("monitoring", false)
	horizontal_hitbox.set_deferred("monitoring", false)
	mp_bar.init_health(MAX_MP)
	mp_bar._set_health(mp)

func _physics_process(delta: float) -> void:
	if is_attacking or is_casting_spell:
		return
	
	if is_knocked_back:
		move_and_collide(velocity * delta)
		return
	
	if can_arise_mob:
		summon_component.handle_arise_mob()
		
	if Input.is_action_just_pressed("dash") and can_dash :
		dash_stream_player.play()
		can_dash = false
		dash_cooldown.start()
		dash_smoke.visible = true
		dash_smoke.position = global_position
		dash_smoke.play("dash")
		is_dashing = true
		speed = DASH_SPEED
		dash_timer.start(DASH_DURATION)

	handle_attack()
	handle_move(delta)

func handle_move(delta: float) -> void:
	
	var direction: Vector2
	
	if is_dashing:
		direction = last_real_direction
	else:
		direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()
		if (direction != Vector2.ZERO):
			last_real_direction = direction

	if direction != Vector2.ZERO:
		velocity = direction * speed * delta
		update_move_animation(direction)
		is_moving = true
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		if is_moving and velocity == Vector2.ZERO:
			play_idle_animation()
			is_moving = false

	move_and_collide(velocity)
	

func handle_attack() -> void:
	if Input.is_action_just_pressed("attack"):
		sword_stream_player.play()
		is_attacking = true

		if last_direction == Vector2.UP:
			animated_sprite_2d.play("attack_back")
			activate_hitbox(vertical_hitbox, Vector2(0, -16))
		elif last_direction == Vector2.DOWN:
			animated_sprite_2d.play("attack_front")
			activate_hitbox(vertical_hitbox, Vector2(0, 15))
		else:
			animated_sprite_2d.play("attack_side")
			animated_sprite_2d.flip_h = last_direction == Vector2.LEFT
			activate_hitbox(horizontal_hitbox, Vector2(-20 if last_direction == Vector2.LEFT else 0, 0))

		attack_timer.start()

func activate_hitbox(hitbox: Area2D, offset: Vector2) -> void:
	hitbox.global_position = global_position + offset
	hitbox.set_deferred("monitoring", true)

func update_move_animation(direction: Vector2) -> void:
	if is_casting_spell:
		return
		
	if not is_attacking:
		if abs(direction.y) > abs(direction.x):
			if direction.y < 0:
				animated_sprite_2d.play("walk_back")
				last_direction = Vector2.UP
			else:
				animated_sprite_2d.play("walk_front")
				last_direction = Vector2.DOWN
		else:
			if direction.x != 0:
				animated_sprite_2d.play("walk_side")
				animated_sprite_2d.flip_h = direction.x < 0
				last_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT

func play_idle_animation() -> void:
	if last_direction == Vector2.UP:
		animated_sprite_2d.play("idle_back")
	elif last_direction == Vector2.DOWN:
		animated_sprite_2d.play("idle_front")
	else:
		animated_sprite_2d.play("idle_side")
		animated_sprite_2d.flip_h = last_direction == Vector2.LEFT

func increase_mp(value):
	mp += value
	if mp > MAX_MP:
		mp = MAX_MP
	mp_bar._set_health(mp)

# there's no friendly fire to or from summons
func _on_vertical_attack_hitbox_body_entered(body: Node2D) -> void:
	if (body is Mob or body is Boss) and not body.is_ally and vertical_hitbox.visible:
		body.attack_received(self, ATTACK_POWER)
		if not body.is_dead:
			increase_mp(body.mp_hit_gain)

func _on_horizontal_attack_hitbox_body_entered(body: Node2D) -> void:
	if (body is Mob or body is Boss) and not body.is_ally and horizontal_hitbox.visible:
		body.attack_received(self, ATTACK_POWER)
		if not body.is_dead:
			increase_mp(body.mp_hit_gain)

func _on_attack_timer_timeout() -> void:
	vertical_hitbox.set_deferred("monitoring", false)
	horizontal_hitbox.set_deferred("monitoring", false)
	is_attacking = false
	play_idle_animation()
	
func _on_hurt_box_damage_taken(amount: Variant, source: Node2D) -> void:
	hurtbox.hp -= amount
	hurtbox.healthbar._set_health(hurtbox.hp)
	hurtbox.play_hurt_sound()
	DamageNumbers.display_text(str(amount), damage_numbers_origin.global_position, "#F00")
	damage_animation_player.play("damage_cooldown")
	
	if not is_knocked_back:
		var knockback_direction = (position - source.position).normalized()
		velocity = knockback_direction * 100.0 # parametrize knockback or change by enemy
		is_knocked_back = true
		knockback_timer.start(0.2)
	
	if hurtbox.hp <= 0:
		get_tree().reload_current_scene()

func _on_knockback_timer_timeout() -> void:
	is_knocked_back = false
	velocity = Vector2.ZERO
	

func _on_dash_timer_timeout() -> void:
	speed = NORMAL_SPEED
	is_dashing = false


func _on_dash_smoke_animation_finished() -> void:
	dash_smoke.visible = false


func _on_dash_cooldown_timeout() -> void:
	can_dash = true
