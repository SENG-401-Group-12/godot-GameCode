extends Node2D

# ===== TEST FLAGS =====
const TEST_LOGIN := true
const TEST_SIGNUP := false
const TEST_GUEST := false
const TEST_LOGOUT := false

const TEST_CREATE_PROFILE := false
const TEST_UPDATE_PROFILE := false
const TEST_SUBMIT_RUN := false
const TEST_LEADERBOARD := false
const TEST_PERSONAL_BEST := true


# ===== TEST DATA =====
const TEST_EMAIL := "neloca3986@duoley.com"
const TEST_PASSWORD := "12345678"
const TEST_DISPLAY_NAME := "BossTest"

const TEST_SCORE := 999
const TEST_DURATION := 60000
const TEST_WAVES := 3


func _ready() -> void:
	print("TEST SCENE READY")
	print("=== Backend Test Manager Started ===")

	# Connect signals
	Backend.login_succeeded.connect(_on_login_success)
	Backend.login_failed.connect(_on_login_failed)

	Backend.signup_succeeded.connect(_on_signup_succeeded)
	Backend.signup_failed.connect(_on_signup_failed)

	Backend.profile_created.connect(_on_profile_created)
	Backend.profile_updated.connect(_on_profile_updated)

	Backend.run_submitted.connect(_on_run_submitted)
	Backend.leaderboard_received.connect(_on_leaderboard_received)
	Backend.personal_best_received.connect(_on_personal_best_received)

	# ===== ENTRY POINT TESTS =====

	if TEST_SIGNUP:
		print("Running SIGNUP test...")
		Backend.signup(TEST_EMAIL, TEST_PASSWORD)
		return

	if TEST_GUEST:
		print("Running GUEST MODE test...")
		Backend.continue_as_guest()
		print("Guest mode:", true)
		return

	if TEST_LOGOUT:
		print("Running LOGOUT test...")
		Backend.logout()
		print("Logged in:", Backend.is_logged_in())
		return

	if TEST_LOGIN:
		print("Running LOGIN test...")
		Backend.login(TEST_EMAIL, TEST_PASSWORD)


# ===== LOGIN FLOW =====

func _on_login_success(user_id: String) -> void:
	print("LOGIN SUCCESS:", user_id)
	print("Logged in:", Backend.is_logged_in())
	print("Current user id:", Backend.current_user_id)

	# ===== POST-LOGIN TESTS =====

	if TEST_CREATE_PROFILE:
		print("Testing CREATE PROFILE...")
		Backend.create_profile(TEST_DISPLAY_NAME)
		return

	if TEST_UPDATE_PROFILE:
		print("Testing UPDATE PROFILE...")
		Backend.update_profile(TEST_DISPLAY_NAME + "_Updated")
		return

	if TEST_SUBMIT_RUN:
		print("Testing SUBMIT RUN...")
		Backend.submit_run(TEST_SCORE, TEST_DURATION, TEST_WAVES)
		return

	if TEST_LEADERBOARD:
		print("Testing LEADERBOARD...")
		Backend.get_top_10()
		return

	if TEST_PERSONAL_BEST:
		print("Testing PERSONAL BEST...")
		Backend.get_personal_best()
		return


func _on_login_failed(message: String) -> void:
	print("LOGIN FAILED:", message)


# ===== SIGNUP =====

func _on_signup_succeeded(message: String) -> void:
	print("SIGNUP SUCCESS:", message)


func _on_signup_failed(message: String) -> void:
	print("SIGNUP FAILED:", message)


# ===== PROFILE =====

func _on_profile_created(data) -> void:
	print("PROFILE CREATED:")
	print(data)


func _on_profile_updated(data) -> void:
	print("PROFILE UPDATED:")
	print(data)


# ===== RUN =====

func _on_run_submitted(data) -> void:
	print("RUN SUBMITTED:")
	print(data)


# ===== LEADERBOARD =====

func _on_leaderboard_received(data) -> void:
	print("LEADERBOARD RECEIVED:")
	print(data)


# ===== PERSONAL BEST =====

func _on_personal_best_received(data) -> void:
	print("PERSONAL BEST RECEIVED:")
	print(data)
