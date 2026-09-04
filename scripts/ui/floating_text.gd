class_name FloatingText
extends RefCounted

## Всплывающий текст, не привязанный к жизни врага/игрока.


static func spawn(scene: Node, global_pos: Vector2, text: String, color: Color = Color.WHITE, crit: bool = false) -> void:
	if scene == null:
		return
	var tree := scene.get_tree()
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		host = scene

	var label := Label.new()
	label.text = text if not crit else text + "!"
	label.modulate = color
	label.z_index = 100
	if crit:
		label.scale = Vector2(1.35, 1.35)
	label.global_position = global_pos + Vector2(-10, -36)
	host.add_child(label)

	# Tween на дереве сцены — переживает queue_free врага
	var tween := tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(randf_range(-10, 10), -42), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
