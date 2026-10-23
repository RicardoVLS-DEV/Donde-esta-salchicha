extends CharacterBody2D

# --- Variables de Movimiento y Gravedad (Tuyas) ---
@export var speed: float = 150.0
@export var jump_velocity: float = -200.0
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false
@export var knockback_force: float = 220.0
@export var knockback_upward: float = 80.0
@export var knockback_duration: float = 0.18
@export var death_height: float = 150.0

var knockback_timer: float = 0.0
var is_dead: bool = false

# --- Variables de Vida y Combate (Nuevas) ---
@export var max_health: int = 100
var current_health: int = 100
@export var attack_damage: int = 25

# --- Referencias a Nodos ---
@onready var animated_sprite: AnimatedSprite2D = $Sprite2D
# IMPORTANTE: Asegúrate de tener el nodo Area2D llamado "PlayerHitbox" y dentro su CollisionShape2D
@onready var hitbox_shape: CollisionShape2D = $PlayerHitbox/CollisionShape2D 
@onready var player_hitbox: Area2D = $PlayerHitbox

func _ready() -> void:
	# Asegurarnos de que inicias con la vida llena y el área de golpe desactivada
	add_to_group("player")
	current_health = max_health
	hitbox_shape.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	
	# 1. Aplicar Gravedad si el personaje está en el aire
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return

	# 2. Manejo de Ataque
	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	# 3. Manejo de Salto
	if Input.is_action_just_pressed("move_up") and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity

	# 4. Movimiento Horizontal
	if not is_attacking:
		var direction := Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			velocity.x = direction * speed
			
			# Ajustar la orientación del sprite según la dirección
			animated_sprite.flip_h = direction < 0
			
			# NUEVO: Ajustar la posición del Hitbox de ataque para que golpee hacia donde miras
			if direction < 0:
				player_hitbox.position.x = -abs(player_hitbox.position.x) # Mover a la izquierda
			else:
				player_hitbox.position.x = abs(player_hitbox.position.x)  # Mover a la derecha
				
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
	else:
		# Frenar suavemente en horizontal si se activa un ataque
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
	
	if global_position.y >= death_height:
		die()
		return
		
	# 5. Actualizar animaciones de movimiento e idle
	update_animations()
	
	

func update_animations() -> void:
	if is_attacking:
		return

	if velocity.x != 0.0:
		animated_sprite.play("walk_right")
	else:
		animated_sprite.play("idle_right")

func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack_right")
	
	# NUEVO: Activar el hitbox para que pueda dañar enemigos
	hitbox_shape.disabled = false

	# Duración de tu ataque (0.4 segundos)
	await get_tree().create_timer(0.4).timeout

	# NUEVO: Desactivar el hitbox al terminar el ataque
	hitbox_shape.disabled = true
	is_attacking = false

# =========================================================
# NUEVAS FUNCIONES DE INTERACCIÓN (Daño, Vida, Muerte)
# =========================================================

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return

	current_health = max(current_health - amount, 0)

	# Retroceso en dirección contraria al atacante
	var direction: float = sign(global_position.x - source_position.x)
	if direction == 0:
		direction = -1 if animated_sprite.flip_h else 1

	velocity.x = direction * knockback_force
	velocity.y = -knockback_upward
	knockback_timer = knockback_duration

	print("Jugador golpeado. Vida: ", current_health)

	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	# min() evita que la vida supere la vida máxima
	current_health = min(current_health + amount, max_health)
	print("Curación. Vida del jugador: ", current_health)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("¡El jugador ha muerto!")

	# Desactivar el área de ataque si existe
	if is_instance_valid(hitbox_shape):
		hitbox_shape.set_deferred("disabled", true)

	# Reiniciar la escena fuera del callback de físicas
	get_tree().call_deferred("reload_current_scene")


# NOTA: Selecciona el nodo "PlayerHitbox" (Area2D), ve a Nodos > Señales, 
# da doble clic en 'body_entered' y conéctalo a este script:
func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(attack_damage)
