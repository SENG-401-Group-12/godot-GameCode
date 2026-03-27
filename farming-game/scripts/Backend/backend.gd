extends Node
class_name backend
const BackendWebConfig = preload("res://scripts/Backend/backend_web_config.gd")

signal login_succeeded(user_id: String)
signal login_failed(message: String)

signal signup_succeeded(message: String)
signal signup_failed(message: String)
signal password_reset_requested(message: String)
signal password_reset_failed(message: String)
signal password_reset_rate_limited(wait_seconds: int, message: String)
signal password_changed(message: String)
signal password_change_failed(message: String)
signal password_recovery_ready(email: String)
signal password_recovery_failed(message: String)

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
signal profile_update_failed(reason: String)
signal profile_lookup_succeeded(data)
signal profile_lookup_failed(reason: String)

## Filled from OS env (SUPABASE_URL, SUPABASE_ANON_KEY) and/or res://.env — see .env.example (never commit .env).
var supabase_url: String = ""
var supabase_anon_key: String = ""

var access_token: String = ""
var refresh_token: String = ""
var current_user_id: String = ""
var current_email: String = ""
var current_display_name: String = ""
var guest_mode := true

## Last finished run as guest: uploaded automatically after sign-in (see try_submit_pending_run_after_auth).
const PENDING_RUN_SAVE_PATH := "user://pending_guest_run.json"
var _pending_run_upload_in_progress := false


func _init() -> void:
	_load_supabase_config()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _load_supabase_config() -> void:
	var url := OS.get_environment("SUPABASE_URL").strip_edges()
	var key := OS.get_environment("SUPABASE_ANON_KEY").strip_edges()
	var from_file := _parse_dotenv_file("res://.env")
	var from_public_cfg := _parse_dotenv_file("res://supabase_web.cfg")
	var from_embedded_url := str(BackendWebConfig.SUPABASE_URL).strip_edges()
	var from_embedded_key := str(BackendWebConfig.SUPABASE_ANON_KEY).strip_edges()
	if url.is_empty():
		url = str(from_file.get("SUPABASE_URL", "")).strip_edges()
	if url.is_empty():
		url = str(from_public_cfg.get("SUPABASE_URL", "")).strip_edges()
	if url.is_empty():
		url = from_embedded_url
	if key.is_empty():
		key = str(from_file.get("SUPABASE_ANON_KEY", "")).strip_edges()
	if key.is_empty():
		key = str(from_public_cfg.get("SUPABASE_ANON_KEY", "")).strip_edges()
	if key.is_empty():
		key = from_embedded_key
	if url.begins_with("\"") and url.ends_with("\"") and url.length() >= 2:
		url = url.substr(1, url.length() - 2)
	if key.begins_with("\"") and key.ends_with("\"") and key.length() >= 2:
		key = key.substr(1, key.length() - 2)
	supabase_url = url
	supabase_anon_key = key
	if supabase_url.is_empty() or supabase_anon_key.is_empty():
		push_error(
			"Backend: Missing Supabase config. Set SUPABASE_URL and SUPABASE_ANON_KEY in the system environment "
			+ "or create farming-game/.env (copy from .env.example). Auth and leaderboards will fail until set."
		)
	elif OS.has_feature("web") and not supabase_url.begins_with("https://"):
		push_error("Backend: SUPABASE_URL must start with https:// for web builds.")


