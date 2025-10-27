extends StaticBody3D

const cell_w: float = 2 		# cell width in metres
const cell_h: float = 2.5		# cell height in metres

@onready var _occluder_instance: OccluderInstance3D = $OccluderInstance3D
@onready var _occluder_vertices = PackedVector3Array()
@onready var _occluder_indices = PackedInt32Array()

@onready var _shader = preload("res://scenes/shader/wall_drawer.gdshader")
@onready var _shader_material = preload("res://scenes/shader/wall_drawer_shader.tres")

var _wall_textures: Array[CompressedTexture2D] = []
var _detail_textures: Array[CompressedTexture2D] = []
var _window_textures: Array[CompressedTexture2D] = []
var _door_textures: Array[CompressedTexture2D] = []
var _rooftop_textures: Array[CompressedTexture2D] = []
var _rooftop_materials: Array[StandardMaterial3D] = []

# Recursively loads the textures found in the directory specified
func load_textures(dir_path: String):
	var textures: Array[CompressedTexture2D] = []
	var dir = DirAccess.open(dir_path)
	dir.list_dir_begin()
	for filename: String in dir.get_files():
		if filename.ends_with(".png"):
			textures.push_back(load(dir_path + filename))
	dir.list_dir_end()
	return textures

# Generates a texture material
func generate_material(texture: CompressedTexture2D):
	var material = StandardMaterial3D.new()
	material.uv1_triplanar = true
	material.metallic_specular = 0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.albedo_texture = texture
	return material

func _ready():
	# Load the textures to be used by the shader
	_wall_textures		= load_textures("res://assets/textures/wall/")
	_detail_textures	= load_textures("res://assets/textures/detail/")
	_window_textures	= load_textures("res://assets/textures/window/")
	_door_textures		= load_textures("res://assets/textures/door/")
	_rooftop_textures	= load_textures("res://assets/textures/rooftop/")
	
	# Generate a material for each texture file found on the "rooftop" directory
	for rooftop_texture: CompressedTexture2D in _rooftop_textures:
		_rooftop_materials.push_back(generate_material(rooftop_texture))
	
	generate_city_block(2,3,1,1,3,2,4,2,4)
	
func reset_city_block():
	for child: Node in get_children():
		if child is CollisionShape3D || child is MeshInstance3D:
			child.queue_free()

func generate_city_block(
		buildings_x: int, 			# total buildings in X axis
		buildings_z: int, 			# total buildings in Z axis
		spacing_x: int,				# spacing between buldings in the X axis
		spacing_z: int, 			# spacing between buldings in the Z axis
		bulding_cols_z: int,		# max amount of columns in z axis
		bulding_min_cols_x: int,	# min amount of columns in x axis
		bulding_max_cols_x: int,	# max amount of columns in x axis
		bulding_min_floors: int,	# min amount of rows (floors)
		bulding_max_floors: int		# max amount of rows (floors)
	):
		
	_occluder_vertices = PackedVector3Array()
	_occluder_indices = PackedInt32Array()
	
	# Offsetting the city block to be centered
	var alleys_space_z = spacing_z * (buildings_z - 1)
	var alleys_space_x = spacing_x * (buildings_x - 1)
	var buildings_space_z = cell_w * bulding_cols_z * buildings_z
	var buildings_space_x = cell_w * (bulding_min_cols_x+bulding_max_cols_x)/2 * buildings_x
	var pos_z = (alleys_space_z + buildings_space_z) / -2 + bulding_cols_z 
	var pos_x = (alleys_space_x + buildings_space_x) / -2 - spacing_x
	
	for j in buildings_z:
		var pos = Vector3(pos_x,0,pos_z)
		var cols_x = 0
		var cols_z = 0
		var floors = 0
		for i in buildings_x:
			pos.x += cols_x
			cols_x = randi_range(bulding_min_cols_x,bulding_max_cols_x)
			cols_z = bulding_cols_z
			floors = randi_range(bulding_min_floors,bulding_max_floors)
			pos.x += cols_x + spacing_x
			var x_scale:float = cols_x * cell_w
			var y_scale:float = floors * cell_h
			var z_scale:float = cols_z * cell_w
			var shader_materials = get_shader_materials(x_scale, y_scale, z_scale,
				_wall_textures[randi() % _wall_textures.size()],
				_detail_textures[randi() % _detail_textures.size()],
				_window_textures[randi() % _window_textures.size()],
				_door_textures[randi() % _door_textures.size()]
			)
			generate_building(x_scale,y_scale,z_scale,pos,shader_materials)
		pos_z += bulding_cols_z * cell_w + spacing_z
	
	calculate_occluder_indices()
	

# (OPTIONAL)
# Generate an occluder to hide the buildings that are not visible
# Reduces impact on GPU performance, at the cost of CPU calculations
func calculate_occluder_indices():
	for i in range(0,_occluder_vertices.size(),8):
		_occluder_indices += PackedInt32Array([
			# First face
			0+i, 1+i, 3+i,
			3+i, 2+i, 0+i,
			# Second face
			2+i, 3+i, 5+i,
			5+i, 4+i, 2+i,
			# Third face
			4+i, 5+i, 7+i,
			7+i, 6+i, 4+i,
			# Fourth face
			6+i, 7+i, 1+i,
			1+i, 0+i, 6+i,
			# Top face
			0+i,2+i,4+i,
			6+i,0+i,4+i,
			# Bottom face
			1+i,3+i,5+i,
			7+i,1+i,5+i
		])
	_occluder_instance.occluder.set_arrays(_occluder_vertices,_occluder_indices)

