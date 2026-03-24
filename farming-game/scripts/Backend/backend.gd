extends Node
class_name backend

signal login_succeeded(user_id: String)
signal login_failed(message: String)

signal signup_succeeded(message: String)
signal signup_failed(message: String)

signal leaderboard_received(data)
signal leaderboard_failed(reason: String)
signal leaderboard_endless_received(data)
signal leaderboard_endless_failed(reason: String)
signal run_submitted(data)
signal run_submit_failed(reason: String)
signal personal_best_received(data)
signal personal_best_failed(reason: String)
signal personal_best_endless_received(data)
signal personal_best_endless_failed(reason: String)

signal profile_created(data)
signal profile_updated(data)
signal profile_lookup_succeeded(data)
signal profile_lookup_failed(reason: String)

const SUPABASE_URL := "https://ugxkrdofwrgsefbssxoy.supabase.co"
const SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVneGtyZG9md3Jnc2VmYnNzeG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NzM0MjMsImV4cCI6MjA4NjM0OTQyM30.tsaSJRKUwECkpKjzK230u0HpyyjyU6DT9ctbIMJx1tE"

var access_token: String = ""
var refresh_token: String = ""
var current_user_id: String = ""
var current_email: String = ""
var current_display_name: String = ""
var guest_mode := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func continue_as_guest() -> void:
	guest_mode = true
	access_token = ""
	refresh_token = ""
	current_user_id = ""
	current_email = ""
	current_display_name = ""


func is_logged_in() -> bool:
	return access_token != "" and current_user_id != "" and !guest_mode


func logout() -> void:
	continue_as_guest()


func signup(email: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/auth/v1/signup"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var body_dict := {
		"email": email,
		"password": password
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_DICTIONARY and data.has("session") and data["session"] != null:
				var session = data["session"]
				access_token = str(session.get("access_token", ""))
				refresh_token = str(session.get("refresh_token", ""))

				if session.has("user") and session["user"] != null:
					var user = session["user"]
					current_user_id = str(user.get("id", ""))
					current_email = str(user.get("email", ""))
					guest_mode = false

			signup_succeeded.emit("Signup successful. Check email confirmation if required.")
		else:
			var msg := "Signup failed."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("msg"):
					msg = str(data["msg"])
				elif data.has("message"):
					msg = str(data["message"])
				elif data.has("error_description"):
					msg = str(data["error_description"])
			signup_failed.emit(msg)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)

