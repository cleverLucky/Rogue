# scripts/DungeonCore.gd
# TinyKeep 风格地牢生成核心逻辑（独立脚本）
class_name DungeonCore
extends RefCounted

var map_width: int
var map_height: int
var num_rooms: int = 25
var separation_iterations: int = 1000
var separation_force: float = 0.5
var main_room_threshold: float = 0.7
var extra_edge_ratio: float = 0.15
var corridor_width: int = 3

var grid: Array = []
var rooms: Array[Dictionary] = []  # [{'id':int, 'rect':Rect2, 'center':Vector2, 'area':float}]

# 主生成函数：返回生成的网格（0=墙，1=地板）
func generate_grid(width: int, height: int) -> Array:
	map_width = width
	map_height = height
	
	print("🚀 开始生成 TinyKeep 风格地牢...")
	
	# 1. 初始化全墙网格
	grid = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(0)  # 0=墙
		grid.append(row)
	
	# generate_and_separate_rooms()

	generate_starting_room()
	generate_and_separate_rooms()

	
	# 3. 雕刻所有房间到网格
	carve_all_rooms()
	
	# 4. 选择主房间并计算 Delaunay + MST + 额外边
	var main_rooms = select_main_rooms()
	if main_rooms.size() < 2:
		print("⚠️ 主房间太少，使用简单连接...")
		connect_rooms_simple()
	else:
		print("🔗 计算 Delaunay 三角剖分和 MST...")
		var mst_edges = compute_mst(main_rooms)
		var all_edges = get_delaunay_edges(main_rooms)
		var extra_edges = get_extra_edges(all_edges, mst_edges, extra_edge_ratio)
		var corridor_edges = mst_edges + extra_edges
		build_corridors(main_rooms, corridor_edges)
	
	print("🎉 地牢网格生成完成！房间数: ", rooms.size())
	return grid

# 生成初始房间（圆内均匀分布）
func generate_and_separate_rooms():
	# 注意：此时 rooms 里已经有安全屋（id=-1）了

	# 读取安全屋的实际位置（更可靠，不硬编码）
	var safe_room = rooms[0]  # 因为 insert(0, ...)
	var safe_top_y    = safe_room.rect.position.y          # 安全屋顶部 y（较小值）
	var safe_bottom_y = safe_room.rect.end.y               # 安全屋底部 y（较大值）

	# 普通房间允许的 y 范围：地图顶部 → 安全屋顶部上方留空隙
	var buffer = 10.0  # 安全屋上方留 10 格缓冲，避免贴太近
	var min_y_for_rooms = 5.0                          # 顶部留墙
	var max_y_for_rooms = safe_top_y - buffer          # 最高到安全屋顶部 - buffer

	# 防止区域太小（极端小地图情况下）
	if max_y_for_rooms - min_y_for_rooms < 30:
		max_y_for_rooms = map_height * 0.45
		print("警告：安全屋上方空间不足，使用地图上半部作为限制")

	var map_center_x = map_width / 2.0

	for i in range(num_rooms):
		var room_w = randi_range(6, 15)
		var room_h = randi_range(4, 12)
		
		# x：全宽随机，但稍向中间靠拢
		var center_x = map_center_x + randf_range(-map_width * 0.42, map_width * 0.42)
		
		# y：强制在上方区域，且考虑房间自身高度不越界
		var half_h = room_h / 2.0
		var center_y = randf_range(
			min_y_for_rooms + half_h,
			max_y_for_rooms - half_h
		)
		
		var center = Vector2(center_x, center_y)
		var rect = Rect2(
			center - Vector2(room_w / 2.0, room_h / 2.0),
			Vector2(room_w, room_h)
		)
		
		var room = {
			'id': i + 100,   # 随便给个正数就好，区分开即可
			'rect': rect,
			'center': center,
			'area': room_w * room_h
		}
		rooms.append(room)

	# 开始分离（包含安全屋）
	separate_rooms()

# 圆内均匀随机点
func random_point_in_circle(radius: float) -> Vector2:
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	return Vector2(cos(angle) * r, sin(angle) * r)

