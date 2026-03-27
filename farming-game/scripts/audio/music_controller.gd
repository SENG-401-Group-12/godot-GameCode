extends Node

## Loads optional audio from res://assets/audio/bgm/. Each role tries harvest-for-all-* names first, then short aliases.
## Menu intro plays at MENU_PITCH_SCALE (1.5 = faster, loop still matches file end).
## Output level follows GameSettings (master × music), default ~75% music × 100% master.
## BGM and one-shot stingers never overlap for run end; no per-wave sting (BGM stays continuous between waves).

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
		"shop":
			return PackedStringArray(["harvest-for-all-shop-music", "shop"])
		"run_loss":
			return PackedStringArray(["harvest-for-all-round-loss", "run_loss"])
		"max_win":
			return PackedStringArray(["harvest-for-all-game-win-max", "game_win_max", "max_win"])
		_:
			return PackedStringArray([role])

var _bgm: AudioStreamPlayer
var _stinger: AudioStreamPlayer
## Single cached instances for gameplay/tension so crossfade "already playing" checks stay reliable
## (repeated load() can return unequal instances or empty resource_path on some platforms).
var _stream_gameplay: AudioStream
var _stream_tension: AudioStream
var _stream_shop: AudioStream
var _urgent_count := 0
var _context := "menu"
var _current_bgm_key := ""
var _fade_tween: Tween
var _xfade_lerp_from: float = 0.0
var _xfade_lerp_to: float = 0.0
## BGM was paused so a one-shot stinger is the only music heard.
var _bgm_paused_for_stinger := false
## When the current stinger ends, unpause BGM (wave clears). False for victory/loss/menu.
var _resume_bgm_after_stinger := false
var _web_audio_unlocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BgmPlayer"
	_bgm.bus = &"Master"
	add_child(_bgm)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "StingerPlayer"
	_stinger.pitch_scale = 1.0
	_stinger.bus = &"Master"
	add_child(_stinger)
	_stinger.finished.connect(_on_stinger_finished)
	GameSettings.settings_changed.connect(_on_game_settings_changed)


func ensure_web_audio_unlocked() -> void:
	if not OS.has_feature("web"):
		return
	if _web_audio_unlocked:
		return
	_web_audio_unlocked = true
	# Browsers block autoplay until a gesture; resume any known audio contexts once the
	# user taps/clicks, then re-trigger the active BGM route.
	JavaScriptBridge.eval(
		"(function(){try{if(window.godotAudioContext&&window.godotAudioContext.state!=='running'){window.godotAudioContext.resume();}"
		+ "if(window.AudioContext){if(!window.__hfa_ctx){window.__hfa_ctx=new AudioContext();}"
		+ "if(window.__hfa_ctx.state!=='running'){window.__hfa_ctx.resume();}}}catch(e){}})();",
		true
	)
	if _context == "menu":
		play_menu()
	elif _context == "game":
		_play_gameplay_bgm(_urgent_count > 0)


func _streams_same_resource(a: AudioStream, b: AudioStream) -> bool:
	if a == null or b == null:
		return a == b
	if a == b:
		return true
	var pa := String(a.resource_path)
	var pb := String(b.resource_path)
	if not pa.is_empty() and not pb.is_empty():
		return pa == pb
	return false


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
	_resume_bgm_after_stinger = false


func play_menu() -> void:
	_stop_stingers()
	_stream_gameplay = null
	_stream_tension = null
	_context = "menu"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = _peak_db()
	var stream: AudioStream = _first_for_role("menu")
	if stream == null:
		push_warning("Music: no menu BGM found under %s (expected harvest-for-all-intro or menu.*)." % BGM_DIR)
		return
	_crossfade_to("menu", stream)


func enter_gameplay() -> void:
	_stop_stingers()
	_context = "game"
	_urgent_count = 0
	_kill_fade()
	_bgm.volume_db = _peak_db()
	_bgm.pitch_scale = 1.0
	_play_gameplay_bgm(false)


func enter_shop() -> void:
	if _context != "game":
		return
	_stop_stingers()
	_context = "shop"
	_kill_fade()
	var stream: AudioStream = _cached_stream_for_role("shop")
	if stream == null:
		push_warning("Music: no shop BGM under %s (expected harvest-for-all-shop-music or shop.*)." % BGM_DIR)
		return
	# Shop immediately pauses the tree; use an immediate switch so paused tweens can't stall this transition on web.
	_set_bgm_loop(stream)
	_apply_bgm_pitch_for_key("shop")
	_bgm.stream = stream
	_bgm.volume_db = _peak_db()
	_bgm.stream_paused = false
	_bgm_paused_for_stinger = false
	_bgm.play()
	_current_bgm_key = "shop"


func exit_shop() -> void:
	if _context != "shop":
		return
	_context = "game"
	_play_gameplay_bgm(_urgent_count > 0)


func register_customer_urgency() -> void:
	if _context != "game":
		return
	_urgent_count += 1
	# Always sync BGM to urgency count. Previously we only switched on 0→1; a leaked count > 0
	# from an edge case meant later waves never hit == 1 again, so tension never returned.
	_play_gameplay_bgm(_urgent_count > 0)
	if _urgent_count > 0:
		# If crossfade was blocked (e.g. wave sting) or state was mid-transition, retry next frame.
		call_deferred("_deferred_reassert_urgency_bgm")


