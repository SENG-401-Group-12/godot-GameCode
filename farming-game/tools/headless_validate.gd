extends SceneTree
## Run: Godot_console.exe --headless --path farming-game -s res://tools/headless_validate.gd
## Loads key scenes (no CropUpgrade) so autoload singletons are not required at compile time for this file.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var exit_code := 0
	var scenes: PackedStringArray = [
		"res://scenes/ui/main_menu/main_menu.tscn",
		"res://scenes/ui/run_setup/run_setup.tscn",
		"res://scenes/tutorial/tutorial_lesson.tscn",
		"res://scenes/test/test_scene_gameloop.tscn",
		"res://scenes/ui/game/in_game_ui.tscn",
		"res://scenes/ui/game/shop/shop_ui.tscn",
		"res://scripts/gamemanager/game_manager.tscn",
	]
	for path: String in scenes:
		var res: Resource = load(path)
		if res == null:
			push_error("LOAD_FAIL: %s" % path)
			exit_code = 1
			continue
		if not (res is PackedScene):
			push_error("NOT_PACKED_SCENE: %s" % path)
			exit_code = 1
			continue
		var ps: PackedScene = res as PackedScene
		var n: Node = ps.instantiate()
		if n == null:
			push_error("INST_FAIL: %s" % path)
			exit_code = 1
			continue
		n.queue_free()
		print("OK load+instantiate: ", path)

	var pd: Node = root.get_node_or_null("PlayerData")
	var um: Node = root.get_node_or_null("UpgradeManager")
	var gp: Node = root.get_node_or_null("GameProgress")
	if pd == null or um == null or gp == null:
		push_error("MISSING autoload (need PlayerData, UpgradeManager, GameProgress)")
		quit(1)
		return

	pd.call("reset_run_state")
	pd.call("set_character_preset", 2)
	var m: Color = pd.call("get_character_modulate") as Color
	if m.a <= 0.0:
		push_error("BAD character modulate")
		exit_code = 1
	else:
		print("OK PlayerData character preset")

	var choices: Array = um.call("generate_upgrade_choices", 3) as Array
	if choices.is_empty():
		push_error("FAIL no upgrade choices")
		exit_code = 1
	else:
		print("OK UpgradeManager.generate_upgrade_choices: ", choices.size())

	print("headless_validate exit_code=", exit_code)
	quit(exit_code)