func _parse_dotenv_file(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Backend: could not open %s for reading." % path)
		return out
	var content := f.get_as_text()
	f.close()
	for raw_line in content.split("\n"):
		var line := raw_line.replace("\r", "").strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var eq := line.find("=")
		if eq <= 0:
			continue
		var k := line.substr(0, eq).strip_edges()
		var v := line.substr(eq + 1).strip_edges()
		if v.length() >= 2 and ((v.begins_with("\"") and v.ends_with("\"")) or (v.begins_with("'") and v.ends_with("'"))):
			v = v.substr(1, v.length() - 2)
		out[k] = v
	return out


## Supabase may gzip JSON; Godot Web's HTTP stack often cannot decode gzip. Ask for identity encoding.
func _supabase_headers(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var h := PackedStringArray([
		"apikey: " + supabase_anon_key,
		"Content-Type: application/json",
	])
	# Browsers block custom Accept-Encoding; sending it on Web causes request failures.
	if not OS.has_feature("web"):
		h.append("Accept-Encoding: identity")
	for s in extra:
		h.append(s)
	return h


func _has_supabase_config() -> bool:
	return not supabase_url.is_empty() and not supabase_anon_key.is_empty()


func _network_error_text(prefix: String, result: int) -> String:
	return "%s (%s: %d)." % [prefix, _http_result_name(result), result]


func _http_result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "TIMEOUT"
		_:
			return "RESULT_UNKNOWN"


func _new_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	# Avoid body decompression failures seen on some HTML5/Supabase responses.
	http.accept_gzip = false
	add_child(http)
	return http


func _parse_query_string(raw: String) -> Dictionary:
	var out: Dictionary = {}
	if raw.is_empty():
		return out
	for pair in raw.split("&"):
		if pair.is_empty():
			continue
		var eq := pair.find("=")
		var k := pair
		var v := ""
		if eq >= 0:
			k = pair.substr(0, eq)
			v = pair.substr(eq + 1)
		k = k.uri_decode().strip_edges()
		v = v.uri_decode().strip_edges()
		if not k.is_empty():
			out[k] = v
	return out


func _header_value(headers: PackedStringArray, name: String) -> String:
	var wanted := name.to_lower()
	for h in headers:
		var line := str(h)
		var idx := line.find(":")
		if idx <= 0:
			continue
		var key := line.substr(0, idx).strip_edges().to_lower()
		if key == wanted:
			return line.substr(idx + 1).strip_edges()
	return ""


func _extract_retry_after_seconds(response_headers: PackedStringArray) -> int:
	var retry_after_raw := _header_value(response_headers, "retry-after")
	if not retry_after_raw.is_empty():
		var as_int := int(retry_after_raw)
		if as_int > 0:
			return as_int
	var reset_unix_raw := _header_value(response_headers, "x-ratelimit-reset")
	if not reset_unix_raw.is_empty():
		var reset_unix := int(reset_unix_raw)
		var now_unix := int(Time.get_unix_time_from_system())
		var delta := reset_unix - now_unix
		if delta > 0:
			return delta
	return 0


func try_start_password_recovery_from_web_url() -> void:
	if not OS.has_feature("web"):
		return
	var hash_raw := str(JavaScriptBridge.eval("window.location.hash || ''", true)).strip_edges()
	if hash_raw.is_empty():
		return
	var hash := hash_raw
	if hash.begins_with("#"):
		hash = hash.substr(1)
	var params := _parse_query_string(hash)
	var has_recovery := str(params.get("type", "")) == "recovery"
	var has_error := params.has("error_description")
	if not has_recovery and not has_error:
		return
	JavaScriptBridge.eval("if (window.history && window.history.replaceState) { window.history.replaceState({}, document.title, window.location.pathname + window.location.search); } ''", true)
	if has_error:
		var err := str(params.get("error_description", "Recovery link is invalid or expired."))
		password_recovery_failed.emit(err)
		return
	var token := str(params.get("access_token", "")).strip_edges()
	var refresh := str(params.get("refresh_token", "")).strip_edges()
	if token.is_empty():
		password_recovery_failed.emit("Recovery token missing in URL.")
		return
	access_token = token
	refresh_token = refresh
	guest_mode = false

	var http := _new_http_request()
	var url := supabase_url + "/auth/v1/user"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
	]))
	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if result != HTTPRequest.RESULT_SUCCESS:
			password_recovery_failed.emit(_network_error_text("Could not verify recovery session", result))
			http.queue_free()
			return
		if response_code >= 200 and response_code < 300 and typeof(data) == TYPE_DICTIONARY:
			var d: Dictionary = data
			current_user_id = str(d.get("id", ""))
			current_email = str(d.get("email", ""))
			password_recovery_ready.emit(current_email)
		else:
			password_recovery_failed.emit("Recovery link is invalid or expired.")
		http.queue_free()
	)
	var req_err := http.request(url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		password_recovery_failed.emit(_network_error_text("Could not start recovery verification", req_err))
		http.queue_free()


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


func save_pending_run_if_guest(
	score_total: int,
	duration_ms: int,
	waves_completed: int,
	total_fed: int,
	total_missed: int,
	is_endless_mode: bool
) -> void:
	if is_logged_in():
		return
	var payload := {
		"score_total": score_total,
		"duration_ms": duration_ms,
		"waves_completed": waves_completed,
		"total_fed": total_fed,
		"total_missed": total_missed,
		"is_endless_mode": is_endless_mode,
	}
	var f := FileAccess.open(PENDING_RUN_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Backend: could not write pending guest run file.")
		return
	f.store_string(JSON.stringify(payload))
	f.close()


func _erase_pending_run_file() -> void:
	if not FileAccess.file_exists(PENDING_RUN_SAVE_PATH):
		return
	var abs_path := ProjectSettings.globalize_path(PENDING_RUN_SAVE_PATH)
	DirAccess.remove_absolute(abs_path)


## Call after login or signup when a session exists so a guest run can be uploaded retroactively.
func try_submit_pending_run_after_auth() -> void:
	if not is_logged_in():
		return
	if _pending_run_upload_in_progress:
		return
	if not FileAccess.file_exists(PENDING_RUN_SAVE_PATH):
		return
	var f := FileAccess.open(PENDING_RUN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_erase_pending_run_file()
		return
	var d: Dictionary = parsed
	var score := int(d.get("score_total", 0))
	var dur := int(d.get("duration_ms", 0))
	var waves := int(d.get("waves_completed", 0))
	var fed := int(d.get("total_fed", 0))
	var missed := int(d.get("total_missed", 0))
	var endless := bool(d.get("is_endless_mode", false))
	_pending_run_upload_in_progress = true
	submit_run(score, dur, waves, fed, missed, endless)


func signup(email: String, password: String) -> void:
	if not _has_supabase_config():
		signup_failed.emit("Backend config missing on this build. Please contact support.")
		return
	var http := _new_http_request()

	var url := supabase_url + "/auth/v1/signup"
	var headers := _supabase_headers()

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

			if is_logged_in():
				call_deferred(&"try_submit_pending_run_after_auth")
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

	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		signup_failed.emit(_network_error_text("Could not start signup request", req_err))
		http.queue_free()

func login(email: String, password: String) -> void:
	if not _has_supabase_config():
		login_failed.emit("Backend config missing on this build. Please contact support.")
		return
	var http := _new_http_request()

	var url := supabase_url + "/auth/v1/token?grant_type=password"
	var headers := _supabase_headers()

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
					call_deferred(&"try_submit_pending_run_after_auth")
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

	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		login_failed.emit(_network_error_text("Could not start login request", req_err))
		http.queue_free()


func request_password_reset(email: String) -> void:
	if not _has_supabase_config():
		password_reset_failed.emit("Backend config missing on this build. Please contact support.")
		return
	var http := _new_http_request()
	var url := supabase_url + "/auth/v1/recover"
	var headers := _supabase_headers()
	var body := JSON.stringify({"email": email})
	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if result != HTTPRequest.RESULT_SUCCESS:
			password_reset_failed.emit(_network_error_text("Could not send reset email", result))
			http.queue_free()
			return
		if response_code >= 200 and response_code < 300:
			password_reset_requested.emit("If this email exists, a reset link was sent.")
		else:
			var msg := "Could not send reset email."
			var retry_secs := _extract_retry_after_seconds(response_headers)
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("msg"):
					msg = str(data["msg"])
				elif data.has("message"):
					msg = str(data["message"])
				elif data.has("error_description"):
					msg = str(data["error_description"])
			var lowered := msg.to_lower()
			if retry_secs > 0 and (response_code == 429 or lowered.contains("rate") or lowered.contains("too many")):
				password_reset_rate_limited.emit(retry_secs, msg)
				http.queue_free()
				return
			password_reset_failed.emit(msg)
		http.queue_free()
	)
	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		password_reset_failed.emit(_network_error_text("Could not start reset request", req_err))
		http.queue_free()


func change_password(new_password: String) -> void:
	if access_token.strip_edges().is_empty():
		password_change_failed.emit("No active session. Use a fresh reset link.")
		return
	if not _has_supabase_config():
		password_change_failed.emit("Backend config missing on this build.")
		return
	var http := _new_http_request()
	var url := supabase_url + "/auth/v1/user"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
	]))
	var body := JSON.stringify({"password": new_password})
	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if result != HTTPRequest.RESULT_SUCCESS:
			password_change_failed.emit(_network_error_text("Could not change password", result))
			http.queue_free()
			return
		if response_code >= 200 and response_code < 300:
			password_changed.emit("Password updated.")
		else:
			var msg := "Could not change password."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("msg"):
					msg = str(data["msg"])
				elif data.has("message"):
					msg = str(data["message"])
				elif data.has("error_description"):
					msg = str(data["error_description"])
			password_change_failed.emit(msg)
		http.queue_free()
	)
	var req_err := http.request(url, headers, HTTPClient.METHOD_PUT, body)
	if req_err != OK:
		password_change_failed.emit(_network_error_text("Could not start password change request", req_err))
		http.queue_free()
	
