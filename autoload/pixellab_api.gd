extends Node
## Client for the PixelLab REST API (v2).
##
## Flow (https://api.pixellab.ai/v2/openapi.json):
##   POST /create-image-pixflux-background   -> 202 {"background_job_id": "..."}
##   GET  /background-jobs/{id}  (poll)       -> {"status": "processing|completed|failed",
##                                                "last_response": {"image": {"base64": "..."}}}
##   DELETE /background-jobs/{id}             -> cancel on timeout
##
## SECURITY: an API token inside a shipped app (APK, Web build) can be extracted by
## anyone. For releases, point `[pixellab] base_url` at your own proxy (server/proxy.mjs)
## which injects the token server-side; this client then sends no Authorization header.
## For local development you can use PIXELLAB_API_TOKEN or user://pixellab.cfg instead.
##
## Config sources, later wins: project.godot [pixellab] base_url -> env PIXELLAB_BASE_URL /
## PIXELLAB_API_TOKEN -> user://pixellab.cfg ([api] base_url, token).

signal progress(request_id: int, status: String, elapsed_sec: float)

enum Err {
	NONE,
	NOT_CONFIGURED,
	UNAUTHORIZED,
	NO_CREDITS,
	BUSY,
	NETWORK,
	FAILED,
	TIMEOUT,
	BAD_REQUEST,
}

const OFFICIAL_BASE_URL := "https://api.pixellab.ai/v2"
const CONFIG_PATH := "user://pixellab.cfg"
const POLL_INTERVAL_SEC := 3.0
const TIMEOUT_SEC := 150.0
const HTTP_TIMEOUT_SEC := 30.0
const STYLE_SUFFIX := ", pixel art illustration, bold simple shapes, vibrant clear colors, full scene with background"
const NEGATIVE := "text, letters, watermark, blurry, noisy, dithering"

var base_url: String = OFFICIAL_BASE_URL
var token: String = ""
var _next_id: int = 1


func _ready() -> void:
	base_url = str(ProjectSettings.get_setting("pixellab/base_url", OFFICIAL_BASE_URL))
	var env_url := OS.get_environment("PIXELLAB_BASE_URL")
	if env_url != "":
		base_url = env_url
	token = OS.get_environment("PIXELLAB_API_TOKEN")
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		base_url = str(cfg.get_value("api", "base_url", base_url))
		token = str(cfg.get_value("api", "token", token))
	base_url = base_url.rstrip("/")


## A custom base URL means a proxy that owns the token, so no local token is needed.
func is_configured() -> bool:
	return token != "" or base_url != OFFICIAL_BASE_URL


func message_for(err: Err) -> String:
	match err:
		Err.NOT_CONFIGURED: return tr("AI generation is not set up yet.")
		Err.UNAUTHORIZED: return tr("Invalid API token.")
		Err.NO_CREDITS: return tr("Out of credits.")
		Err.BUSY: return tr("The service is busy. Try again in a moment.")
		Err.NETWORK: return tr("Network error. Check your connection.")
		Err.TIMEOUT: return tr("Timed out waiting for the image.")
		_: return tr("The image could not be generated.")


