# scripts/player.gd
extends CharacterBody2D
class_name Player

const SPEED = 200.0
var health = 100

func _ready():
	print("👤 玩家已就绪！血量:", health)
	add_to_group("player")  # 让敌人能找到玩家

func _physics_process(delta):
	# WASD 或方向键移动
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * SPEED
	move_and_slide()  # 自动碰撞墙壁
	
	# 面向鼠标（增加沉浸感）
	if get_global_mouse_position() != global_position:
		look_at(get_global_mouse_position())

func take_damage(amount: int):
	health -= amount
	print("💥 玩家受伤！剩余血量:", health)
	if health <= 0:
		print("💀 玩家死亡！")
		get_tree().reload_current_scene()  # 重启游戏

func heal(amount: int):
	health += amount
	if health > 100:
		health = 100
	print("❤️ 玩家回血！血量:", health)