# 分离房间（物理模拟）
func separate_rooms():
	var moved = true
	var iter = 0
	while moved and iter < separation_iterations:
		moved = false
		iter += 1
		
		for i in range(rooms.size()):
			for j in range(i + 1, rooms.size()):
				var roomA = rooms[i]
				var roomB = rooms[j]
				
				if roomA.rect.intersects(roomB.rect):
					# 判断哪个是安全屋
					var safe = null
					var other = null
					if roomA.has("is_starting_room") and roomA.is_starting_room:
						safe = roomA
						other = roomB
					elif roomB.has("is_starting_room") and roomB.is_starting_room:
						safe = roomB
						other = roomA
					
					var dx = roomB.center.x - roomA.center.x
					var dy = roomB.center.y - roomA.center.y
					var dist = max(0.001, sqrt(dx*dx + dy*dy))
					
					var force_mag = separation_force * 1.5   # 对安全屋加大推力
					
					dx /= dist
					dy /= dist
					
					if safe != null:
						# 只推 other，不动安全屋
						other.center.x += dx * force_mag * 1.5
						other.center.y += dy * force_mag * 1.5
						other.rect.position = other.center - other.rect.size * 0.5
					else:
						# 普通房间互推
						roomA.center.x -= dx * force_mag
						roomA.center.y -= dy * force_mag
						roomB.center.x += dx * force_mag
						roomB.center.y += dy * force_mag
						roomA.rect.position = roomA.center - roomA.rect.size * 0.5
						roomB.rect.position = roomB.center - roomB.rect.size * 0.5
					
					moved = true
	
	# 在 separate_rooms() 最后的 clamp 循环中
	for room in rooms:
		if room.has("is_starting_room") and room.is_starting_room:
			# 安全屋位置不允许动
			continue
		
		room.rect.position.x = round(room.rect.position.x)
		room.rect.position.y = round(room.rect.position.y)
		room.center.x = room.rect.position.x + room.rect.size.x * 0.5
		room.center.y = room.rect.position.y + room.rect.size.y * 0.5
		
		# clamp（普通房间）
		room.rect.position.x = max(1.0, min(room.rect.position.x, map_width - room.rect.size.x - 1))
		room.rect.position.y = max(1.0, min(room.rect.position.y, map_height - room.rect.size.y - 1))
		
		room.center.x = room.rect.position.x + room.rect.size.x * 0.5
		room.center.y = room.rect.position.y + room.rect.size.y * 0.5


# 雕刻所有房间
func carve_all_rooms():
	for room in rooms:
		var rect_i = Rect2i(room.rect.position.round(), room.rect.size.round())
		for x in range(rect_i.position.x, rect_i.position.x + rect_i.size.x):
			for y in range(rect_i.position.y, rect_i.position.y + rect_i.size.y):
				if x >= 0 and x < map_width and y >= 0 and y < map_height:
					grid[y][x] = 1

# 选择主房间（较大房间）
func select_main_rooms() -> Array[Dictionary]:
	var avg_area = 0.0
	for room in rooms:
		avg_area += room.area
	avg_area /= rooms.size()
	
	var main_rooms_local: Array[Dictionary] = []
	for room in rooms:
		if room.area > avg_area * main_room_threshold:
			main_rooms_local.append(room)
	
	return main_rooms_local

# ─────────────── Delaunay 三角剖分 ───────────────
func get_delaunay_edges(main_rooms: Array[Dictionary]) -> Array[Dictionary]:
	var centers: PackedVector2Array = []
	for room in main_rooms:
		centers.append(room.center)
	
	var triangles = Geometry2D.triangulate_delaunay(centers)
	if triangles.is_empty():
		print("⚠️ Delaunay 三角剖分失败，返回空边集")
		return []
	
	var edge_dict: Dictionary = {}
	for i in range(0, triangles.size(), 3):
		var a = triangles[i]
		var b = triangles[i + 1]
		var c = triangles[i + 2]
		
		_add_unique_edge(edge_dict, a, b, centers)
		_add_unique_edge(edge_dict, b, c, centers)
		_add_unique_edge(edge_dict, c, a, centers)
	
	var edges: Array[Dictionary] = []
	for key in edge_dict:
		var parts = key.split(",")
		var u = int(parts[0])
		var v = int(parts[1])
		var w = edge_dict[key]
		edges.append({'u': u, 'v': v, 'w': w})
	
	return edges

func _add_unique_edge(edge_dict: Dictionary, a: int, b: int, centers: PackedVector2Array):
	var u = mini(a, b)
	var v = maxi(a, b)
	var key = str(u) + "," + str(v)
	var dist = centers[a].distance_to(centers[b])
	if not edge_dict.has(key):
		edge_dict[key] = dist

# ─────────────── 最小生成树 (Kruskal) ───────────────
func compute_mst(main_rooms: Array[Dictionary]) -> Array[Dictionary]:
	var n = main_rooms.size()
	var all_edges = get_delaunay_edges(main_rooms)
	
	all_edges.sort_custom(func(a, b): return a.w < b.w)
	
	var parent: Array[int] = []
	var rank: Array[int] = []
	for i in range(n):
		parent.append(i)
		rank.append(0)
	
	var mst_edges: Array[Dictionary] = []
	for edge in all_edges:
		var pu = _find(parent, edge.u)
		var pv = _find(parent, edge.v)
		if pu != pv:
			_union(parent, rank, pu, pv)
			mst_edges.append(edge)
	
	return mst_edges