func _deferred_reassert_urgency_bgm() -> void:
	if _context != "game" or _urgent_count <= 0:
		return
	_play_gameplay_bgm(true)


func unregister_customer_urgency() -> void:
	if _context != "game":
		return
	_urgent_count = max(0, _urgent_count - 1)
	_play_gameplay_bgm(_urgent_count > 0)


## Call at the start of each wave so urgency cannot carry over between waves.
func reset_wave_urgency() -> void:
	if _context != "game":
		return
	_urgent_count = 0
	_play_gameplay_bgm(false)
	_reset_customer_urgency_flags_after_wave()


func play_max_win_sting() -> void:
	_kill_fade()
	_bgm.stop()
	_current_bgm_key = ""
	_bgm.stream_paused = false
	_bgm_paused_for_stinger = false
	# Stop customers from calling register/reassert while run is over (was restarting BGM after loss sting).
	_context = "ended"
	_urgent_count = 0
	_play_stinger_one_shot("max_win", false)


func play_run_loss_sting() -> void:
	_kill_fade()
	_bgm.stop()
	_current_bgm_key = ""
	_bgm.stream_paused = false
	_bgm_paused_for_stinger = false
	_context = "ended"
	_urgent_count = 0
	_play_stinger_one_shot("run_loss", false)


func _reset_customer_urgency_flags_after_wave() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"customers_with_order_timer"):
		if n.has_method(&"on_wave_reset_clear_urgency_flag"):
			n.on_wave_reset_clear_urgency_flag()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _cached_stream_for_role(role: String) -> AudioStream:
	match role:
		"gameplay":
			if _stream_gameplay == null:
				_stream_gameplay = _first_for_role("gameplay")
			return _stream_gameplay
		"tension":
			if _stream_tension == null:
				_stream_tension = _first_for_role("tension")
			return _stream_tension
		"shop":
			if _stream_shop == null:
				_stream_shop = _first_for_role("shop")
			return _stream_shop
		_:
			return _first_for_role(role)


func _play_gameplay_bgm(tension: bool) -> void:
	var key := "tension" if tension else "gameplay"
	var stream: AudioStream = _cached_stream_for_role(key)
	if stream == null and tension:
		key = "gameplay"
		stream = _cached_stream_for_role("gameplay")
	if stream == null:
		push_warning("Music: no gameplay BGM under %s (expected harvest-for-all-game-loop or gameplay.*)." % BGM_DIR)
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
	# Avoid swapping/unpausing BGM while the wave-clear jingle plays (would overlap audio).
	if _stinger.playing and _resume_bgm_after_stinger:
		return
	# Key can be stale if a crossfade was killed (e.g. wave-win sting) before the tween callback ran.
	# Match by resource_path too: repeated load() can yield a different instance than _bgm.stream.
	if key == _current_bgm_key and _bgm.playing and _streams_same_resource(_bgm.stream, stream):
		return
	_set_bgm_loop(stream)
	_apply_bgm_pitch_for_key(key)
	var duration := 0.35
	var peak := _peak_db()
	_kill_fade()
	if not _bgm.playing or _bgm.stream == null:
		_bgm.stream = stream
		_bgm.volume_db = peak
		_bgm.stream_paused = false
		_bgm_paused_for_stinger = false
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
			_bgm.stream_paused = false
			_bgm_paused_for_stinger = false
			_bgm.play()
			_current_bgm_key = key
			_xfade_lerp_from = p - 50.0
			_xfade_lerp_to = p
	)
	_fade_tween.tween_method(_xfade_volume_lerp, 0.0, 1.0, duration * 0.55).set_ease(Tween.EASE_OUT)


func _xfade_volume_lerp(alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	_bgm.volume_db = lerpf(_xfade_lerp_from, _xfade_lerp_to, a)


func _silence_bgm_for_exclusive_stinger() -> void:
	if not _bgm.playing:
		return
	if _bgm_paused_for_stinger:
		return
	_bgm.stream_paused = true
	_bgm_paused_for_stinger = true


func _release_bgm_from_stinger_pause() -> void:
	if not _bgm_paused_for_stinger:
		return
	_bgm.stream_paused = false
	_bgm.volume_db = _peak_db()
	_bgm_paused_for_stinger = false


func _on_stinger_finished() -> void:
	var should_resume := _resume_bgm_after_stinger
	_resume_bgm_after_stinger = false
	if should_resume and _context == "game":
		_release_bgm_from_stinger_pause()
		# Crossfades are blocked while the wave jingle plays; catch up with urgency state.
		_play_gameplay_bgm(_urgent_count > 0)
	else:
		_bgm_paused_for_stinger = false


func _play_stinger_one_shot(role: String, resume_bgm_after: bool) -> void:
	var s := _first_for_role(role)
	if s == null:
		return
	_kill_fade()
	if _stinger.playing:
		_stinger.stop()
	_resume_bgm_after_stinger = false
	_silence_bgm_for_exclusive_stinger()
	_resume_bgm_after_stinger = resume_bgm_after
	_set_stinger_no_loop(s)
	_stinger.volume_db = _peak_db()
	_stinger.stream = s
	_stinger.play()
