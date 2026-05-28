# C3 Godot Utils
# v3.0.0
# File revision: 2026-05-27

@tool
class_name C3OpenAIClient
extends Node
## General-purpose client for OpenAI-compatible HTTP APIs.

## Emitted when a request fails. The [member ok] field of the returned response
## object is the primary way to detect failure; this signal is a secondary
## broadcast for optional cross-cutting concerns such as global error logging.
signal request_failed(error: Dictionary)

@export var base_url: String = "http://127.0.0.1:1234"
@export var api_key: String = "no-key"


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
	var error: Dictionary = {}
	## The resulting audio stream. Only valid when [member ok] is [code]true[/code].
	var stream: AudioStream


## The response returned by [method create_transcription].
class TranscriptionResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: Dictionary = {}
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
	var error: Dictionary = {}
	var content: String = ""
	var refusal: String = ""
	var finish_reason: String = ""
	var model: String = ""
	var usage: Dictionary = {}


## The response returned by [method get_models].
class ModelsResponse:
	## [code]true[/code] if the request succeeded.
	var ok: bool = true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()


## Returns the list of model IDs available on the server.
## Returns a [ModelsResponse] with [member ModelsResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] on failure.
func get_models() -> ModelsResponse:
	var response := await _http_get(base_url + "/v1/models", _headers())
	var res := ModelsResponse.new()
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var parser := JSON.new()
	parser.parse((response["body"] as PackedByteArray).get_string_from_utf8())
	var json: Variant = parser.get_data()
	for m in json.get("data", []):
		res.ids.append(m["id"])
	return res


## Sends a chat completion request and returns the model's response.
## Returns a [ChatCompletionResponse] with [member ChatCompletionResponse.ok]
## set to [code]false[/code] and emits [signal request_failed] on failure.
func chat_completion(
	messages: Array, opts: ChatOptions = null
) -> ChatCompletionResponse:
	if opts == null:
		opts = ChatOptions.new()
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
	var response := await _http_post(
		base_url + "/v1/chat/completions", body, _headers()
	)
	var res := ChatCompletionResponse.new()
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var parser := JSON.new()
	if (
		parser.parse(
			(response["body"] as PackedByteArray).get_string_from_utf8()
		)
		!= OK
	):
		res.ok = false
		res.error = {"message": "Failed to parse response body as JSON."}
		request_failed.emit(res.error)
		return res
	var json: Variant = parser.get_data()
	var choices: Variant = json.get("choices") if json is Dictionary else null
	if not choices is Array or (choices as Array).is_empty():
		res.ok = false
		res.error = {"message": "Response JSON missing choices."}
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
	res.usage = json_dict.get("usage", {})
	return res


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
		base_url + "/v1/audio/speech", body, _headers()
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
		res.error = {"message": "Unsupported AudioStream type."}
		return res
	var form_fields: Dictionary = {"model": opts.model}
	if not opts.language.is_empty():
		form_fields["language"] = opts.language
	var response := await _http_post_multipart(
		base_url + "/v1/audio/transcriptions",
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
		res.error = {"message": "Failed to parse transcription response as JSON."}
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
		return {"ok": false, "error": {"error": err}}
	var args: Array = await req.request_completed
	req.queue_free()
	var result: int = args[0]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": {"result": result}}
	return {"ok": true, "body": args[3] as PackedByteArray}


func _http_request_raw(
	method: int, url: String, headers: PackedStringArray, body: PackedByteArray
) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request_raw(url, headers, method, body)
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
