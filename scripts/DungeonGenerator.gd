# scripts/DungeonGenerator.gd
extends Node2D
class_name DungeonGenerator

@export var map_width: int = 80
@export var map_height: int = 60
@export var tile_size: int = 16

@export var enemy_scene: PackedScene
@export var navigation_region: NavigationRegion2D

var dungeon_core: DungeonCore

var grid: Array = []         # 2D网格：0=墙，1=地板
@export var tilemap: TileMapLayer


@export var tileset_path: String = "res://assets/dungeon_tileset.tres"
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS     := Vector2i(0, 5)
const DUNGEON_SOURCE_ID := 1
const FLOOR_ATLAS := Vector2i(0, 5)

func _ready():
	generate_dungeon()

func generate_dungeon():
	print("🚀 开始生成地牢...")
	
	# 1. 创建核心生成器实例
	dungeon_core = DungeonCore.new()
	
	# 可选：在这里修改 DungeonCore 的参数（如果需要覆盖默认值）
	# dungeon_core.num_rooms = 30
	# dungeon_core.corridor_width = 4
	# dungeon_core.extra_edge_ratio = 0.2
	# dungeon_core.separation_force = 0.8
	
	# 2. 使用 DungeonCore 生成网格
	grid = dungeon_core.generate_grid(map_width, map_height)
	# 4. 创建并绘制 TileMap
	create_tilemap()
	draw_dungeon()
	
	# 5. 居中相机
	center_camera()
	
	# 敌人生成部分（替换成这样，保持其他不变）
	var spawner = get_node_or_null("EnemySpawner")
	if spawner == null:
		spawner = Node.new()
		spawner.name = "EnemySpawner"
		spawner.set_script(load("res://scripts/EnemySpawner.gd"))
		add_child(spawner)

	# 初始化参数
	# spawner.initialize(grid, tile_size, map_width, map_height)
	spawner.initialize(grid, tile_size, map_width, map_height, dungeon_core.get_rooms())

	# 关键修复：强制加载敌人场景（防止编辑器没设置）
	spawner.enemy_scene = load("res://scenes/enemy.tscn")

	# 执行生成
	spawner.spawn_enemies()

	# 6. 生成玩家（重要！放在这里）
	create_player()
	
	setup_navigation()

	print("🎉 地牢生成完成！")

# 创建单个随机房间
func create_random_room():
	var room_w = randi_range(6, 12)
	var room_h = randi_range(4, 8)
	var room_x = randi_range(2, map_width - room_w - 2)
	var room_y = randi_range(2, map_height - room_h - 2)
	
	for x in range(room_x, room_x + room_w):
		for y in range(room_y, room_y + room_h):
			if x < map_width and y < map_height:
				grid[y][x] = 1

# 连接房间（随机挖3条L形隧道）
func connect_rooms():
	var floors = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] == 1:
				floors.append(Vector2i(x, y))
	
	for i in range(3):
		if floors.size() < 2:
			break
		var start = floors[randi() % floors.size()]
		var end = floors[randi() % floors.size()]
		dig_tunnel(start, end)

# 挖L形隧道
func dig_tunnel(start: Vector2i, end: Vector2i):
	# 先水平
	for x in range(min(start.x, end.x), max(start.x, end.x) + 1):
		if x < map_width:
			grid[start.y][x] = 1
	# 再垂直
	for y in range(min(start.y, end.y), max(start.y, end.y) + 1):
		if y < map_height:
			grid[y][end.x] = 1

# 创建TileMap和图集
func create_tilemap():
	tilemap = TileMapLayer.new()
	tilemap.name = "TileMapLayer"   # 建議改名，避免跟舊 TileMap 混淆
	add_child(tilemap)

	var tileset = load(tileset_path) as TileSet
	
	if tileset == null:
		push_error("无法载入 TileSet！请检查路径：" + tileset_path)
		push_error("1. 檔案是否存在？")
		push_error("2. 是否真的是 TileSet 資源？")
		push_error("3. 路徑大小寫是否正確？")
		return
	
	tilemap.tile_set = tileset
	print("成功載入 TileSet:", tileset_path)
	print("圖集來源數量:", tileset.get_source_count())


