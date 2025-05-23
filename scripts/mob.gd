class_name Mob extends CharacterBody2D

@export var MAX_HP := 100.0
@export var attack_damage := 20.0
@export var speed := 40.0
@export var knockback := 150.0
@export var mp_hit_gain := 1
@export var mp_death_gain := 20

var hp := MAX_HP

var is_knocked_back := false
var is_spirit_slime := false
var is_emerging := false
var is_dying := false
var is_dead := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var player: Player = $"../../Player"
@onready var hit_flash_anim_player = $HitflashAnimationPlayer
@onready var damage_numbers_origin = $DamageNumbersOrigin
@onready var arise_area: Area2D = $AriseArea
@onready var hit_stream_player: AudioStreamPlayer2D = $SoundEffects/HitStreamPlayer

@export var is_ally := false
@export var is_recruitable := false

func _ready() -> void:
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, true)
	
	# Connect signals automatically
	knockback_timer.timeout.connect(_on_knockback_timer_timeout)
	arise_area.body_entered.connect(_on_arise_area_body_entered)
	arise_area.body_exited.connect(_on_arise_area_body_exited)
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func attack_received(source: Variant, damage: float) -> void:
	#avoid interaction while dying
	if is_dead:
		return
	
	if hp > 0:
		var knockback_direction = (global_position - source.position).normalized()
		velocity = knockback_direction * knockback
		is_knocked_back = true
		knockback_timer.start()
		hit_flash_anim_player.play("hit_flash")
		if source is Player:
			hit_stream_player.play()
	
	if not is_spirit_slime:
		hp -= damage
		if hp <= 0:
			handle_death()
			if source is Player:
				source.increase_mp(mp_death_gain)
		DamageNumbers.display_text(str(damage), damage_numbers_origin.global_position)
	
func _on_knockback_timer_timeout() -> void:
	is_knocked_back = false
	velocity = Vector2.ZERO


func handle_death() -> void:
	is_dead = true
	animated_sprite.play("death")

func _on_arise_area_body_entered(body: Node2D) -> void:
	if body is Player and is_spirit_slime:
		player.can_arise_mob = true
		player.e_key_animation.visible = true

func _on_arise_area_body_exited(body: Node2D) -> void:
	if body is Player and is_spirit_slime:
		player.can_arise_mob = false
		player.e_key_animation.visible = false

func delete_spirit_mob() -> void:
	if is_spirit_slime:
		queue_free()

func _on_hurtbox_damage_taken(amount: Variant, source: Variant) -> void:
	attack_received(source, amount)
	

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		if is_recruitable:
			is_spirit_slime = true
			player.summon_component.connect("delete_mob", Callable(self, "delete_spirit_mob"))
			animated_sprite.play("spirit")
		else:
			if is_ally:
				player.summon_component.summon_killed(self)
			queue_free()
