extends CharacterBody2D

@export var patrol_speed: float = 35.0     # 巡逻慢速
@export var chase_speed: float = 60.0      # 追击加速
@export var patrol_radius: float = 80.0    # 巡逻圈半径
@export var player_chase_distance: float = 150.0  # 发现距离

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var patrol_center: Vector2
var player: Node2D
var chase_timer: float = 0.0  # 追击专用定时器
var chase_update_interval: float = 0.5  # 追击更新频率

func _ready():
	add_to_group("enemies")
	patrol_center = position
	player = get_tree().get_first_node_in_group("player")
	
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.path_max_distance = 50.0
	
	# 初始生成巡逻路径
	_generate_new_patrol_target()
	
	print("👹 路径结束巡逻小怪激活: ", position)

func _physics_process(delta):
	chase_timer += delta
	
	# 动态状态切换
	if _should_chase_player():
		# 追击：频繁更新玩家位置
		if chase_timer > chase_update_interval:
			nav_agent.set_target_position(player.global_position)
			chase_timer = 0.0
	else:
		# 巡逻：只在路径结束时生成新路径
		if nav_agent.is_navigation_finished():
			_generate_new_patrol_target()
	
	# 移动逻辑（始终尝试）
	if not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos).normalized()
		
		var current_speed = chase_speed if _should_chase_player() else patrol_speed
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO  # 路径结束微停（自然）
	
	move_and_slide()
	
	# 面向移动方向
	if velocity.length() > 0:
		rotation = velocity.angle() + PI / 2

# 生成新巡逻目标（走到结束才调用）
func _generate_new_patrol_target():
	var angle = randf() * TAU
	var patrol_pos = patrol_center + Vector2(cos(angle), sin(angle)) * patrol_radius
	nav_agent.set_target_position(patrol_pos)
	print("👣 新巡逻路径生成: ", patrol_pos)

# 判断是否追击玩家
func _should_chase_player() -> bool:
	return player and global_position.distance_to(player.global_position) < player_chase_distance
