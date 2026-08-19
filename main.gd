extends Node3D

const TILE_SIZE := 1.65
const BUILDING_LIMIT := 36
const WALKER_COUNT := 12
const UPPER_ORDER_THRESHOLD := 12

var wood := Color("#9a5e3b")
var wood_dark := Color("#50342b")
var cream := Color("#f7d99b")
var grass := Color("#5f9c67")
var gold := Color("#f4b944")
var sky := Color("#f19b72")

var city_root: Node3D
var people_root: Node3D
var coins_root: Node3D
var building_count := 0
var activity := 18
var prosperity := 72
var elapsed := 0.0
var growth_clock := 0.0
var paused := false
var speed := 1.0
var speed_mode := 1
var growth_boost := 1.0
var chain_triggered := false
var chain_elapsed := 0.0
var status_label: Label
var activity_label: Label
var prosperity_label: Label
var growth_label: Label
var speed_label: Label
var progress_bar: ProgressBar
var walkers: Array[Node3D] = []
var walker_offsets: Array[float] = []
var coin_nodes: Array[Node3D] = []
var shockwaves: Array[Node3D] = []
var effect_nodes: Array[Node3D] = []
var flash_light: OmniLight3D
var boom_effect: Node3D
var spark_effect: GPUParticles3D

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_build_landscape()
	_build_square()
	_build_forge()
	_build_background()
	_build_people()
	_build_interface()
	_grow_city()

func _process(delta: float) -> void:
	if paused:
		return
	elapsed += delta * speed
	growth_clock += delta * speed * growth_boost
	_update_people()
	_update_coins()
	_update_chain_effects(delta * speed)
	if growth_clock > 4.5 and building_count < BUILDING_LIMIT:
		growth_clock = 0.0
		activity = mini(100, activity + randi_range(2, 7))
		prosperity = mini(100, prosperity + randi_range(1, 4))
		if not chain_triggered and building_count >= UPPER_ORDER_THRESHOLD and prosperity >= 80:
			_trigger_order_chain()
		_grow_city()
	_update_interface()

func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ffd2a6")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("#ffd19b")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(17, 17, 17)
	camera.rotation_degrees = Vector3(-35, 45, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0))

func _material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = scale
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, size: Vector3, material: Material, at: Vector3, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(parent, mesh, material, at)
	instance.rotation = rotation
	return instance

func _build_landscape() -> void:
	city_root = Node3D.new()
	city_root.name = "Ciudad_que_crece_sola"
	add_child(city_root)
	people_root = Node3D.new()
	add_child(people_root)
	coins_root = Node3D.new()
	add_child(coins_root)
	_box(self, Vector3(38, 0.25, 38), _material(Color("#356350")), Vector3(0, -0.25, 0))
	for x in range(-10, 11):
		for z in range(-10, 11):
			if (x + z) % 3 == 0:
				_box(self, Vector3(1.52, 0.06, 1.52), _material(grass.lightened(0.06)), Vector3(x * TILE_SIZE, 0, z * TILE_SIZE))
	var river := _box(self, Vector3(4.2, 0.08, 34), _material(Color("#5bacc0"), 0.35), Vector3(10.5, -0.05, 0), Vector3(0, -0.12, deg_to_rad(-8)))
	river.name = "Rio"
	for z in range(-10, 11, 3):
		_box(self, Vector3(0.45, 0.03, 0.08), _material(Color("#a7e0d0"), 0.2), Vector3(10.1, 0.02, z * 1.4), Vector3(0, -0.1, deg_to_rad(-8)))

func _build_square() -> void:
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_box(self, Vector3(0.18, 0.08, 2.2), _material(wood_dark), Vector3(cos(angle) * 2.0, 0.08, sin(angle) * 2.0), Vector3(0, -angle, 0))

func _build_forge() -> void:
	var forge := Node3D.new()
	forge.name = "Forja_Central"
	city_root.add_child(forge)
	_box(forge, Vector3(2.0, 0.55, 2.0), _material(wood_dark), Vector3(0, 0.3, 0))
	var fire := _mesh(forge, CylinderMesh.new(), _material(Color("#ff9d39"), 0.35), Vector3(0, 0.85, 0), Vector3(0.45, 0.45, 0.45))
	(fire.mesh as CylinderMesh).top_radius = 0.3
	var flame := _mesh(forge, SphereMesh.new(), _material(Color("#ffe28a"), 0.2), Vector3(0, 1.35, 0), Vector3(0.28, 0.6, 0.28))
	flame.name = "Llama"
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		_box(forge, Vector3(0.3, 0.55, 0.3), _material(wood), Vector3(cos(angle) * 1.0, 0.58, sin(angle) * 1.0))