func create_profile(display_name: String) -> void:
	if !is_logged_in():
		print("User must be logged in to create a profile.")
		return

	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/profiles"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
		"Prefer: return=representation",
	]))

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

	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/profiles?id=eq." + current_user_id
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
		"Prefer: return=representation",
	]))

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
			var msg := "Could not update username."
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("message"):
					msg = str(data["message"])
				elif data.has("msg"):
					msg = str(data["msg"])
				elif data.has("hint"):
					msg = str(data["hint"])
			elif text.length() > 0 and text.length() < 220:
				msg = text
			profile_update_failed.emit(msg)
			print("Update profile failed: ", text)

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	
func get_my_profile() -> void:
	if !is_logged_in():
		profile_lookup_failed.emit("Must be logged in.")
		return
	if not _has_supabase_config():
		profile_lookup_failed.emit("Backend config missing on this build.")
		return

	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/profiles?id=eq." + current_user_id + "&select=*"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
	]))

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text: String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if result != HTTPRequest.RESULT_SUCCESS:
			profile_lookup_failed.emit(_network_error_text("Network error while checking profile", result))
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

	var req_err := http.request(url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		profile_lookup_failed.emit(_network_error_text("Could not start profile request", req_err))
		http.queue_free()

func submit_run(score_total: int, duration_ms: int, waves_completed: int, total_fed: int, total_missed: int, is_endless_mode: bool) -> void:
	if !is_logged_in():
		print("Guest users cannot submit runs.")
		return

	var http := _new_http_request()

	var rpc_name := "submit_run_best_endless" if is_endless_mode else "submit_run_best"
	var url := supabase_url + "/rest/v1/rpc/" + rpc_name
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
	]))

	var body_dict := {
		"p_score_total": score_total,
		"p_duration_ms": duration_ms,
		"p_waves_completed": waves_completed,
		"p_total_fed": total_fed,
		"p_total_missed": total_missed,
	}
	var body := JSON.stringify(body_dict)

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		var text : String = response_body.get_string_from_utf8()
		var data = JSON.parse_string(text)

		if response_code >= 200 and response_code < 300:
			if _pending_run_upload_in_progress:
				_pending_run_upload_in_progress = false
				_erase_pending_run_file()
			run_submitted.emit(data)
			if is_logged_in():
				get_personal_best(is_endless_mode)
		else:
			if _pending_run_upload_in_progress:
				_pending_run_upload_in_progress = false
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

		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)

