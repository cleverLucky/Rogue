extends CharacterBody2D

@export var patrol_speed: float = 35.0
@export var chase_speed: float = 60.0
@export var patrol_radius: float = 80.0
@export var player_chase_distance: float = 150.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var my_room_bounds: Rect2 = Rect2()
var patrol_center: Vector2
var player: Node2D = null

var chase_timer: float = 0.0
var chase_update_interval: float = 0.4  # 追击更新间隔（防过度重算）

func _ready():
	add_to_group("enemies")
	patrol_center = position
	
	if my_room_bounds == Rect2():
		my_room_bounds = Rect2(0, 0, 1280, 960)
	
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.path_max_distance = 64.0
	
	_generate_new_patrol_target()
	print("👹 优化版房间限定小怪激活，边界: ", my_room_bounds)

func _physics_process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	chase_timer += delta
	
	var should_chase = _should_chase_player()
	
	# 目标更新逻辑
	if should_chase:
		# 追击：定时更新玩家位置
		if chase_timer >= chase_update_interval:
			nav_agent.set_target_position(player.global_position)
			chase_timer = 0.0
	else:
		# 巡逻：只在路径结束时换新目标
		if nav_agent.is_navigation_finished():
			_generate_new_patrol_target()
	
	# 移动计算
	var target_velocity := Vector2.ZERO
	
	if not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos).normalized()
		
		# 防零向量（用上一帧方向或默认右）
		if direction.length_squared() < 0.01:
			direction = velocity.normalized()
			if direction.length_squared() < 0.01:
				direction = Vector2.RIGHT
		
		var current_speed = chase_speed if should_chase else patrol_speed
		target_velocity = direction * current_speed
	
	# 平滑速度（转向更自然）
	velocity = velocity.lerp(target_velocity, delta * 12.0)
	
	# 分离力（放在速度计算后，碰撞前）
	var separation = _calculate_separation_force()
	velocity += separation * delta * 120.0  # 推力强度
	velocity = velocity.limit_length(max(patrol_speed, chase_speed))  # 限速
	
	move_and_slide()
	
	# 平滑旋转
	if velocity.length() > 5.0:
		var target_rot = velocity.angle() + PI / 2
		rotation = lerp_angle(rotation, target_rot, delta * 15.0)

# 计算分离力（Boids风格）
func _calculate_separation_force() -> Vector2:
	var force = Vector2.ZERO
	var nearby = get_tree().get_nodes_in_group("enemies")
	for other in nearby:
		if other == self:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < 32.0 and dist > 0.1:
			var dir = global_position.direction_to(other.global_position)
			force -= dir * (1.0 / dist)  # 负方向 = 推开
	
	return force.normalized() * 80.0  # 强度可调

# 生成新巡逻目标
func _generate_new_patrol_target():
	var room_min_dim = min(my_room_bounds.size.x, my_room_bounds.size.y)
	var dynamic_radius = max(30.0, room_min_dim * 0.45)  # 优化：最小30
	
	var attempts = 0
	while attempts < 60:
		var angle = randf() * TAU
		var patrol_pos = patrol_center + Vector2(cos(angle), sin(angle)) * dynamic_radius
		patrol_pos = patrol_pos.clamp(my_room_bounds.position, my_room_bounds.end)
		
		nav_agent.set_target_position(patrol_pos)
		
		if nav_agent.is_target_reachable():
			return  # 成功
		
		attempts += 1
	
	# 失败时回中心
	nav_agent.set_target_position(patrol_center)
	print("⚠️ 小怪回退到中心点，房间可能太小")

func _should_chase_player() -> bool:
	if player == null:
		return false
	var dist = global_position.distance_to(player.global_position)
	return dist < player_chase_distance and my_room_bounds.has_point(player.global_position)
