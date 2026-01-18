extends CharacterBody2D

@export var patrol_speed: float = 35.0
@export var chase_speed: float = 60.0
@export var patrol_radius: float = 80.0
@export var player_chase_distance: float = 150.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var my_room_bounds: Rect2 = Rect2()  # 出生房间边界，由 spawner 设置
var patrol_center: Vector2
var player: Node2D = null

func _ready():
	add_to_group("enemies")
	patrol_center = position
	
	# 默认全地图边界（防止未设置）
	if my_room_bounds == Rect2():
		my_room_bounds = Rect2(0, 0, 1280, 960)
	
	# 初始生成第一个巡逻路径
	_generate_new_patrol_target()
	
	print("👹 房间限定小怪激活，房间边界: ", my_room_bounds)

func _physics_process(delta):
	# 每帧尝试查找玩家（如果还没找到）
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	# 判断当前状态
	var should_chase = _should_chase_player()
	
	if should_chase:
		# 追击模式：实时更新玩家位置（保持响应快）
		nav_agent.set_target_position(player.global_position)
	else:
		# 巡逻模式：**只在路径结束时**才生成新目标（无抖动）
		if nav_agent.is_navigation_finished():
			_generate_new_patrol_target()
	
	# 移动逻辑（始终平滑）
	if not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos).normalized()
		
		# 方向防零向量抖动
		if direction.length() < 0.1:
			direction = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT
		
		var current_speed = chase_speed if should_chase else patrol_speed
		velocity = direction * current_speed
		
		# 平滑转向（减少抖动）
		velocity = velocity.lerp(direction * current_speed, delta * 8.0)
	else:
		# 路径结束时平滑减速（自然停顿）
		velocity = velocity.move_toward(Vector2.ZERO, patrol_speed * delta * 3.0)
	
	move_and_slide()
	
	# 平滑旋转（避免突变）
	if velocity.length() > 5.0:
		var target_rot = velocity.angle() + PI / 2
		rotation = lerp_angle(rotation, target_rot, delta * 10.0)

# 生成新巡逻目标（只在路径结束时调用）
func _generate_new_patrol_target():
	var attempts = 0
	while attempts < 30:  # 增加尝试次数，确保找到可达点
		var angle = randf() * TAU
		var patrol_pos = patrol_center + Vector2(cos(angle), sin(angle)) * patrol_radius
		
		# 严格限制在房间内
		patrol_pos = patrol_pos.clamp(my_room_bounds.position, my_room_bounds.position + my_room_bounds.size)
		
		# 设置新目标
		nav_agent.set_target_position(patrol_pos)
		
		# 检查是否可达（NavAgent 会自动计算）
		if nav_agent.is_target_reachable():
			break
		
		attempts += 1
	
	if attempts >= 30:
		print("警告：怪物无法生成有效巡逻点，房间可能太小")

func _should_chase_player() -> bool:
	if player == null:
		return false
	
	var dist = global_position.distance_to(player.global_position)
	return dist < player_chase_distance and my_room_bounds.has_point(player.global_position)
