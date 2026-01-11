extends NodeState

@export var player : Player
@export var animated_sprite_2d : AnimatedSprite2D
@export var speed : int = 50

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_physics_process(delta:float) -> void:
	var diretion: Vector2 = GameInputEvent.movement_input()
	
	if diretion == Vector2.UP:
		animated_sprite_2d.play("walk_back")
	elif diretion == Vector2.DOWN:
		animated_sprite_2d.play("walk_front")
	elif diretion == Vector2.LEFT:
		animated_sprite_2d.play("walk_left")
	elif diretion == Vector2.RIGHT:
		animated_sprite_2d.play("walk_right")
		
	if diretion != Vector2.ZERO:
		player.player_direction = diretion
	
	player.velocity = speed * diretion
	player.move_and_slide()
	
func _on_next_transitions() -> void:
	if !GameInputEvent.is_movement_input():
		transition.emit("Idle")
	
func _on_enter() -> void:
	pass
	
func _on_exit() -> void:
	animated_sprite_2d.stop()
	
