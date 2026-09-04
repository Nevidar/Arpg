extends SceneTree


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var packed: PackedScene = load("res://scenes/arena.tscn")
	change_scene_to_packed(packed)
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.35).timeout

	var lines: PackedStringArray = PackedStringArray()
	var a: Node = current_scene
	lines.append("scene=%s" % str(a))
	if a == null:
		_write(lines)
		quit()
		return

	lines.append("script_ok=%s" % str(a.get_script() != null))
	var world: Node = a.get_node_or_null("World")
	lines.append("world=%s" % str(world))
	if world:
		lines.append("world_n=%d" % world.get_child_count())
		for c in world.get_children():
			lines.append("child=%s class=%s pos=%s visible=%s" % [c.name, c.get_class(), str(c.global_position), str(c.visible)])
			if c.has_node("Visual"):
				var v = c.get_node("Visual")
				lines.append("  visual type=%s color=%s" % [v.get_class(), str(v.color)])
	lines.append("zone=%s" % str(a.get("_zone_index")))
	lines.append("alive=%s" % str(a.get("_alive_enemies")))
	lines.append("player_var=%s" % str(a.get("player")))
	var wave = a.get_node_or_null("HUD/Root/WaveLabel")
	if wave:
		lines.append("wave=%s" % wave.text)
	var floor_n = a.get_node_or_null("Floor")
	if floor_n:
		lines.append("floor type=%s color=%s visible=%s" % [floor_n.get_class(), str(floor_n.color), str(floor_n.visible)])
	_write(lines)
	quit()


func _write(lines: PackedStringArray) -> void:
	var path := "C:/Users/eilukhin/Documents/Ai_agent/arpg_Nevidar/agents/acts-campaign/debug_boot.txt"
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string("\n".join(lines))
		fa.close()