func draw_dungeon():
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			
			if grid[y][x] == 0:
				# 地板
				tilemap.set_cell(pos, DUNGEON_SOURCE_ID, FLOOR_ATLAS)
			else:
				# 牆壁（或外圍草地）
				tilemap.set_cell(pos, GRASS_SOURCE_ID, GRASS_ATLAS)  # 墙


# 居中相机
func center_camera():
	var camera = Camera2D.new()
	camera.name = "MainCamera"
	add_child(camera)
	camera.make_current()
	
	var map_center = Vector2(map_width * tile_size / 2.0, map_height * tile_size / 2.0)
	camera.position = map_center
	camera.zoom = Vector2(0.8, 0.8)

# 修改 find_random_floor_position()，优先用起始房间中心
func find_random_floor_position() -> Vector2:
	# 先检查是否有起始房间（id=-1）
	for room in dungeon_core.rooms:
		if room.get('is_starting_room', false):
			var center_x = room.center.x * tile_size + tile_size / 2.0
			var center_y = room.center.y * tile_size + tile_size / 2.0
			print("玩家优先出生在起始安全室中心")
			return Vector2(center_x, center_y)
	
	# 找不到就用随机地板（fallback）
	for i in range(200):
		var x = randi_range(1, map_width - 2)
		var y = randi_range(1, map_height - 2)
		if grid[y][x] == 1:
			return Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size / 2.0)
	
	# 极端情况：返回地图中心
	return Vector2(map_width * tile_size / 2.0, map_height * tile_size / 2.0)

	
# 生成玩家（使用预制场景）
func create_player():
	var path = "res://scenes/test_player.tscn"  # ← 先确认这个路径是否正确
	
	var player_scene = load(path)
	if player_scene == null:
		printerr("【严重错误】找不到玩家场景！")
		printerr("尝试加载的路径: " + path)
		printerr("请检查以下内容：")
		printerr("1. 文件是否存在？")
		printerr("2. 文件名大小写是否正确？（Godot 区分大小写）")
		printerr("3. 是否在 scenes 文件夹下？")
		
		# 自动打印 scenes 文件夹里所有文件，帮助你排查
		var dir = DirAccess.open("res://scenes")
		if dir:
			printerr("当前 res://scenes 文件夹内容：")
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir():
					printerr("  - " + file_name)
					file_name = dir.get_next()
				else:
					printerr("无法打开 res://scenes 文件夹！")
		
		return  # 直接返回，避免后续崩溃
	
	var player = player_scene.instantiate()
	if player == null:
		printerr("玩家场景加载成功，但 instantiate() 失败！可能是场景内部配置错误")
		return
	
	player.global_position = find_random_floor_position()
	add_child(player)
	print("✅ 玩家已创建！位置:", player.global_position)


func setup_navigation():
	# 确保 NavigationRegion2D 存在
	if navigation_region == null:
		navigation_region = NavigationRegion2D.new()
		navigation_region.name = "NavigationRegion2D"
		add_child(navigation_region)
	
	# 创建 NavigationPolygon
	var nav_polygon = NavigationPolygon.new()
	navigation_region.navigation_polygon = nav_polygon
	
	# 创建源几何数据
	var nav_source = NavigationMeshSourceGeometryData2D.new()
	
	# 添加所有地板作为可行走轮廓（高效方式：只加外轮廓 + 合并）
	# 这里用简单矩形轮廓方式（每个地板 tile 一个矩形）
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] == 1:  # 地板
				var outline = PackedVector2Array([
					Vector2(x * tile_size,     y * tile_size),
					Vector2((x+1) * tile_size, y * tile_size),
					Vector2((x+1) * tile_size, (y+1) * tile_size),
					Vector2(x * tile_size,     (y+1) * tile_size),
					Vector2(x * tile_size,     y * tile_size)  # 闭合轮廓
				])
				nav_source.add_traversable_outline(outline)
	
	# 重要：使用 NavigationServer2D 烘焙
	NavigationServer2D.bake_from_source_geometry_data(nav_polygon, nav_source, func(): 
		print("🧭 NavigationPolygon 烘焙完成！怪物可智能移动")
	)
	
	# 可选：设置烘焙参数（在 NavigationRegion2D Inspector 里也可以调）
	nav_polygon.agent_radius = 8.0  # 怪物半径
	nav_polygon.cell_size = 4.0     # 网格精度
