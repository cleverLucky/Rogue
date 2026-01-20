# scripts/EnemySpawner.gd
# 房间优先 + 走廊0怪物 + 面积加权（大房间多怪物）+ 每个怪物绑定房间
extends Node
class_name EnemySpawner

@export var enemy_scene: PackedScene # 编辑器拖入 enemy.tscn
@export var min_enemies: int = 18
@export var max_enemies: int = 40
@export var grid_divisions: int = 7   # 每个房间内分块数（均匀分布用）

var grid: Array = []
var rooms: Array[Dictionary] = []     # 房间数据 {'rect':Rect2, 'center':Vector2, 'area':float}
var tile_size: int = 16
var map_width: int = 80
var map_height: int = 60
var used_positions: Dictionary = {}

func spawn_enemies(custom_count: int = -1) -> void:
	used_positions.clear()
	
	var target_count = custom_count if custom_count >= 0 else randi_range(min_enemies, max_enemies)
	
	if enemy_scene == null:
		printerr("EnemySpawner: 敌人场景未设置！")
		return
	
	if rooms.is_empty():
		printerr("EnemySpawner: 房间数据未设置！请在initialize传入rooms")
		return
	
	print("🛡️ 面积加权生成怪物：目标=", target_count, "，房间数=", rooms.size())
	
	var allocations = _allocate_by_area(target_count)
	var spawned = 0
	
	# 根据分配数量，在每个房间生成对应怪物数
	for room_idx in rooms.size():
		var room = rooms[room_idx]
		if room.get('is_starting_room', false):
			print("跳过起始安全室，不生成怪物")
			continue  # 跳过这个房间
		var to_spawn = allocations[room_idx]
		
		if to_spawn <= 0:
			continue
		
		# 计算该房间的 Rect2i（四舍五入）
		var rect = room.rect
		var room_rect = Rect2i(
			round(rect.position.x),
			round(rect.position.y),
			round(rect.size.x),
			round(rect.size.y)
		)
		
		# 在这个房间内生成 to_spawn 只怪物（用分块均匀）
		for _i in range(to_spawn):
			var pos = _get_random_floor_in_room(room_rect)
			if pos != Vector2i(-1, -1) and _place_enemy(room_rect, pos):
				spawned += 1
	
	print("✅ 面积加权生成完成：", spawned, "个 (走廊0%)，实际分配：", allocations)

# 面积加权分配算法（核心）
func _allocate_by_area(target_count: int) -> Array[int]:
	# 计算总面积
	var total_area: float = 0.0
	for room in rooms:
		total_area += room.area
	
	if total_area <= 0:
		return []
	
	# 第一步：计算每个房间的期望值
	var expected: Array[float] = []
	for room in rooms:
		var weight = room.area / total_area
		expected.append(target_count * weight)
	
	# 第二步：分配整数部分
	var allocated: Array[int] = []
	var total_allocated = 0
	
	for i in rooms.size():
		var num = int(expected[i])  # floor
		allocated.append(num)
		total_allocated += num
	
	# 第三步：剩余数量按小数部分 + 随机扰动分配
	var remaining = target_count - total_allocated
	
	# 小数部分作为基础权重
	var weights: Array[float] = []
	for i in rooms.size():
		weights.append(expected[i] - int(expected[i]) + randf() * 0.02)  # 加一点随机扰动
	
	while remaining > 0:
		var total_weight = 0.0
		for w in weights:
			total_weight += max(w, 0.0)  # 防止负数
		
		if total_weight <= 0:
			break
		
		var r = randf() * total_weight
		var cumulative = 0.0
		
		for i in rooms.size():
			cumulative += max(weights[i], 0.0)
			if r <= cumulative:
				allocated[i] += 1
				remaining -= 1
				# 降低该房间后续被选概率，避免过度集中
				weights[i] *= 0.7
				break
	
	return allocated

# 在指定房间内随机取一个地板点（用于生成）
func _get_random_floor_in_room(room_rect: Rect2i) -> Vector2i:
	var attempts = 0
	while attempts < 50:
		var x = randi_range(room_rect.position.x, room_rect.position.x + room_rect.size.x - 1)
		var y = randi_range(room_rect.position.y, room_rect.position.y + room_rect.size.y - 1)
		if x >= 0 and x < map_width and y >= 0 and y < map_height and grid[y][x] == 1:
			var pos = Vector2i(x, y)
			if not used_positions.has(str(x) + "," + str(y)):
				return pos
		attempts += 1
	return Vector2i(-1, -1)  # 找不到

# 放置怪物（绑定房间边界）
func _place_enemy(room_rect: Rect2i, pos: Vector2i) -> bool:
	var key = str(pos.x) + "," + str(pos.y)
	if used_positions.has(key):
		return false
	
	var enemy = enemy_scene.instantiate() as Node2D
	if enemy:
		enemy.position = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
		
		# 给怪物绑定它的专属房间边界（像素单位）
		enemy.my_room_bounds = Rect2(
			room_rect.position * tile_size,
			room_rect.size * tile_size
		)
		
		add_child(enemy)
		used_positions[key] = true
		return true
	return false

func initialize(grid_ref: Array, tile_size_val: int, w: int, h: int, rooms_ref: Array[Dictionary]):
	grid = grid_ref
	rooms = rooms_ref
	tile_size = tile_size_val
	map_width = w
	map_height = h
