extends Node

## Loads optional audio from res://assets/audio/bgm/. Each role tries harvest-for-all-* names first, then short aliases.
## Menu intro plays at MENU_PITCH_SCALE (1.5 = faster, loop still matches file end).
## Output level follows GameSettings (master × music), default ~75% music × 100% master.

const BGM_DIR := "res://assets/audio/bgm/"
const MENU_PITCH_SCALE := 1.5


func _bases_for_role(role: String) -> PackedStringArray:
	match role:
		"menu":
			return PackedStringArray(["harvest-for-all-intro", "menu"])
		"gameplay":
			return PackedStringArray(["harvest-for-all-game-loop", "gameplay"])
		"tension":
			return PackedStringArray(["harvest-for-all-tension", "tension"])
		"wave_win":
			return PackedStringArray(["harvest-for-all-round-win", "wave_win"])
		"run_loss":
			return PackedStringArray(["harvest-for-all-round-loss", "run_loss"])
		"max_win":
			return PackedStringArray(["harvest-for-all-game-win-max", "game_win_max", "max_win"])
		_:
			return PackedStringArray([role])

var _bgm: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _urgent_count := 0
var _context := "menu"
var _current_bgm_key := ""
var _fade_tween: Tween
var _xfade_lerp_from: float = 0.0
var _xfade_lerp_to: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BgmPlayer"
	add_child(_bgm)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "StingerPlayer"
	_stinger.pitch_scale = 1.0
	add_child(_stinger)
	GameSettings.settings_changed.connect(_on_game_settings_changed)


func _peak_db() -> float:
	return GameSettings.get_music_volume_db()


func _on_game_settings_changed() -> void:
	_stinger.volume_db = _peak_db()
	if _fade_tween != null and _fade_tween.is_valid():
		return
	if _bgm.playing:
		_bgm.volume_db = _peak_db()


func _stop_stingers() -> void:
	if _stinger.playing:
		_stinger.stop()
	_stinger.stream = null


func play_menu() -> void:
	_stop_stingers()
	_context = "menu"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = _peak_db()
	_crossfade_to("menu", _first_for_role("menu"))


func enter_gameplay() -> void:
	_stop_stingers()
	_context = "game"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = _peak_db()
	_bgm.pitch_scale = 1.0
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


func play_max_win_sting() -> void:
	_play_stinger_one_shot("max_win")
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm, "volume_db", -80.0, 0.4)
	_fade_tween.tween_callback(
		func() -> void:
			_bgm.stop()
			_current_bgm_key = ""
	)


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
	var stream: AudioStream = _first_for_role(key)
	if stream == null and tension:
		key = "gameplay"
		stream = _first_for_role("gameplay")
	if stream == null:
		_bgm.stop()
		_current_bgm_key = ""
		return
	_crossfade_to(key, stream)


func _first_for_role(role: String) -> AudioStream:
	var bases := _bases_for_role(role)
	for base in bases:
		for ext: String in ["mp3", "ogg", "wav"]:
			var path := BGM_DIR + str(base) + "." + ext
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


func _apply_bgm_pitch_for_key(key: String) -> void:
	_bgm.pitch_scale = MENU_PITCH_SCALE if key == "menu" else 1.0


func _crossfade_to(key: String, stream: AudioStream) -> void:
	if stream == null:
		return
	if key == _current_bgm_key and _bgm.playing:
		return
	_set_bgm_loop(stream)
	_apply_bgm_pitch_for_key(key)
	var duration := 0.35
	var peak := _peak_db()
	_kill_fade()
	if not _bgm.playing or _bgm.stream == null:
		_bgm.stream = stream
		_bgm.volume_db = peak
		_bgm.play()
		_current_bgm_key = key
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm, "volume_db", peak - 50.0, duration * 0.45).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(
		func() -> void:
			var p := _peak_db()
			_apply_bgm_pitch_for_key(key)
			_bgm.stream = stream
			_bgm.volume_db = p - 50.0
			_bgm.play()
			_current_bgm_key = key
			_xfade_lerp_from = p - 50.0
			_xfade_lerp_to = p
	)
	_fade_tween.tween_method(_xfade_volume_lerp, 0.0, 1.0, duration * 0.55).set_ease(Tween.EASE_OUT)


func _xfade_volume_lerp(alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	_bgm.volume_db = lerpf(_xfade_lerp_from, _xfade_lerp_to, a)


func _play_stinger_one_shot(role: String) -> void:
	var s := _first_for_role(role)
	if s == null:
		return
	_set_stinger_no_loop(s)
	_stinger.volume_db = _peak_db()
	_stinger.stream = s
	_stinger.play()
