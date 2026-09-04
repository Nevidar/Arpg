extends Node

## Простые процедурные звуки без ассетов.

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)


func play_hit(crit: bool = false) -> void:
	_play_tone(520.0 if not crit else 780.0, 0.05 if not crit else 0.08, 0.35 if not crit else 0.5)


func play_swing() -> void:
	_play_tone(180.0, 0.04, 0.22)


func play_dash() -> void:
	_play_tone(120.0, 0.06, 0.18)


func play_hurt() -> void:
	_play_tone(90.0, 0.07, 0.4)


func play_pickup() -> void:
	_play_tone(660.0, 0.06, 0.28)


func play_level_up() -> void:
	_play_tone(440.0, 0.08, 0.3)
	await get_tree().create_timer(0.08).timeout
	_play_tone(660.0, 0.1, 0.35)


func play_splash() -> void:
	_play_tone(240.0, 0.07, 0.32)
	await get_tree().create_timer(0.05).timeout
	_play_tone(160.0, 0.08, 0.28)


func play_slam() -> void:
	_play_tone(90.0, 0.1, 0.45)
	await get_tree().create_timer(0.06).timeout
	_play_tone(70.0, 0.12, 0.4)


func play_portal() -> void:
	_play_tone(300.0, 0.1, 0.3)
	await get_tree().create_timer(0.08).timeout
	_play_tone(480.0, 0.12, 0.35)


func _play_tone(freq: float, duration: float, volume: float) -> void:
	var sample_rate := 22050
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(sample_rate)
		var env := 1.0 - (float(i) / float(frames))
		var sample := int(sin(t * freq * TAU) * env * volume * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.mix_rate = sample_rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.volume_db = -8.0
	p.play()
	p.finished.connect(p.queue_free)
