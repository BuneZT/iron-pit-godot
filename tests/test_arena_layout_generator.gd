extends TestCase


func test_enforces_center_safe_zone() -> void:
	for run in range(10):
		var layout := ArenaLayoutGenerator.generate(run * 100)
		var safe_radius: float = float(layout["safe_radius"])
		var all_items: Array = []
		all_items.append_array(layout["megaliths"])
		all_items.append_array(layout["barricades"])
		all_items.append_array(layout["braziers"])

		for item in all_items:
			var dist := Vector2(float(item["x"]), float(item["z"])).length()
			assert_gte(dist, safe_radius)


func test_keeps_all_elements_inside_arena_perimeter_bounds() -> void:
	for run in range(10):
		var layout := ArenaLayoutGenerator.generate(run * 100)
		var bounds: float = float(layout["arena_bounds"])
		var all_items: Array = []
		all_items.append_array(layout["megaliths"])
		all_items.append_array(layout["barricades"])
		all_items.append_array(layout["braziers"])

		for item in all_items:
			assert_lte(absf(float(item["x"])), bounds)
			assert_lte(absf(float(item["z"])), bounds)


func test_enforces_minimum_separation_between_major_obstacles() -> void:
	for run in range(10):
		var layout := ArenaLayoutGenerator.generate(run * 100)
		var obstacles: Array = []
		obstacles.append_array(layout["megaliths"])
		obstacles.append_array(layout["barricades"])

		for i in range(obstacles.size()):
			for j in range(i + 1, obstacles.size()):
				var dist := Vector2(
					float(obstacles[i]["x"]) - float(obstacles[j]["x"]),
					float(obstacles[i]["z"]) - float(obstacles[j]["z"])
				).length()
				assert_gte(dist, 6.5)


func test_distributes_obstacles_and_braziers_across_all_four_quadrants() -> void:
	var layout := ArenaLayoutGenerator.generate(42)
	var signs: Array[Vector2] = [
		Vector2(1, 1),
		Vector2(-1, 1),
		Vector2(-1, -1),
		Vector2(1, -1),
	]

	for s in signs:
		var mega_count := 0
		for m in layout["megaliths"]:
			if float(m["x"]) * s.x > 0.0 and float(m["z"]) * s.y > 0.0:
				mega_count += 1
		var barr_count := 0
		for b in layout["barricades"]:
			if float(b["x"]) * s.x > 0.0 and float(b["z"]) * s.y > 0.0:
				barr_count += 1
		var braz_count := 0
		for br in layout["braziers"]:
			if float(br["x"]) * s.x > 0.0 and float(br["z"]) * s.y > 0.0:
				braz_count += 1

		assert_gte(mega_count, 1)
		assert_gte(barr_count, 1)
		assert_gte(braz_count, 1)


func test_distributes_braziers_across_varied_depths() -> void:
	var layout := ArenaLayoutGenerator.generate(42)
	var inner_count := 0
	var outer_count := 0
	for b in layout["braziers"]:
		var d := Vector2(float(b["x"]), float(b["z"])).length()
		if d <= 20.0:
			inner_count += 1
		if d >= 30.0:
			outer_count += 1

	assert_gte(inner_count, 1)
	assert_gte(outer_count, 1)


func test_populates_outer_zones_near_walls_with_barricades_and_ruins() -> void:
	var layout := ArenaLayoutGenerator.generate(42)
	var outer_barricades := 0
	for b in layout["barricades"]:
		if Vector2(float(b["x"]), float(b["z"])).length() >= 30.0:
			outer_barricades += 1
	var outer_megaliths := 0
	for m in layout["megaliths"]:
		if Vector2(float(m["x"]), float(m["z"])).length() >= 30.0:
			outer_megaliths += 1

	assert_gte(outer_barricades, 2)
	assert_gte(outer_megaliths, 1)


func test_generates_different_layouts_with_different_seeds() -> void:
	var layout_a := ArenaLayoutGenerator.generate(1)
	var layout_b := ArenaLayoutGenerator.generate(999)
	assert_ne(float(layout_a["megaliths"][0]["x"]), float(layout_b["megaliths"][0]["x"]))


func test_find_fog_spawn_point_in_distance_fog() -> void:
	var layout := ArenaLayoutGenerator.generate(123)
	var bounds: float = float(layout["arena_bounds"])
	var player_pos := Vector2(0.0, 0.0)

	for i in range(20):
		var spawn := ArenaLayoutGenerator.find_fog_spawn_point(player_pos, layout)
		var dist := spawn.distance_to(player_pos)
		assert_gte(dist, 22.0)
		assert_lte(absf(spawn.x), bounds)
		assert_lte(absf(spawn.y), bounds)


func test_find_fog_spawn_point_when_player_near_border() -> void:
	var layout := ArenaLayoutGenerator.generate(123)
	var bounds: float = float(layout["arena_bounds"])
	var corner_player := Vector2(38.0, 38.0)

	for i in range(20):
		var spawn := ArenaLayoutGenerator.find_fog_spawn_point(corner_player, layout)
		var dist := spawn.distance_to(corner_player)
		assert_gte(dist, 20.0)
		assert_lte(absf(spawn.x), bounds)
		assert_lte(absf(spawn.y), bounds)


func test_find_fog_spawn_point_avoids_major_obstacles() -> void:
	var layout := ArenaLayoutGenerator.generate(123)
	var player_pos := Vector2(0.0, 0.0)
	var obstacles: Array = []
	obstacles.append_array(layout["megaliths"])
	obstacles.append_array(layout["barricades"])

	for i in range(30):
		var spawn := ArenaLayoutGenerator.find_fog_spawn_point(player_pos, layout)
		for obs in obstacles:
			var dist := Vector2(spawn.x - float(obs["x"]), spawn.y - float(obs["z"])).length()
			assert_gte(dist, 2.0)
