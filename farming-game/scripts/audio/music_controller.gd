extends Node

## Optional streams under res://assets/audio/bgm/ — use any extension Godot imports (e.g. .mp3, .ogg, .wav).
## BGM loops: menu, gameplay, tension. One-shots: wave_win, run_loss.

const BGM_DIR := "res://assets/audio/bgm/"

var _bgm: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _urgent_count := 0
var _context := "menu"
var _current_bgm_key := ""
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BgmPlayer"
	add_child(_bgm)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "StingerPlayer"
	add_child(_stinger)


func play_menu() -> void:
	_context = "menu"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = 0.0
	_crossfade_to("menu", _first_existing("menu"))


func enter_gameplay() -> void:
	_context = "game"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = 0.0
	_play_gameplay_bgm(false)


func register_customer_urgency() -> void:
	if _context != "game":
		return
	_urgent_count += 1
	if _urgent_count == 1:
		_play_gameplay_bgm(true)


func unregister_customer_urgency() -> void:
	if _context != "game":
		return
	_urgent_count = max(0, _urgent_count - 1)
	if _urgent_count == 0:
		_play_gameplay_bgm(false)


func play_wave_win_sting() -> void:
	_play_stinger_one_shot("wave_win")


func play_run_loss_sting() -> void:
	_play_stinger_one_shot("run_loss")
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm, "volume_db", -80.0, 0.4)
	_fade_tween.tween_callback(
		func() -> void:
			_bgm.stop()
			_current_bgm_key = ""
	)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _play_gameplay_bgm(tension: bool) -> void:
	var key := "tension" if tension else "gameplay"
	var stream: AudioStream = _first_existing(key)
	if stream == null and tension:
		key = "gameplay"
		stream = _first_existing("gameplay")
	if stream == null:
		_bgm.stop()
		_current_bgm_key = ""
		return
	_crossfade_to(key, stream)


func _first_existing(base: String) -> AudioStream:
	for ext: String in ["mp3", "ogg", "wav"]:
		var path := BGM_DIR + base + "." + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _set_bgm_loop(s: AudioStream) -> void:
	if s == null:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _set_stinger_no_loop(s: AudioStream) -> void:
	if s == null:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


func _crossfade_to(key: String, stream: AudioStream) -> void:
	if stream == null:
		return
	if key == _current_bgm_key and _bgm.playing:
		return
	_set_bgm_loop(stream)
	var duration := 0.35
	_kill_fade()
	if not _bgm.playing or _bgm.stream == null:
		_bgm.stream = stream
		_bgm.volume_db = 0.0
		_bgm.play()
		_current_bgm_key = key
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm, "volume_db", -50.0, duration * 0.45).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(
		func() -> void:
			_bgm.stream = stream
			_bgm.volume_db = -50.0
			_bgm.play()
			_current_bgm_key = key
	)
	_fade_tween.tween_property(_bgm, "volume_db", 0.0, duration * 0.55).set_ease(Tween.EASE_OUT)


func _play_stinger_one_shot(base: String) -> void:
	var s := _first_existing(base)
	if s == null:
		return
	_set_stinger_no_loop(s)
	_stinger.stream = s
	_stinger.play()