## Generates a `size` x `size` picture from a text prompt.
## Returns {ok, image: Image, texture: ImageTexture, job_id, error: Err, message}.
## Usage:  var r := await PixelLabAPI.generate_image("a sleepy panda")
func generate_image(description: String, size: int = 64, options: Dictionary = {}) -> Dictionary:
	var rid := _next_id
	_next_id += 1
	if not is_configured():
		return _fail(Err.NOT_CONFIGURED)

	var body := {
		"description": description + STYLE_SUFFIX,
		"negative_description": NEGATIVE,
		"image_size": {"width": size, "height": size},
		"no_background": false,
		"detail": "medium detail",
		"shading": "basic shading",
		"outline": "selective outline",
	}
	body.merge(options, true)

	var started := await _request(HTTPClient.METHOD_POST, "/create-image-pixflux-background", body)
	if not started.ok:
		return started
	var job_id: String = str(started.json.get("background_job_id", ""))
	if job_id == "":
		return _fail(Err.FAILED, "response had no background_job_id")

	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().create_timer(POLL_INTERVAL_SEC).timeout
		var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
		progress.emit(rid, "processing", elapsed)
		if elapsed > TIMEOUT_SEC:
			_request(HTTPClient.METHOD_DELETE, "/background-jobs/%s" % job_id)  # fire and forget
			return _fail(Err.TIMEOUT)

		var poll := await _request(HTTPClient.METHOD_GET, "/background-jobs/%s" % job_id)
		if not poll.ok:
			if poll.error == Err.BUSY:
				continue  # rate-limited while polling: just wait for the next tick
			return poll
		var status: String = str(poll.json.get("status", ""))
		if status == "completed":
			return await _finish(poll.json.get("last_response", {}), job_id)
		if status == "failed":
			var last: Dictionary = poll.json.get("last_response", {}) if poll.json.get("last_response") is Dictionary else {}
			return _fail(Err.FAILED, str(last.get("error", last.get("detail", "job failed"))))
	return _fail(Err.FAILED)  # unreachable, keeps the parser happy


## Downloads the result and turns it into Image + ImageTexture (spec items 1.3).
func _finish(last_response: Variant, job_id: String) -> Dictionary:
	if not (last_response is Dictionary) or not (last_response.get("image") is Dictionary):
		return _fail(Err.FAILED, "completed job has no image")
	var meta: Dictionary = last_response["image"]
	var bytes := PackedByteArray()
	if meta.has("base64"):
		bytes = Marshalls.base64_to_raw(str(meta["base64"]))
	elif meta.has("url"):
		var dl := await _download(str(meta["url"]))
		if not dl.ok:
			return dl
		bytes = dl.bytes
	if bytes.is_empty():
		return _fail(Err.FAILED, "empty image payload")

	var image := decode_image(bytes, str(meta.get("format", "png")))
	if image == null:
		return _fail(Err.FAILED, "could not decode image")
	return {
		"ok": true,
		"image": image,
		"texture": ImageTexture.create_from_image(image),
		"job_id": job_id,
		"error": Err.NONE,
		"message": "",
	}


static func decode_image(bytes: PackedByteArray, format: String = "png") -> Image:
	var img := Image.new()
	var e: Error
	match format.to_lower():
		"jpg", "jpeg": e = img.load_jpg_from_buffer(bytes)
		"webp": e = img.load_webp_from_buffer(bytes)
		_: e = img.load_png_from_buffer(bytes)
	if e != OK:
		# The declared format can lie; sniff the PNG signature before giving up.
		if bytes.size() > 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
			e = img.load_png_from_buffer(bytes)
	return img if e == OK else null


# -- HTTP plumbing ----------------------------------------------------------------

func _request(method: int, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT_SEC
	add_child(http)

	var headers := PackedStringArray(["Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)

	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _fail(Err.NETWORK, "request() returned %s" % error_string(err))
	var res: Array = await http.request_completed
	http.queue_free()

	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail(Err.NETWORK, "HTTPRequest result %d" % result)

	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	var json: Dictionary = parsed if parsed is Dictionary else {}
	if code >= 200 and code < 300:
		return {"ok": true, "status": code, "json": json}

	var detail := str(json.get("detail", json.get("error", "")))
	match code:
		401, 403: return _fail(Err.UNAUTHORIZED, detail)
		402: return _fail(Err.NO_CREDITS, detail)
		429: return _fail(Err.BUSY, detail)
		400, 422: return _fail(Err.BAD_REQUEST, detail)
		_: return _fail(Err.FAILED, "HTTP %d %s" % [code, detail])


func _download(url: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT_SEC
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return _fail(Err.NETWORK)
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return _fail(Err.NETWORK, "download failed (HTTP %d)" % res[1])
	return {"ok": true, "bytes": res[3]}


func _fail(err: Err, detail: String = "") -> Dictionary:
	if detail != "":
		push_warning("PixelLabAPI: %s (%s)" % [Err.keys()[err], detail])
	return {"ok": false, "error": err, "message": message_for(err), "detail": detail}