# Blends the wall, window and door textures
func get_shader_materials(
		scale_x: float,
		scale_y: float,
		scale_z: float,
		wall_texture: Texture2D,
		detail_texture: Texture2D,
		window_texture: Texture2D,
		door_texture: Texture2D
	):
	# Generate an unique shader material for each wall of the building
	# NOTE: Not sure how performant it is, since there are 4 unique shader 
	# materials per buillding
	var shader_materials: Array[ShaderMaterial] = [
		_shader_material.duplicate(),
		_shader_material.duplicate(),
		_shader_material.duplicate(),
		_shader_material.duplicate(),
	]
	
	for i in shader_materials.size():
		var total_w
		if i % 2 != 0: total_w = scale_x
		else: total_w = scale_z
		shader_materials[i].shader = _shader
		
		# Setting up shader parameters
		shader_materials[i].set_shader_parameter("wall_texture",wall_texture)
		shader_materials[i].set_shader_parameter("detail_texture",detail_texture)
		shader_materials[i].set_shader_parameter("window_texture",window_texture)
		shader_materials[i].set_shader_parameter("door_texture",door_texture)
		shader_materials[i].set_shader_parameter("cell_w",cell_w)
		shader_materials[i].set_shader_parameter("cell_h",cell_h)
		shader_materials[i].set_shader_parameter("total_w",total_w)
		shader_materials[i].set_shader_parameter("total_h",scale_y)
		
		# If it is the last face of the building, it allows drawing it a door
		if i == 3: shader_materials[i].set_shader_parameter("draw_door",true)
	return shader_materials

func cross_edges(vtx_1: Vector3,vtx_2: Vector3,vtx_3: Vector3):
	return vtx_1.direction_to(vtx_2).cross(vtx_2.direction_to(vtx_3)) * -1

func generate_building(
		x_scale: float, 
		y_scale: float, 
		z_scale: float, 
		pos: Vector3, 
		shader_materials: Array[ShaderMaterial]
	):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = ArrayMesh.new()
	var mesh_data_arrays = []
	mesh_data_arrays.resize(ArrayMesh.ARRAY_MAX)
	var indices = PackedInt32Array([
		0,1,2, # First triangle
		0,2,3  # Second triangle
	])
	var tex_uvs = PackedVector2Array([
		Vector2(0,0), # TL
		Vector2(1,0), # TR
		Vector2(1,1), # BR
		Vector2(0,1), # BL
	])
	var v = Vector3.ZERO
	var face = PackedVector3Array([v,v,v,v])
	var normals = PackedVector3Array([v,v,v,v])
	
	var top_l = Vector3(-x_scale/2, y_scale, z_scale/2) + pos
	var top_r = Vector3(x_scale/2, y_scale, z_scale/2) + pos
	var bot_r = Vector3(x_scale/2, 0, z_scale/2) + pos
	var bot_l = Vector3(-x_scale/2, 0, z_scale/2) + pos
	
	mesh_data_arrays[ArrayMesh.ARRAY_VERTEX] = face
	mesh_data_arrays[ArrayMesh.ARRAY_INDEX] = indices
	mesh_data_arrays[ArrayMesh.ARRAY_TEX_UV] = tex_uvs
	mesh_data_arrays[ArrayMesh.ARRAY_NORMAL] = normals
	for i in 5:
		if i < 4: # Drawing the side faces
			var displacement = cross_edges(top_l,top_r,bot_r)
			if i % 2 == 0: displacement *= z_scale
			else: displacement *= x_scale
			top_r = top_l
			bot_r = bot_l
			top_l = top_l - displacement
			bot_l = bot_l - displacement
			_occluder_vertices += PackedVector3Array([top_l,bot_l])
		else: # Drawing the top face (rooftop)
			top_l.z -= (top_l.z * 2 - pos.z * 2)
			top_r.z -= (top_r.z * 2 - pos.z * 2)
			bot_l.y = top_l.y
			bot_r.y = top_r.y
		face[0] = top_l; face[1] = top_r; face[2] = bot_r; face[3] = bot_l
		
		var normal = cross_edges(top_l,top_r,bot_r)
		for n in normals.size(): 
			normals[n] = normal
		mesh_instance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data_arrays)
		
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = mesh_instance.mesh.create_convex_shape()
	
	for i in 4: mesh_instance.mesh.surface_set_material(i,shader_materials[i])
	mesh_instance.mesh.surface_set_material(4,_rooftop_materials[randi() % _rooftop_materials.size()])
	
	mesh_instance.lod_bias = 0.05
	mesh_instance.visibility_range_end = 300
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	#mesh_instance.visibility_range_end_margin = 150
	#mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	#mesh_instance.cast_shadow = false
	
	add_child(mesh_instance)
	add_child(collision_shape)