func _build_background() -> void:
	for data in [[Vector3(-13, 1.7, -12), Vector3(8, 3, 5)], [Vector3(1, 1.2, -14), Vector3(10, 2, 4)], [Vector3(-15, 1.0, 7), Vector3(6, 2, 7)]]:
		_mesh(self, SphereMesh.new(), _material(Color("#66806a")), data[0], data[1])
	for data in [[Vector3(-8, 1.3, -8), 1.0], [Vector3(6, 1.0, -9), 0.8], [Vector3(-10, 1.0, 5), 0.85], [Vector3(8, 1.2, 7), 1.1]]:
		_create_tree(data[0], data[1])

func _create_tree(at: Vector3, size: float) -> void:
	var tree := Node3D.new()
	add_child(tree)
	_box(tree, Vector3(0.28, 1.4, 0.28) * size, _material(Color("#67452f")), at + Vector3(0, 0.7 * size, 0))
	_mesh(tree, SphereMesh.new(), _material(Color("#3f7653")), at + Vector3(0, 1.7 * size, 0), Vector3(1.0, 1.2, 1.0) * size)
	_mesh(tree, SphereMesh.new(), _material(Color("#6c9a5a")), at + Vector3(0.4, 1.85 * size, 0.1), Vector3(0.65, 0.75, 0.65) * size)