func get_top_10() -> void:
	if not _has_supabase_config():
		leaderboard_failed.emit("Backend config missing on this build.")
		return
	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/rpc/get_top_10_normal"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + supabase_anon_key,
	]))

	var body := "{}"

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		if result != HTTPRequest.RESULT_SUCCESS:
			leaderboard_failed.emit(_network_error_text("Network error", result))
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

	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		leaderboard_failed.emit(_network_error_text("Could not start leaderboard request", req_err))
		http.queue_free()


func get_top_10_endless() -> void:
	if not _has_supabase_config():
		leaderboard_endless_failed.emit("Backend config missing on this build.")
		return
	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/rpc/get_top_10_endless"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + supabase_anon_key,
	]))

	var body := "{}"

	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		if result != HTTPRequest.RESULT_SUCCESS:
			leaderboard_endless_failed.emit(_network_error_text("Network error", result))
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

	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		leaderboard_endless_failed.emit(_network_error_text("Could not start endless request", req_err))
		http.queue_free()

func get_personal_best(is_endless_mode: bool) -> void:
	if !is_logged_in():
		print("Must be logged in to get personal best.")
		return

	var http := _new_http_request()

	var url := supabase_url + "/rest/v1/rpc/get_personal_best"
	var headers := _supabase_headers(PackedStringArray([
		"Authorization: Bearer " + access_token,
	]))

	var body_dict := {
		"p_user_id": current_user_id,
		"p_is_endless_mode": is_endless_mode
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