func _find(parent: Array[int], x: int) -> int:
	if parent[x] != x:
		parent[x] = _find(parent, parent[x])
	return parent[x]

func _union(parent: Array[int], rank: Array[int], x: int, y: int):
	if rank[x] > rank[y]:
		parent[y] = x
	elif rank[x] < rank[y]:
		parent[x] = y
	else:
		parent[y] = x
		rank[x] += 1

# ─────────────── 添加额外边（创建循环） ───────────────
func get_extra_edges(all_edges: Array[Dictionary], mst_edges: Array[Dictionary], ratio: float) -> Array[Dictionary]:
	var mst_set: Dictionary = {}
	for edge in mst_edges:
		var key = str(mini(edge.u, edge.v)) + "," + str(maxi(edge.u, edge.v))
		mst_set[key] = true
	
	var extra: Array[Dictionary] = []
	var num_extra = int(all_edges.size() * ratio)
	all_edges.shuffle()
	
	for edge in all_edges:
		var key = str(mini(edge.u, edge.v)) + "," + str(maxi(edge.u, edge.v))
		if not mst_set.has(key) and extra.size() < num_extra:
			extra.append(edge)
	
	return extra

# ─────────────── 构建走廊 ───────────────
func build_corridors(main_rooms: Array[Dictionary], edges: Array[Dictionary]):
	for edge in edges:
		var p1 = main_rooms[edge.u].center
		var p2 = main_rooms[edge.v].center
		dig_l_shaped_corridor(p1, p2)

func dig_l_shaped_corridor(p1: Vector2, p2: Vector2):
	var cx1 = round(p1.x)
	var cy1 = round(p1.y)
	var cx2 = round(p2.x)
	var cy2 = round(p2.y)
	
	# 水平段
	for x in range(mini(cx1, cx2), maxi(cx1, cx2) + 1):
		for off in range(-corridor_width / 2, corridor_width / 2 + 1):
			set_grid_tile(x, int(cy1) + off)
	
	# 垂直段
	for y in range(mini(cy1, cy2), maxi(cy1, cy2) + 1):
		for off in range(-corridor_width / 2, corridor_width / 2 + 1):
			set_grid_tile(int(cx2) + off, y)

# 简单回退连接
func connect_rooms_simple():
	var floors: Array[Vector2i] = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] == 1:
				floors.append(Vector2i(x, y))
	
	for i in range(5):
		if floors.size() < 2:
			break
		var start = floors[randi() % floors.size()]
		var end = floors[randi() % floors.size()]
		dig_tunnel_simple(start, end)

func dig_tunnel_simple(start: Vector2i, end: Vector2i):
	for x in range(mini(start.x, end.x), maxi(start.x, end.x) + 1):
		set_grid_tile(x, start.y)
	for y in range(mini(start.y, end.y), maxi(start.y, end.y) + 1):
		set_grid_tile(end.x, y)

func set_grid_tile(x: int, y: int):
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		grid[y][x] = 1

func get_rooms() -> Array[Dictionary]:
	return rooms

# 生成固定起始安全室（最下面，水平居中）
func generate_starting_room():
	# 固定大小（可调）
	var start_w = 12  # 宽度（格子数）
	var start_h = 10   # 高度（格子数）
	
	# 位置：最底部，水平居中，向上留2格墙
	var start_x = (map_width - start_w) / 2.0  # 水平居中
	var start_y = map_height - start_h - 2     # 最下面，留2格墙边距
	
	var start_rect = Rect2(start_x, start_y, start_w, start_h)
	var start_room = {
		'id': -1,  # 特殊 ID
		'rect': start_rect,
		'center': start_rect.position + start_rect.size * 0.5,
		'area': start_w * start_h,
		'is_starting_room': true  # 标记：不生成怪物
	}
	
	# 插入到 rooms 列表首位（方便后续过滤）
	rooms.insert(0, start_room)
	
	# 立即雕刻到 grid（确保先生成）
	var rect_i = Rect2i(start_rect.position.round(), start_rect.size.round())
	for x in range(rect_i.position.x, rect_i.position.x + rect_i.size.x):
		for y in range(rect_i.position.y, rect_i.position.y + rect_i.size.y):
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				grid[y][x] = 1
	
	print("安全起始房间生成：最底部中央，位置(", start_x, ",", start_y, "), 大小(", start_w, "x", start_h, ")")
	print("安全屋 rooms 数据: id=", start_room.id, ", is_starting_room=", start_room.is_starting_room)