func _grow_city() -> void:
	if building_count >= BUILDING_LIMIT:
		return
	var ring := int(building_count / 8) + 1
	var slot := building_count % 8
	var angle := (TAU * float(slot) / 8.0) + ring * 0.38
	var radius := float(ring) * 2.25 + 1.8
	var upper_order := chain_triggered and building_count >= UPPER_ORDER_THRESHOLD
	_create_building(Vector3(cos(angle) * radius, 0, sin(angle) * radius), building_count % 3 == 1, upper_order)
	if prosperity >= 70 and building_count % 2 == 0:
		_spawn_coin(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	building_count += 1

func _spawn_coin(at: Vector3) -> void:
	if coin_nodes.size() >= 36:
		return
	var coin := Node3D.new()
	coin.position = at + Vector3(0, 1.0, 0)
	coins_root.add_child(coin)
	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.22
	coin_mesh.bottom_radius = 0.22
	coin_mesh.height = 0.08
	coin_mesh.radial_segments = 12
	_mesh(coin, coin_mesh, _material(gold, 0.28), Vector3.ZERO)
	coin.rotation_degrees = Vector3(0, 0, 22)
	var sign := Label3D.new()
	sign.text = "$"
	sign.font_size = 42
	sign.outline_size = 8
	sign.modulate = Color("#fff0b0")
	sign.position = Vector3(0, 0.28, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	coin.add_child(sign)
	coin_nodes.append(coin)

func _trigger_order_chain() -> void:
	chain_triggered = true
	chain_elapsed = 0.0
	growth_boost = 1.9
	activity = mini(100, activity + 18)
	prosperity = 100
	for i in range(4):
		_spawn_wave()
	for i in range(18):
		var angle := TAU * float(i) / 18.0
		_spawn_coin(Vector3(cos(angle) * (1.5 + i % 3), 0.15, sin(angle) * (1.5 + i % 3)))
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("#ffd86b")
	flash_light.light_energy = 9.0
	flash_light.omni_range = 8.0
	flash_light.position = Vector3(0, 1.2, 0)
	add_child(flash_light)
	boom_effect = Node3D.new()
	boom_effect.position = Vector3(0, 1.2, 0)
	add_child(boom_effect)
	var boom_mesh := SphereMesh.new()
	boom_mesh.radial_segments = 16
	boom_mesh.rings = 8
	var boom_material := _material(Color(1.0, 0.78, 0.3, 0.7), 0.2)
	boom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(boom_effect, boom_mesh, boom_material, Vector3.ZERO, Vector3(0.35, 0.35, 0.35))
	_spawn_spark_particles()

func _spawn_wave() -> void:
	var wave := Node3D.new()
	wave.position = Vector3(0, 0.12, 0)
	add_child(wave)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 8
	var ring_material := _material(Color(1.0, 0.78, 0.28, 0.88), 0.2)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(wave, ring, ring_material, Vector3.ZERO)
	shockwaves.append(wave)

func _spawn_spark_particles() -> void:
	spark_effect = GPUParticles3D.new()
	spark_effect.amount = 90
	spark_effect.lifetime = 2.2
	spark_effect.one_shot = true
	spark_effect.explosiveness = 0.95
	spark_effect.position = Vector3(0, 1.0, 0)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 1.0
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 4.0
	process_material.gravity = Vector3(0, -3.0, 0)
	spark_effect.process_material = process_material
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	spark_effect.draw_pass_1 = spark_mesh
	spark_effect.draw_pass_1.material = _material(Color("#fff0a3"), 0.2)
	add_child(spark_effect)

func _update_chain_effects(delta: float) -> void:
	if not chain_triggered:
		return
	chain_elapsed += delta
	for wave in shockwaves:
		if is_instance_valid(wave):
			wave.scale += Vector3.ONE * delta * 2.8
	if flash_light and is_instance_valid(flash_light):
		flash_light.light_energy = max(0.0, 9.0 - chain_elapsed * 5.0)
	if boom_effect and is_instance_valid(boom_effect):
		boom_effect.scale = Vector3.ONE * (0.35 + chain_elapsed * 1.8)
	if chain_elapsed > 3.5:
		for wave in shockwaves:
			if is_instance_valid(wave):
				wave.queue_free()
		shockwaves.clear()
		if is_instance_valid(flash_light):
			flash_light.queue_free()
			flash_light = null
		if is_instance_valid(boom_effect):
			boom_effect.queue_free()
			boom_effect = null
		chain_elapsed = -99.0

func _create_building(at: Vector3, shop: bool, upper_order := false) -> void:
	var building := Node3D.new()
	building.position = at
	building.name = "Empresa superior" if upper_order else ("Negocio" if shop else "Casa")
	city_root.add_child(building)
	var height := 1.2 + float((building_count * 17) % 5) * 0.18
	var width := 1.25
	var depth := 1.15
	if upper_order:
		height = 2.5 + float(building_count % 3) * 0.22
		width = 1.85
		depth = 1.65
	_box(building, Vector3(width, height, depth), _material(Color("#b87843") if upper_order else wood), Vector3(0, height / 2.0, 0))
	var frame_offset := width * 0.29
	var facade_z := -depth / 2.0 - 0.02
	_box(building, Vector3(0.12, height * 0.84, 0.06), _material(wood_dark), Vector3(-frame_offset, height / 2.0, facade_z))
	_box(building, Vector3(0.12, height * 0.84, 0.06), _material(wood_dark), Vector3(frame_offset, height / 2.0, facade_z))
	_box(building, Vector3(width * 0.66, 0.08, 0.07), _material(wood_dark), Vector3(0, height * 0.58, facade_z - 0.02), Vector3(0, 0, deg_to_rad(18)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 1.3 if upper_order else 0.95
	roof.height = 0.9 if upper_order else 0.75
	roof.radial_segments = 4
	_mesh(building, roof, _material(Color("#4a3a3a") if upper_order else Color("#59423c")), Vector3(0, height + roof.height / 2.0, 0), Vector3(1.0, 1.0, 0.78))
	if upper_order:
		for floor in range(2):
			for window in range(3):
				_box(building, Vector3(0.28, 0.32, 0.04), _material(Color("#ffe08c"), 0.3), Vector3(-0.62 + window * 0.62, 0.72 + floor * 0.68, facade_z - 0.05))
		for stripe in range(7):
			_box(building, Vector3(0.3, 0.1, 0.72), _material(cream if stripe % 2 == 0 else Color("#d65c4b")), Vector3(-0.9 + stripe * 0.3, height * 0.62, facade_z - 0.12), Vector3(0, 0, deg_to_rad(-8)))
		_box(building, Vector3(width * 0.76, 0.1, 0.08), _material(wood_dark), Vector3(0, height * 0.62 - 0.08, facade_z - 0.08))
		var sign := Label3D.new()
		sign.text = "BANCO" if building_count % 3 == 0 else ("FABRICA" if building_count % 3 == 1 else "MAYORISTA")
		sign.font_size = 28
		sign.outline_size = 6
		sign.modulate = Color("#ffe8a3")
		sign.position = Vector3(0, height * 0.92, facade_z - 0.08)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		building.add_child(sign)
	elif shop:
		for stripe in range(5):
			_box(building, Vector3(0.3, 0.08, 0.55), _material(cream if stripe % 2 == 0 else Color("#d65c4b")), Vector3(-0.6 + stripe * 0.3, height * 0.68, facade_z - 0.06), Vector3(0, 0, deg_to_rad(-8)))
		_box(building, Vector3(0.62, 0.58, 0.04), _material(Color("#e7a653")), Vector3(0, 0.42, facade_z - 0.02))

func _build_people() -> void:
	for i in range(WALKER_COUNT):
		var person := Node3D.new()
		people_root.add_child(person)
		_box(person, Vector3(0.18, 0.42, 0.18), _material(Color("#4c6e91") if i % 2 == 0 else Color("#c85f4e")), Vector3(0, 0.35, 0))
		_mesh(person, SphereMesh.new(), _material(Color("#f2b47c")), Vector3(0, 0.72, 0), Vector3(0.19, 0.22, 0.19))
		walkers.append(person)
		walker_offsets.append(float(i) * 0.7)

func _update_people() -> void:
	for i in range(walkers.size()):
		var person := walkers[i]
		var phase := elapsed * (0.32 + float(i % 3) * 0.05) + walker_offsets[i]
		var radius := 1.6 + fmod(float(i) * 1.35, 5.0)
		person.position = Vector3(cos(phase) * radius, 0.05 + abs(sin(phase * 4.0)) * 0.04, sin(phase) * radius)
		person.rotation.y = -phase + PI / 2.0

func _update_coins() -> void:
	for i in range(coin_nodes.size()):
		var coin := coin_nodes[i]
		coin.position.y = 1.1 + sin(elapsed * 2.0 + float(i)) * 0.18

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(26, 24)
	panel.size = Vector2(360, 250)
	panel.color = Color(0.08, 0.12, 0.14, 0.88)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "CIUDAD AUSTRACA"
	title.position = Vector2(22, 18)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f7d99b"))
	panel.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(22, 54)
	status_label.add_theme_color_override("font_color", Color("#c5d8c2"))
	panel.add_child(status_label)
	activity_label = Label.new()
	activity_label.position = Vector2(22, 78)
	panel.add_child(activity_label)
	prosperity_label = Label.new()
	prosperity_label.position = Vector2(22, 102)
	panel.add_child(prosperity_label)
	growth_label = Label.new()
	growth_label.position = Vector2(22, 128)
	growth_label.text = "EL MERCADO DECIDE"
	growth_label.add_theme_color_override("font_color", Color("#e7a653"))
	panel.add_child(growth_label)
	speed_label = Label.new()
	speed_label.position = Vector2(22, 198)
	speed_label.add_theme_color_override("font_color", Color("#f7d99b"))
	panel.add_child(speed_label)
	var button := Button.new()
	button.text = "PAUSAR / CONTINUAR"
	button.position = Vector2(22, 158)
	button.size = Vector2(132, 30)
	button.pressed.connect(_toggle_pause)
	panel.add_child(button)
	var speed_names := ["LENTA", "NORMAL", "RAPIDA"]
	for i in range(speed_names.size()):
		var speed_button := Button.new()
		speed_button.text = speed_names[i]
		speed_button.position = Vector2(164 + i * 64, 194)
		speed_button.size = Vector2(60, 30)
		speed_button.pressed.connect(_set_speed.bind(i))
		panel.add_child(speed_button)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(22, 235)
	progress_bar.size = Vector2(316, 8)
	progress_bar.show_percentage = false
	panel.add_child(progress_bar)
	_update_interface()

func _update_interface() -> void:
	if not status_label:
		return
	status_label.text = "CADENA DE PROSPERIDAD  •  +90%" if chain_triggered else "Orden espontaneo  •  sin alcaldia"
	activity_label.text = "ACTIVIDAD ECONOMICA     %02d" % activity
	prosperity_label.text = "PROSPERIDAD             %02d" % prosperity
	var speed_name := ["LENTA", "NORMAL", "RAPIDA"][speed_mode]
	speed_label.text = "RITMO DE CRECIMIENTO: %s" % speed_name
	growth_label.text = "EMPRESAS SUPERIORES ACTIVAS" if chain_triggered else "EL MERCADO DECIDE"
	progress_bar.value = float(building_count) / float(BUILDING_LIMIT) * 100.0

func _set_speed(mode: int) -> void:
	speed_mode = mode
	speed = [0.55, 1.0, 2.0][mode]
	_update_interface()

func _toggle_pause() -> void:
	paused = not paused
