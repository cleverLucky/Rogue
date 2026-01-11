# scripts/DungeonGenerator.gd
extends Node2D
class_name DungeonGenerator

@export var map_width: int = 80
@export var map_height: int = 60
@export var tile_size: int = 16

var grid: Array = []         # 2D网格：0=墙，1=地板
var tilemap: TileMapLayer


@export var tileset_path: String = "res://assets/dungeon_tileset.tres"
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS     := Vector2i(0, 5)
const DUNGEON_SOURCE_ID := 1
const FLOOR_ATLAS := Vector2i(0, 5)

func _ready():
	generate_dungeon()

func generate_dungeon():
	print("🚀 开始生成地牢...")
	
	# 1. 初始化全墙网格
	grid = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(0)  # 0=墙
		grid.append(row)
	
	# 2. 生成5个随机房间
	for i in range(5):
		create_random_room()
	
	# 3. 连接房间
	connect_rooms()
	
	# 4. 创建并绘制 TileMap
	create_tilemap()
	draw_dungeon()
	
	# 5. 居中相机
	center_camera()
	
	# 6. 生成玩家（重要！放在这里）
	create_player()
	
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
		push_error("無法載入 TileSet！請檢查路徑：" + tileset_path)
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

# 随机找一个地板位置（玩家出生点）
func find_random_floor_position() -> Vector2:
	for i in range(100):
		var x = randi_range(1, map_width - 2)
		var y = randi_range(1, map_height - 2)
		if grid[y][x] == 1:
			return Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size / 2.0)
	# 找不到就返回中心
	return Vector2(map_width * tile_size / 2.0, map_height * tile_size / 2.0)

# 生成玩家（使用预制场景）
func create_player():
	var path = "res://scenes/player.tscn"  # ← 先确认这个路径是否正确
	
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
