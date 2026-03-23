extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed := Globals.player_speed
var previous_direction := Vector2.DOWN

var _mana_sprite_frames: SpriteFrames
var _mirror_left_animations := true
var _sheet_frames_cache: Dictionary = {}


func _ready() -> void:
	_mana_sprite_frames = animated_sprite.sprite_frames.duplicate(true)
	_apply_skin_visual()


func refresh_appearance_from_data() -> void:
	_apply_skin_visual()


func _apply_skin_visual() -> void:
	if PlayerData.uses_builtin_mana_frames():
		animated_sprite.sprite_frames = _mana_sprite_frames
	else:
		animated_sprite.sprite_frames = _get_cached_frames_for_key(PlayerData.get_character_preset_key())
	_mirror_left_animations = PlayerData.character_uses_mirrored_side_frames()
	animated_sprite.modulate = PlayerData.get_character_modulate()
	animated_sprite.material = null
	animated_sprite.play(&"idle_down")


func _get_cached_frames_for_key(key: String) -> SpriteFrames:
	if _sheet_frames_cache.has(key):
		return _sheet_frames_cache[key] as SpriteFrames
	var tex := PlayerData.get_character_texture()
	var frames := _duplicate_mana_frames_with_texture(tex)
	_sheet_frames_cache[key] = frames
	return frames


func _duplicate_mana_frames_with_texture(tex: Texture2D) -> SpriteFrames:
	if tex == null:
		return _mana_sprite_frames
	var sf := SpriteFrames.new()
	for anim_name in _mana_sprite_frames.get_animation_names():
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, _mana_sprite_frames.get_animation_loop(anim_name))
		sf.set_animation_speed(anim_name, _mana_sprite_frames.get_animation_speed(anim_name))
		for frame_idx in range(_mana_sprite_frames.get_frame_count(anim_name)):
			var source_tex := _mana_sprite_frames.get_frame_texture(anim_name, frame_idx)
			var frame_tex: Texture2D = source_tex
			if source_tex is AtlasTexture:
				var src_atlas := source_tex as AtlasTexture
				var dst_atlas := AtlasTexture.new()
				dst_atlas.atlas = tex
				dst_atlas.region = src_atlas.region
				dst_atlas.margin = src_atlas.margin
				dst_atlas.filter_clip = src_atlas.filter_clip
				frame_tex = dst_atlas
			sf.add_frame(anim_name, frame_tex, _mana_sprite_frames.get_frame_duration(anim_name, frame_idx))
	return sf


func play_animation(animation_name: StringName, flipped := false) -> void:
	animated_sprite.flip_h = flipped
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func get_input() -> void:
	var input_direction := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = input_direction * speed


func play_animations() -> void:
	if velocity.length() > 0:
		if velocity.x < 0:
			play_animation(&"walk_left", _mirror_left_animations)
			previous_direction = Vector2.LEFT
		elif velocity.x > 0:
			play_animation(&"walk_right")
			previous_direction = Vector2.RIGHT
		elif velocity.y < 0:
			play_animation(&"walk_up")
			previous_direction = Vector2.UP
		else:
			play_animation(&"walk_down")
			previous_direction = Vector2.DOWN
	else:
		if previous_direction == Vector2.LEFT:
			play_animation(&"idle_left", _mirror_left_animations)
		elif previous_direction == Vector2.RIGHT:
			play_animation(&"idle_right")
		elif previous_direction == Vector2.UP:
			play_animation(&"idle_up")
		else:
			play_animation(&"idle_down")


func _physics_process(_delta: float) -> void:
	get_input()
	play_animations()
	move_and_slide()
