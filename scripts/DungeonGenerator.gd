# scripts/DungeonGenerator.gd
extends Node2D
class_name DungeonGenerator

@export var map_width: int = 80
@export var map_height: int = 60
@export var tile_size: int = 16

var grid: Array = []         # 2D网格：0=墙，1=地板
var tilemap: TileMap

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
	tilemap = TileMap.new()
	tilemap.name = "TileMap"
	add_child(tilemap)
	
	var tileset = TileSet.new()
	tilemap.tile_set = tileset
	
	# 地板（绿色）
	var floor_source = TileSetAtlasSource.new()
	var floor_texture = create_colored_texture(Color(0.2, 0.6, 0.2))
	floor_source.texture = floor_texture
	floor_source.texture_region_size = Vector2i(tile_size, tile_size)
	floor_source.create_tile(Vector2i(0, 0))
	tileset.add_source(floor_source, 0)
	
	# 墙（灰色）
	var wall_source = TileSetAtlasSource.new()
	var wall_texture = create_colored_texture(Color(0.4, 0.4, 0.4))
	wall_source.texture = wall_texture
	wall_source.texture_region_size = Vector2i(tile_size, tile_size)
	wall_source.create_tile(Vector2i(0, 0))
	tileset.add_source(wall_source, 1)

# 绘制整个地牢
func draw_dungeon():
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			if grid[y][x] == 1:
				tilemap.set_cell(0, pos, 0, Vector2i(0, 0))   # 地板
			else:
				tilemap.set_cell(0, pos, 1, Vector2i(0, 0))   # 墙

# 创建纯色纹理
func create_colored_texture(color: Color) -> ImageTexture:
	var img = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

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
	var player_scene = load("res://scenes/player.tscn")
	if player_scene == null:
		printerr("错误：找不到 res://scenes/player.tscn")
		return
	
	var player = player_scene.instantiate()
	player.global_position = find_random_floor_position()
	add_child(player)
	print("✅ 玩家已创建！位置:", player.global_position)
