
extends CharacterBody2D

@export var max_health: int = 50
@export var touch_damage: int = 20

# Persecución
@export var chase_speed: float = 45.0
@export var detection_range: float = 250.0
@export var stop_distance: float = 30.0

# Retroceso
@export var knockback_force: float = 220.0
@export var knockback_upward: float = 70.0
@export var knockback_duration: float = 0.18

@export var damage_cooldown: float = 1.0

var health: int = 50
var is_dead: bool = false
var can_damage_player: bool = true
var knockback_timer: float = 0.0

var gravity: float = float(
	ProjectSettings.get_setting("physics/2d/default_gravity")
)

var player: CharacterBody2D = null


func _ready() -> void:
	add_to_group("enemy")
	health = max_health

	var damage_area = get_node_or_null("EnemyDamageArea")

	if damage_area:
		damage_area.body_entered.connect(
			_on_enemy_damage_area_body_entered
		)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Durante el retroceso no perseguir al jugador
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return

	# Buscar al jugador
	if not is_instance_valid(player):
		player = null

		
		var players: Array[Node] = get_tree().get_nodes_in_group("player")

		if not players.is_empty():
			player = players[0] as CharacterBody2D

	# Perseguir lentamente dentro del rango
	if is_instance_valid(player):
		var distance := global_position.distance_to(
			player.global_position
		)

		if distance <= detection_range and distance > stop_distance:
			var direction: float = sign(
				player.global_position.x - global_position.x
			)

			velocity.x = direction * chase_speed
		else:
			velocity.x = move_toward(
				velocity.x, 0.0, chase_speed
			)
	else:
		velocity.x = move_toward(
			velocity.x, 0.0, chase_speed
		)

	move_and_slide()


func _on_enemy_damage_area_body_entered(body: Node2D) -> void:
	if is_dead or not can_damage_player:
		return

	if not body.is_in_group("player"):
		return

	if not body.has_method("take_damage"):
		return

	var scene_tree: SceneTree = get_tree()

	can_damage_player = false
	body.take_damage(touch_damage, global_position)

	if not is_inside_tree():
		return

	await scene_tree.create_timer(damage_cooldown).timeout

	if not is_inside_tree() or is_dead:
		return

	can_damage_player = true

	# Guardar una referencia al árbol antes de aplicar daño
	

	can_damage_player = false

	# Aplicar daño al jugador
	body.take_damage(touch_damage, global_position)

	# Comprobar si el enemigo sigue dentro del árbol
	if not is_inside_tree():
		return

	# Esperar antes de permitir otro golpe
	await scene_tree.create_timer(damage_cooldown).timeout


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return

	health = max(health - amount, 0)

	# Retroceso en dirección contraria al atacante
	var direction: float = sign(
		global_position.x - source_position.x
	)

	if direction == 0:
		direction = 1

	velocity.x = direction * knockback_force
	velocity.y = -knockback_upward
	knockback_timer = knockback_duration

	print("Enemigo golpeado. Vida: ", health, "/", max_health)

	if health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("Enemigo eliminado")
	queue_free()
