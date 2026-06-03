@tool
class_name C3OpenAIClient
extends Node
## General-purpose client for OpenAI-compatible HTTP APIs.


## Structured error placed on the [code]error[/code] field of every response
## object when [code]ok[/code] is [code]false[/code], and carried by
## [signal request_failed].
class ApiError:
	## Broad category of failure:[br]
	## [code]&"transport"[/code] — no usable HTTP response (DNS, connection, TLS,
	## or the request could not be started).[br]
	## [code]&"http"[/code] — a non-2xx status with no parseable API error body.[br]
	## [code]&"api"[/code] — the server returned a structured error body.[br]
	## [code]&"parse"[/code] — a 2xx body that could not be understood.[br]
	## [code]&"client"[/code] — the request was rejected before being sent (e.g.
	## an invalid argument).[br]
	## [code]&"cancelled"[/code] — the caller aborted the request.
	var kind: StringName = &""
	## Human-readable description. Never empty.
	var message: String = ""
	## HTTP status code, or [code]0[/code] when not applicable.
	var status: int = 0
	## Machine-readable API error code (e.g. [code]"invalid_api_key"[/code]), or
	## [code]""[/code] if absent.
	var code: String = ""
	## API error type (e.g. [code]"invalid_request_error"[/code]), or [code]""[/code].
	var type: String = ""
	## Raw response body, for debugging. May be [code]""[/code].
	var raw: String = ""

	## Builds an error for a transport-level failure with no usable HTTP response.
	static func transport(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"transport"
		e.message = p_message
		return e

	## Builds an error for a 2xx response whose body could not be understood.
	static func parse_failure(
		p_message: String, p_raw: String = ""
	) -> ApiError:
		var e := ApiError.new()
		e.kind = &"parse"
		e.message = p_message
		e.raw = p_raw
		return e

	## Builds an error for a caller-initiated cancellation.
	static func cancelled(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"cancelled"
		e.message = p_message
		return e

	## Builds an error for a request rejected before being sent (bad argument).
	static func client_error(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"client"
		e.message = p_message
		return e

	## Builds an error from a non-2xx response, pulling the server's own
	## [code]{"error": {...}}[/code] body when present. Falls back to a generic
	## HTTP-status message otherwise.
	static func from_response(p_status: int, body: PackedByteArray) -> ApiError:
		var e := ApiError.new()
		e.kind = &"http"
		e.status = p_status
		e.raw = body.get_string_from_utf8()
		e.message = "Request failed with status %d." % p_status
		var parser := JSON.new()
		if parser.parse(e.raw) == OK and parser.get_data() is Dictionary:
			var api_err: Variant = (parser.get_data() as Dictionary).get("error")
			if api_err is Dictionary:
				var d: Dictionary = api_err
				e.kind = &"api"
				if d.get("message") is String:
					e.message = d["message"]
				if d.get("code") is String:
					e.code = d["code"]
				if d.get("type") is String:
					e.type = d["type"]
		return e

	func _to_string() -> String:
		var parts := PackedStringArray(["[%s]" % kind])
		if status != 0:
			parts.append("status=%d" % status)
		if not code.is_empty():
			parts.append("code=%s" % code)
		parts.append(message)
		return " ".join(parts)


## Emitted when a request fails. The [member ok] field of the returned response
## object is the primary way to detect failure; this signal is a secondary
## broadcast for optional cross-cutting concerns such as global error logging.
signal request_failed(error: ApiError)

## The base URL of the OpenAI-compatible API, including the version path.
## For example, [code]"https://api.openai.com/v1"[/code] for OpenAI or
## [code]"http://127.0.0.1:1234/v1"[/code] for a local server.
@export var base_url: String = "http://127.0.0.1:1234/v1"
## The API key sent as a Bearer token in the [code]Authorization[/code] header.
## Set to any non-empty value for servers that don't require authentication.
var api_key: String = "no-key"


## Optional parameters for a text-to-speech request.
class SpeechOptions:
	var model: String = ""
	var voice: String = ""
	## Sample rate of the [code]"pcm"[/code] response. Must match the server's
	## output. OpenAI and speaches both default to 24000 Hz.
	var pcm_sample_rate: int = 24000
	## Whether the [code]"pcm"[/code] response is stereo. Most TTS servers
	## output mono. Set to [code]true[/code] if the server produces stereo PCM.
	var pcm_stereo: bool = false


## The response returned by [method create_speech].
class SpeechResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	## The resulting audio stream. Only valid when [member ok] is [code]true[/code].
	var stream: AudioStream


## The response returned by [method create_transcription].
class TranscriptionResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	var text: String = ""


## Optional parameters for a transcription request.
class TranscriptionOptions:
	var model: String = ""
	## BCP-47 language code (e.g. [code]"en"[/code]). Leave empty to auto-detect.
	var language: String = ""


## Optional parameters for a chat completion request.
class ChatOptions:
	var model: String = ""
	## Leave as [constant @GDScript.NAN] to omit temperature from the request entirely.
	var temperature: float = NAN
	## Set to -1 to omit max_tokens from the request entirely.
	var max_tokens: int = -1
	## One or more sequences where generation stops. Leave empty to omit from the request.
	var stop: PackedStringArray = PackedStringArray()


## The response returned by [method chat_completion].
class ChatCompletionResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	var content: String = ""
	var refusal: String = ""
	var finish_reason: String = ""
	var model: String = ""
	var usage: Dictionary = {}


## A handle to an in-progress streaming chat completion, returned by
## [method chat_completion_stream]. Emits [signal delta] as text arrives and
## [signal finished] exactly once when the stream ends.
class ChatStream:
	extends Node

	## Emitted for each incremental piece of generated text as it arrives.
	signal delta(text: String)
	## Emitted exactly once when the stream ends — on success, on error, or
	## after [method cancel]. Carries the same [ChatCompletionResponse] that
	## [method chat_completion] returns.
	signal finished(result: ChatCompletionResponse)

	var _sse: C3SSERequest
	var _client: C3OpenAIClient
	var _res := ChatCompletionResponse.new()
	var _content := ""
	var _refusal := ""
	var _done := false

	# Kicks off the request. Called by chat_completion_stream() right after the
	# stream is added to the tree.
	func _start(
		sse: C3SSERequest,
		url: String,
		headers: PackedStringArray,
		body: String,
		client: C3OpenAIClient
	) -> void:
		_client = client
		_sse = sse
		add_child(_sse)
		_sse.event_received.connect(_on_event_received)
		_sse.finished.connect(_on_sse_finished)
		_sse.response_error.connect(_on_response_error)
		_sse.request_failed.connect(_on_sse_request_failed)
		var err := _sse.request(url, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			# Defer so the caller can connect to `finished` before it fires —
			# _start() runs synchronously inside chat_completion_stream().
			_resolve.call_deferred(
				false,
				ApiError.transport(
					"Failed to start stream request (error %d)." % err
				),
				true
			)

	## Aborts the in-flight request and resolves [signal finished] with
	## [member ChatCompletionResponse.ok] set to [code]false[/code].
	func cancel() -> void:
		_resolve(false, ApiError.cancelled("Stream cancelled."), false)

	func _on_response_error(code: int, body: String) -> void:
		_resolve(
			false, ApiError.from_response(code, body.to_utf8_buffer()), true
		)

	func _on_event_received(data: String, _event_type: String) -> void:
		if _done or data == "[DONE]":
			return
		var parser := JSON.new()
		if parser.parse(data) != OK:
			return
		var json: Variant = parser.get_data()
		if not json is Dictionary:
			return
		var json_dict: Dictionary = json
		var model: Variant = json_dict.get("model")
		if model is String and not (model as String).is_empty():
			_res.model = model
		var raw_usage: Variant = json_dict.get("usage")
		if raw_usage is Dictionary:
			_res.usage = {
				"prompt_tokens": int(raw_usage.get("prompt_tokens", 0)),
				"completion_tokens": int(raw_usage.get("completion_tokens", 0)),
				"total_tokens": int(raw_usage.get("total_tokens", 0)),
			}
		var choices: Variant = json_dict.get("choices")
		if not choices is Array or (choices as Array).is_empty():
			return
		var choice: Dictionary = (choices as Array)[0]
		var finish_reason: Variant = choice.get("finish_reason")
		if finish_reason is String:
			_res.finish_reason = finish_reason
		var delta_obj: Variant = choice.get("delta")
		if not delta_obj is Dictionary:
			return
		var delta_dict: Dictionary = delta_obj
		var piece: Variant = delta_dict.get("content")
		if piece is String and not (piece as String).is_empty():
			_content += piece
			delta.emit(piece)
		var refusal_piece: Variant = delta_dict.get("refusal")
		if refusal_piece is String:
			_refusal += refusal_piece

	func _on_sse_finished() -> void:
		_resolve(true, null, false)

	func _on_sse_request_failed(reason: String) -> void:
		_resolve(false, ApiError.transport(reason), true)

	# Single exit point: fills in the result, tears down the SSE node, and emits
	# finished once. `broadcast` re-emits the client's request_failed signal for
	# genuine failures (not user cancellation), mirroring chat_completion().
	func _resolve(ok: bool, error: ApiError, broadcast: bool) -> void:
		if _done:
			return
		_done = true
		_res.ok = ok
		_res.error = error
		if ok:
			_res.content = _content
			_res.refusal = _refusal
		if is_instance_valid(_sse):
			_sse.queue_free()
			_sse = null
		if broadcast and is_instance_valid(_client):
			_client.request_failed.emit(error)
		finished.emit(_res)
		queue_free()


## The response returned by [method get_models].
class ModelsResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	var ids: PackedStringArray = PackedStringArray()


## Returns the list of model IDs available on the server.
## Returns a [ModelsResponse] with [member ModelsResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] on failure.
func get_models() -> ModelsResponse:
	var response := await _http_get(base_url + "/models", _headers())
	var res := ModelsResponse.new()
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var body_str := (response["body"] as PackedByteArray).get_string_from_utf8()
	var parser := JSON.new()
	if parser.parse(body_str) != OK:
		res.ok = false
		res.error = ApiError.parse_failure(
			"Failed to parse models response as JSON.", body_str
		)
		request_failed.emit(res.error)
		return res
	var json: Variant = parser.get_data()
	var data: Variant = json.get("data") if json is Dictionary else null
	if not data is Array:
		res.ok = false
		res.error = ApiError.parse_failure(
			'Models response JSON missing "data" array.', body_str
		)
		request_failed.emit(res.error)
		return res
	# Skip malformed entries rather than failing the whole list.
	for m in (data as Array):
		if m is Dictionary and (m as Dictionary).get("id") is String:
			res.ids.append((m as Dictionary)["id"])
	return res


## Sends a chat completion request and returns the model's response.
## Returns a [ChatCompletionResponse] with [member ChatCompletionResponse.ok]
## set to [code]false[/code] and emits [signal request_failed] on failure.
func chat_completion(
	messages: Array, opts: ChatOptions = null
) -> ChatCompletionResponse:
	if opts == null:
		opts = ChatOptions.new()
	var body := _build_chat_body(messages, opts)
	var response := await _http_post(
		base_url + "/chat/completions", body, _headers()
	)
	var res := ChatCompletionResponse.new()
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var body_str := (response["body"] as PackedByteArray).get_string_from_utf8()
	var parser := JSON.new()
	if parser.parse(body_str) != OK:
		res.ok = false
		res.error = ApiError.parse_failure(
			"Failed to parse response body as JSON.", body_str
		)
		request_failed.emit(res.error)
		return res
	var json: Variant = parser.get_data()
	var choices: Variant = json.get("choices") if json is Dictionary else null
	if not choices is Array or (choices as Array).is_empty():
		res.ok = false
		res.error = ApiError.parse_failure(
			"Response JSON missing choices.", body_str
		)
		request_failed.emit(res.error)
		return res
	var json_dict: Dictionary = json
	var choice: Dictionary = (choices as Array)[0]
	var message: Dictionary = choice["message"]
	var content: Variant = message.get("content")
	res.content = content if content is String else ""
	var refusal: Variant = message.get("refusal")
	res.refusal = refusal if refusal is String else ""
	res.finish_reason = choice["finish_reason"]
	res.model = json_dict.get("model", "")
	var raw_usage: Dictionary = json_dict.get("usage", {})
	res.usage = {
		"prompt_tokens": int(raw_usage.get("prompt_tokens", 0)),
		"completion_tokens": int(raw_usage.get("completion_tokens", 0)),
		"total_tokens": int(raw_usage.get("total_tokens", 0)),
	}
	return res


## Sends a streaming chat completion request and returns a [ChatStream] handle.
## Connect to [signal ChatStream.delta] for incremental text and
## [code]await[/code] [signal ChatStream.finished] for the final
## [ChatCompletionResponse]. On a non-200 response or transport error the
## result's [member ChatCompletionResponse.ok] is [code]false[/code] and
## [signal request_failed] is emitted, mirroring [method chat_completion].
func chat_completion_stream(
	messages: Array, opts: ChatOptions = null
) -> ChatStream:
	if opts == null:
		opts = ChatOptions.new()
	var body := _build_chat_body(messages, opts)
	body["stream"] = true
	var stream := ChatStream.new()
	add_child(stream)
	stream._start(
		_make_sse_request(),
		base_url + "/chat/completions",
		_headers(),
		JSON.stringify(body),
		self
	)
	return stream


# Creates the [C3SSERequest] used by [method chat_completion_stream].
# Overridable in tests to substitute a fake transport.
func _make_sse_request() -> C3SSERequest:
	return C3SSERequest.new()


# Assembles the JSON request body shared by chat_completion() and
# chat_completion_stream(). Warns when no model is set.
func _build_chat_body(messages: Array, opts: ChatOptions) -> Dictionary:
	if opts.model.is_empty():
		push_warning(
			(
				"C3OpenAIClient: opts.model is empty — using server default. "
				+ "Set opts.model explicitly when targeting OpenAI."
			)
		)
	var body: Dictionary = {
		"model": opts.model,
		"messages": messages,
	}
	if not is_nan(opts.temperature):
		body["temperature"] = opts.temperature
	if opts.max_tokens != -1:
		body["max_tokens"] = opts.max_tokens
	if not opts.stop.is_empty():
		body["stop"] = opts.stop
	return body


## Helper function for constructing a user message
## dictionary for the OpenAI chat API. [br]
## Returns:[br]
## [code]{"role": "user", "content": content}[/code]
static func make_user_msg(content: String) -> Dictionary:
	return {"role": "user", "content": content}


## Helper function for constructing an assistant message
## dictionary for the OpenAI chat API. [br]
## Returns:[br]
## [code]{"role": "assistant", "content": content}[/code]
static func make_assistant_msg(content: String) -> Dictionary:
	return {"role": "assistant", "content": content}


## Helper function for constructing a system message
## dictionary for the OpenAI chat API. [br]
## Returns:[br]
## [code]{"role": "system", "content": content}[/code]
static func make_system_msg(content: String) -> Dictionary:
	return {"role": "system", "content": content}


## Constructs a text content part for use with [method make_user_msg_with_parts]. [br]
## Returns:[br]
## [code]{"type": "text", "text": text}[/code]
static func make_part_text(text: String) -> Dictionary:
	return {"type": "text", "text": text}


## Constructs an image URL content part for use with [method make_user_msg_with_parts]. [br]
## [param url] may be an [code]https://[/code] URL or a [code]data:[/code] URI
## (e.g. [code]"data:image/png;base64,..."[/code]). [br]
## [param detail] controls resolution sampling: [code]"auto"[/code] (default),
## [code]"low"[/code], or [code]"high"[/code]. [br]
## Returns:[br]
## [code]{"type": "image_url", "image_url": {"url": url, "detail": detail}}[/code]
static func make_part_image_url(
	url: String, detail: String = "auto"
) -> Dictionary:
	return {"type": "image_url", "image_url": {"url": url, "detail": detail}}


## Constructs a user message whose content is an array of content parts
## built with [method make_part_text] and [method make_part_image_url]. [br]
## Returns:[br]
## [code]{"role": "user", "content": parts}[/code]
static func make_user_msg_with_parts(parts: Array) -> Dictionary:
	return {"role": "user", "content": parts}


## Sends a text-to-speech request and returns a [SpeechResponse].
## The server must return raw 16-bit signed little-endian PCM (request format
## [code]"pcm"[/code]). Use [member SpeechOptions.pcm_sample_rate] and
## [member SpeechOptions.pcm_stereo] to match the server's output. [br]
## Returns a [SpeechResponse] with [member SpeechResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] on failure.
func create_speech(input: String, opts: SpeechOptions = null) -> SpeechResponse:
	if opts == null:
		opts = SpeechOptions.new()
	var body := {
		"model": opts.model,
		"input": input,
		"voice": opts.voice,
		"response_format": "pcm",
	}
	var response := await _http_post(
		base_url + "/audio/speech", body, _headers()
	)
	var res := SpeechResponse.new()
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var wav := AudioStreamWAV.new()
	wav.data = response["body"]
	wav.stereo = opts.pcm_stereo
	wav.mix_rate = opts.pcm_sample_rate
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	res.stream = wav
	return res


## Transcribes an [AudioStream] and returns a [TranscriptionResponse].
## Supports [AudioStreamMP3] and [AudioStreamWAV] as input.
## Returns a [TranscriptionResponse] with [member TranscriptionResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] on failure.
func create_transcription(
	audio: AudioStream, opts: TranscriptionOptions = null
) -> TranscriptionResponse:
	if opts == null:
		opts = TranscriptionOptions.new()
	var res := TranscriptionResponse.new()
	var audio_bytes: PackedByteArray
	var filename: String
	var file_content_type: String
	if audio is AudioStreamMP3:
		audio_bytes = (audio as AudioStreamMP3).data
		filename = "audio.mp3"
		file_content_type = "audio/mpeg"
	elif audio is AudioStreamWAV:
		audio_bytes = _audio_stream_wav_to_bytes(audio as AudioStreamWAV)
		filename = "audio.wav"
		file_content_type = "audio/wav"
	else:
		push_error(
			"C3OpenAIClient: Unsupported AudioStream type. Only AudioStreamMP3 and AudioStreamWAV are supported."
		)
		res.ok = false
		res.error = ApiError.client_error("Unsupported AudioStream type.")
		return res
	var form_fields: Dictionary = {"model": opts.model}
	if not opts.language.is_empty():
		form_fields["language"] = opts.language
	var response := await _http_post_multipart(
		base_url + "/audio/transcriptions",
		form_fields,
		"file",
		audio_bytes,
		filename,
		file_content_type,
		_headers()
	)
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var parser := JSON.new()
	var body_str := (response["body"] as PackedByteArray).get_string_from_utf8()
	if parser.parse(body_str) != OK:
		res.ok = false
		res.error = ApiError.parse_failure(
			"Failed to parse transcription response as JSON.", body_str
		)
		request_failed.emit(res.error)
		return res
	var json: Variant = parser.get_data()
	var text: Variant = (
		(json as Dictionary).get("text") if json is Dictionary else null
	)
	res.text = text if text is String else ""
	return res


func _audio_stream_wav_to_bytes(wav: AudioStreamWAV) -> PackedByteArray:
	var pcm := wav.data
	var num_channels := 2 if wav.stereo else 1
	# AudioStreamWAV.format: FORMAT_8_BIT = 0, FORMAT_16_BIT = 1, FORMAT_IMA_ADPCM = 2
	var bits_per_sample := 8 if wav.format == 0 else 16
	var bytes_per_sample := bits_per_sample >> 3
	var byte_rate := wav.mix_rate * num_channels * bytes_per_sample
	var block_align := num_channels * bytes_per_sample
	var data_size := pcm.size()
	var header := PackedByteArray()
	header.resize(44)
	# RIFF chunk
	header.encode_u8(0, 0x52); header.encode_u8(1, 0x49); header.encode_u8(2, 0x46); header.encode_u8(3, 0x46)  # "RIFF"
	header.encode_u32(4, 36 + data_size)  # file size - 8
	header.encode_u8(8, 0x57); header.encode_u8(9, 0x41); header.encode_u8(10, 0x56); header.encode_u8(11, 0x45)  # "WAVE"
	# fmt chunk
	header.encode_u8(12, 0x66); header.encode_u8(13, 0x6D); header.encode_u8(14, 0x74); header.encode_u8(15, 0x20)  # "fmt "
	header.encode_u32(16, 16)  # chunk size
	header.encode_u16(20, 1)  # PCM format
	header.encode_u16(22, num_channels)
	header.encode_u32(24, wav.mix_rate)
	header.encode_u32(28, byte_rate)
	header.encode_u16(32, block_align)
	header.encode_u16(34, bits_per_sample)
	# data chunk
	header.encode_u8(36, 0x64); header.encode_u8(37, 0x61); header.encode_u8(38, 0x74); header.encode_u8(39, 0x61)  # "data"
	header.encode_u32(40, data_size)
	return header + pcm


## Internal HTTP POST method. Can be overridden in tests.
func _http_post(
	url: String, body: Dictionary, headers: PackedStringArray
) -> Dictionary:
	return await _http_request(
		HTTPClient.METHOD_POST, url, headers, JSON.stringify(body)
	)


## Internal multipart/form-data POST. Can be overridden in tests.
func _http_post_multipart(
	url: String,
	form_fields: Dictionary,
	file_field: String,
	file_bytes: PackedByteArray,
	filename: String,
	file_content_type: String,
	headers: PackedStringArray
) -> Dictionary:
	var boundary := "GodotFormBoundary" + str(randi())
	var body := PackedByteArray()
	for key in form_fields:
		var part: String = (
			"--"
			+ boundary
			+ "\r\n"
			+ 'Content-Disposition: form-data; name="'
			+ key
			+ '"\r\n\r\n'
			+ str(form_fields[key])
			+ "\r\n"
		)
		body.append_array(part.to_utf8_buffer())
	var file_header := (
		"--"
		+ boundary
		+ "\r\n"
		+ 'Content-Disposition: form-data; name="'
		+ file_field
		+ '"; filename="'
		+ filename
		+ '"\r\n'
		+ "Content-Type: "
		+ file_content_type
		+ "\r\n\r\n"
	)
	body.append_array(file_header.to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	var multipart_headers := PackedStringArray()
	for h in headers:
		if not h.begins_with("Content-Type:"):
			multipart_headers.append(h)
	multipart_headers.append(
		"Content-Type: multipart/form-data; boundary=" + boundary
	)
	return await _http_request_raw(
		HTTPClient.METHOD_POST, url, multipart_headers, body
	)


## Internal HTTP GET method. Can be overridden in tests.
func _http_get(url: String, headers: PackedStringArray) -> Dictionary:
	return await _http_request(HTTPClient.METHOD_GET, url, headers)


func _http_request(
	method: int, url: String, headers: PackedStringArray, body: String = ""
) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {
			"ok": false,
			"error":
			ApiError.transport("Failed to start request (error %d)." % err)
		}
	var args: Array = await req.request_completed
	req.queue_free()
	return _process_http_result(args)


func _http_request_raw(
	method: int, url: String, headers: PackedStringArray, body: PackedByteArray
) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request_raw(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {
			"ok": false,
			"error":
			ApiError.transport("Failed to start request (error %d)." % err)
		}
	var args: Array = await req.request_completed
	req.queue_free()
	return _process_http_result(args)


# Maps the HTTPRequest.request_completed arguments to the shared response shape:
# {"ok": true, "body": PackedByteArray} on a 2xx response, or
# {"ok": false, "error": ApiError} on a transport failure or non-2xx status.
func _process_http_result(args: Array) -> Dictionary:
	var result: int = args[0]
	var status: int = args[1]
	var resp_body: PackedByteArray = args[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error":
			ApiError.transport("HTTP transport failed (result %d)." % result)
		}
	if status < 200 or status >= 300:
		return {"ok": false, "error": ApiError.from_response(status, resp_body)}
	return {"ok": true, "body": resp_body}


func _headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	return headers
