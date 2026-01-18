# scripts/EnemySpawner.gd (房间优先 + 走廊0怪物 + 每个怪物绑定房间)
extends Node
class_name EnemySpawner

@export var enemy_scene: PackedScene # 编辑器拖入 enemy.tscn
@export var min_enemies: int = 18
@export var max_enemies: int = 40
@export var grid_divisions: int = 7   # 分块数（房间内均匀）

var grid: Array = []
var rooms: Array[Dictionary] = []     # 房间数据
var tile_size: int = 16
var map_width: int = 80
var map_height: int = 60
var used_positions: Dictionary = {}

func spawn_enemies(custom_count: int = -1) -> void:
	used_positions.clear()
	
	var count = custom_count if custom_count >= 0 else randi_range(min_enemies, max_enemies)
	
	if enemy_scene == null:
		printerr("EnemySpawner: 敌人场景未设置！")
		return
	
	if rooms.is_empty():
		printerr("EnemySpawner: 房间数据未设置！请在initialize传入rooms")
		return
	
	print("🛡️ 房间优先生成怪物：目标=", count, "，房间数=", rooms.size(), "，分块=", grid_divisions)
	
	var spawned = _spawn_in_rooms_only(count)
	print("✅ 房间内怪物生成完成：", spawned, "个 (走廊0%)")

# 只在房间内均匀生成（核心算法）
func _spawn_in_rooms_only(target_count: int) -> int:
	var spawned = 0
	
	# 步骤1：每个房间强制均匀分块生成
	for room_idx in range(rooms.size()):
		var room = rooms[room_idx]
		var rect = room.rect
		var room_rect = Rect2i(
			round(rect.position.x),
			round(rect.position.y),
			round(rect.size.x),
			round(rect.size.y)
		)
		
		# 房间内分小块（根据房间大小动态分块）
		var room_blocks_x = max(1, int(room_rect.size.x / (map_width / grid_divisions)))
		var room_blocks_y = max(1, int(room_rect.size.y / (map_height / grid_divisions)))
		
		for rx in range(room_blocks_x):
			for ry in range(room_blocks_y):
				var bx_start = room_rect.position.x + rx * (room_rect.size.x / room_blocks_x)
				var by_start = room_rect.position.y + ry * (room_rect.size.y / room_blocks_y)
				var b_w = room_rect.size.x / room_blocks_x
				var b_h = room_rect.size.y / room_blocks_y
				
				var room_block_floors = _get_room_floors_in_block(bx_start, by_start, b_w, b_h, room_rect)
				if room_block_floors.is_empty():
					continue
				
				# 随机选1个
				var pos = room_block_floors[randi() % room_block_floors.size()]
				if _place_enemy(room_rect, pos):  # 关键：传入 room_rect
					spawned += 1
					if spawned >= target_count:
						return spawned
	
	# 步骤2：补足剩余（全房间随机）
	var remaining = target_count - spawned
	while remaining > 0:
		var all_room_floors = _collect_all_room_floors()
		if all_room_floors.is_empty():
			break
		var pos = all_room_floors[randi() % all_room_floors.size()]
		# 补足时随机选一个房间的 rect（这里简单取第一个有地板的房间）
		var random_room_rect = _get_random_room_rect_with_floors()
		if _place_enemy(random_room_rect, pos):
			spawned += 1
			remaining -= 1
	
	return spawned

# 房间块内地板点（只在指定房间内）
func _get_room_floors_in_block(start_x: int, start_y: int, block_w: int, block_h: int, room_rect: Rect2i) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for x in range(start_x, min(start_x + block_w, map_width)):
		for y in range(start_y, min(start_y + block_h, map_height)):
			var pos = Vector2i(x, y)
			if grid[y][x] == 1 and room_rect.has_point(pos):
				floors.append(pos)
	return floors

# 收集全房间地板（补足用）
func _collect_all_room_floors() -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for room in rooms:
		var rect_i = Rect2i(
			round(room.rect.position.x),
			round(room.rect.position.y),
			round(room.rect.size.x),
			round(room.rect.size.y)
		)
		for x in range(rect_i.position.x, rect_i.position.x + rect_i.size.x):
			for y in range(rect_i.position.y, rect_i.position.y + rect_i.size.y):
				if x >= 0 and x < map_width and y >= 0 and y < map_height and grid[y][x] == 1:
					var key = str(x) + "," + str(y)
					if not used_positions.has(key):
						floors.append(Vector2i(x, y))
	return floors

# 随机选一个有地板的房间 rect（补足用）
func _get_random_room_rect_with_floors() -> Rect2i:
	for room in rooms:
		var rect_i = Rect2i(
			round(room.rect.position.x),
			round(room.rect.position.y),
			round(room.rect.size.x),
			round(room.rect.size.y)
		)
		if not _get_room_floors_in_block(rect_i.position.x, rect_i.position.y, rect_i.size.x, rect_i.size.y, rect_i).is_empty():
			return rect_i
	return Rect2i()  # 空

# 放置怪物（绑定房间边界）
func _place_enemy(room_rect: Rect2i, pos: Vector2i) -> bool:
	var key = str(pos.x) + "," + str(pos.y)
	if used_positions.has(key):
		return false
	
	var enemy = enemy_scene.instantiate() as Node2D
	if enemy:
		enemy.position = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
		
		# 关键：给怪物设置它的专属房间边界（像素单位）
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
