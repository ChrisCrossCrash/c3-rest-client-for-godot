class_name C3OpenAIClient
extends Node
## General-purpose client for OpenAI-compatible HTTP APIs.

signal request_failed(error: Dictionary)

@export var base_url: String = "http://127.0.0.1:1234"
@export var api_key: String = "no-key"


## Returns the list of model IDs available on the server.
## Returns an empty array and emits [signal request_failed] on failure.
func get_models() -> PackedStringArray:
	var response := await _http_get(base_url + "/v1/models")
	if not response["ok"]:
		request_failed.emit(response["error"])
		return PackedStringArray()
	var parser := JSON.new()
	parser.parse((response["body"] as PackedByteArray).get_string_from_utf8())
	var json: Variant = parser.get_data()
	var ids := PackedStringArray()
	for m in json.get("data", []):
		ids.append(m["id"])
	return ids


## Internal HTTP request method. Can be overridden in tests.
func _http_get(url: String) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(url, _headers())
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": {"error": err}}
	var args: Array = await req.request_completed
	req.queue_free()
	var result: int = args[0]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": {"result": result}}
	return {"ok": true, "body": args[3] as PackedByteArray}


func _headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	return headers