func login(email: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var body_dict := {
		"email": email,
		"password": password
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_DICTIONARY:
				access_token = str(data.get("access_token", ""))
				refresh_token = str(data.get("refresh_token", ""))

				if data.has("user") and data["user"] != null:
					var user = data["user"]
					current_user_id = str(user.get("id", ""))
					current_email = str(user.get("email", ""))
					guest_mode = false
					login_succeeded.emit(current_user_id)
				else:
					login_failed.emit("Login succeeded, but no user data was returned.")
			else:
				login_failed.emit("Invalid login response.")
		else:
			var msg := "Login failed."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("msg"):
					msg = str(data["msg"])
				elif data.has("message"):
					msg = str(data["message"])
				elif data.has("error_description"):
					msg = str(data["error_description"])
			login_failed.emit(msg)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
func create_profile(display_name: String) -> void:
	if !is_logged_in():
		print("User must be logged in to create a profile.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/profiles"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var body_dict := {
		"id": current_user_id,
		"display_name": display_name
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				var d: Dictionary = data[0]
				current_display_name = str(d.get("display_name", ""))
			profile_created.emit(data)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)

func update_profile(display_name: String) -> void:
	if !is_logged_in():
		print("User must be logged in to update a profile.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/profiles?id=eq." + current_user_id
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var body_dict := {
		"display_name": display_name
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			profile_updated.emit(data)
		else:
			print("Update profile failed: ", text)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	
func get_my_profile() -> void:
	if !is_logged_in():
		profile_lookup_failed.emit("Must be logged in.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/profiles?id=eq." + current_user_id + "&select=*"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if result != HTTPRequest.RESULT_SUCCESS:
			profile_lookup_failed.emit("Network error while checking profile.")
			http.queue_free()
			return

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_ARRAY:
				var rows: Array = data
				if not rows.is_empty():
					var d: Dictionary = rows[0]
					current_display_name = str(d.get("display_name", ""))
			profile_lookup_succeeded.emit(data)
		else:
			profile_lookup_failed.emit("Profile lookup failed.")
			print("Get profile failed: ", text)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_GET)

func submit_run(score_total: int, duration_ms: int, waves_completed: int, total_fed: int, total_missed: int) -> void:
	if !is_logged_in():
		print("Guest users cannot submit runs.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	## Server RPC: one row per account; only updates when the new score is higher (see supabase/leaderboard_functions.sql).
	var url := SUPABASE_URL + "/rest/v1/rpc/submit_run_best"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var body_dict := {
		"p_score_total": score_total,
		"p_duration_ms": duration_ms,
		"p_waves_completed": waves_completed,
		"p_total_fed": total_fed,
		"p_total_missed": total_missed
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			run_submitted.emit(data)
		else:
			var err := "Could not save score."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("message"):
					err = str(data["message"])
				elif data.has("hint"):
					err = str(data["hint"])
			elif text.length() > 0 and text.length() < 200:
				err = text
			print("Submit run failed: ", text)
			run_submit_failed.emit(err)

		if is_logged_in():
			get_personal_best()

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func submit_run_endless(score_total: int, duration_ms: int, waves_completed: int, total_fed: int, total_missed: int) -> void:
	if !is_logged_in():
		print("Guest users cannot submit runs.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/rpc/submit_run_best_endless"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var body_dict := {
		"p_score_total": score_total,
		"p_duration_ms": duration_ms,
		"p_waves_completed": waves_completed,
		"p_total_fed": total_fed,
		"p_total_missed": total_missed
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			run_submitted.emit(data)
		else:
			var err := "Could not save score."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("message"):
					err = str(data["message"])
				elif data.has("hint"):
					err = str(data["hint"])
			elif text.length() > 0 and text.length() < 200:
				err = text
			print("Submit endless run failed: ", text)
			run_submit_failed.emit(err)

		if is_logged_in():
			get_personal_best_endless()

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func get_top_10() -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/rpc/get_top_10"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var body := "{}"

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		if result != HTTPRequest.RESULT_SUCCESS:
			leaderboard_failed.emit("Network error — check connection.")
			http.queue_free()
			return
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_ARRAY:
				leaderboard_received.emit(data)
			else:
				leaderboard_failed.emit("Unexpected response from server.")
		else:
			print("Get top 10 failed: ", text)
			var err_msg: String = text if text.length() > 0 else "Leaderboard request failed (%d)." % response_code
			if err_msg.length() > 180:
				err_msg = err_msg.substr(0, 177) + "..."
			leaderboard_failed.emit(err_msg)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func get_top_10_endless() -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/rpc/get_top_10_endless"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var body := "{}"

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		if result != HTTPRequest.RESULT_SUCCESS:
			leaderboard_endless_failed.emit("Network error — check connection.")
			http.queue_free()
			return
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if typeof(data) == TYPE_ARRAY:
				leaderboard_endless_received.emit(data)
			else:
				leaderboard_endless_failed.emit("Unexpected response from server.")
		else:
			print("Get top 10 endless failed: ", text)
			# Missing RPC / migration: show empty endless list instead of raw SQL in UI.
			var tl := text.to_lower()
			if response_code == 404 or "pgrst" in tl or "could not find the function" in tl:
				leaderboard_endless_received.emit([])
				http.queue_free()
				return
			var err_msg: String = text if text.length() > 0 else "Leaderboard request failed (%d)." % response_code
			if err_msg.length() > 180:
				err_msg = err_msg.substr(0, 177) + "..."
			leaderboard_endless_failed.emit(err_msg)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func get_personal_best() -> void:
	if !is_logged_in():
		print("Must be logged in to get personal best.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/rpc/get_personal_best"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var body_dict := {
		"p_user_id": current_user_id
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if result != HTTPRequest.RESULT_SUCCESS:
			personal_best_failed.emit("Network error.")
			http.queue_free()
			return
		if response_code >= 200 and response_code < 300:
			personal_best_received.emit(data)
		else:
			print("Get personal best failed: ", text)
			personal_best_failed.emit(text if text.length() > 0 else "Could not load account best.")

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func get_personal_best_endless() -> void:
	if !is_logged_in():
		print("Must be logged in to get personal best.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url := SUPABASE_URL + "/rest/v1/rpc/get_personal_best_endless"
	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var body_dict := {
		"p_user_id": current_user_id
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if result != HTTPRequest.RESULT_SUCCESS:
			personal_best_endless_failed.emit("Network error.")
			http.queue_free()
			return
		if response_code >= 200 and response_code < 300:
			personal_best_endless_received.emit(data)
		else:
			print("Get personal best endless failed: ", text)
			personal_best_endless_failed.emit(text if text.length() > 0 else "Could not load account best.")

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)
