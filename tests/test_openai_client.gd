extends GutTest

## Test double for [C3OpenAIClient] that bypasses real HTTP requests.
## Set [member preset_response] before calling any method that triggers a request.
## Inspect [member request_log] after the call to assert which endpoints were called
## and with what bodies. Each entry is:[br] [code]{"method": String, "url": String, "body": Variant, "headers": PackedStringArray}[/code]
## [br]where [code]body[/code] is [code]null[/code] for GET requests and a [Dictionary] for POST requests.
@warning_ignore("missing_tool")
class TestableClient extends C3OpenAIClient:
	## The response returned by [method _http_get] and [method _http_post]. Defaults to an empty success.
	var preset_response: Dictionary = {"ok": true, "body": PackedByteArray()}
	## Ordered log of all requests made.
	## Each entry is:[br]
	## [code]{"method": String, "url": String, "body": Variant, "headers": PackedStringArray}[/code].
	var request_log: Array[Dictionary] = []

	func _http_get(url: String, headers: PackedStringArray) -> Dictionary:
		request_log.append(
			{"method": "GET", "url": url, "body": null, "headers": headers}
		)
		return preset_response

	func _http_post(
		url: String, body: Dictionary, headers: PackedStringArray
	) -> Dictionary:
		request_log.append(
			{"method": "POST", "url": url, "body": body, "headers": headers}
		)
		return preset_response

	func _http_post_multipart(
		url: String,
		form_fields: Dictionary,
		file_field: String,
		file_bytes: PackedByteArray,
		filename: String,
		file_content_type: String,
		headers: PackedStringArray
	) -> Dictionary:
		request_log.append({
			"method": "POST_MULTIPART",
			"url": url,
			"form_fields": form_fields,
			"file_field": file_field,
			"file_bytes": file_bytes,
			"filename": filename,
			"file_content_type": file_content_type,
			"headers": headers,
		})
		return preset_response


class TestGetModels extends GutTest:
	var client: TestableClient

	func before_each() -> void:
		client = TestableClient.new()
		add_child_autofree(client)

	func test_returns_model_ids() -> void:
		client.preset_response = {
			"ok": true,
			"body":
			'{"data": [{"id": "model-a"}, {"id": "model-b"}]}'.to_utf8_buffer()
		}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray(["model-a", "model-b"]))

	func test_returns_empty_array_for_empty_data() -> void:
		client.preset_response = {
			"ok": true, "body": '{"data": []}'.to_utf8_buffer()
		}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_returns_empty_array_when_data_key_missing() -> void:
		client.preset_response = {"ok": true, "body": "{}".to_utf8_buffer()}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com"
		client.preset_response = {
			"ok": true, "body": '{"data": []}'.to_utf8_buffer()
		}

		await client.get_models()

		assert_eq(client.request_log[0]["url"], "http://example.com/v1/models")

	func test_makes_exactly_one_request() -> void:
		client.preset_response = {
			"ok": true, "body": '{"data": []}'.to_utf8_buffer()
		}

		await client.get_models()

		assert_eq(client.request_log.size(), 1)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		watch_signals(client)

		await client.get_models()

		assert_signal_emitted(client, "request_failed")

	func test_returns_empty_array_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		watch_signals(client)

		await client.get_models()

		assert_signal_emitted(client, "request_failed")

	func test_returns_empty_array_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())


class TestMessageHelpers extends GutTest:
	func test_make_user_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_user_msg("hi"),
			{"role": "user", "content": "hi"}
		)

	func test_make_assistant_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_assistant_msg("hi"),
			{"role": "assistant", "content": "hi"}
		)

	func test_make_system_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_system_msg("hi"),
			{"role": "system", "content": "hi"}
		)

	func test_make_part_text() -> void:
		assert_eq(
			C3OpenAIClient.make_part_text("describe this"),
			{"type": "text", "text": "describe this"}
		)

	func test_make_part_image_url_default_detail() -> void:
		assert_eq(
			C3OpenAIClient.make_part_image_url("data:image/png;base64,abc"),
			{
				"type": "image_url",
				"image_url":
				{"url": "data:image/png;base64,abc", "detail": "auto"}
			}
		)

	func test_make_part_image_url_custom_detail() -> void:
		assert_eq(
			C3OpenAIClient.make_part_image_url(
				"data:image/png;base64,abc", "high"
			),
			{
				"type": "image_url",
				"image_url":
				{"url": "data:image/png;base64,abc", "detail": "high"}
			}
		)

	func test_make_user_msg_with_parts() -> void:
		var parts := [
			C3OpenAIClient.make_part_text("describe this"),
			C3OpenAIClient.make_part_image_url("data:image/png;base64,abc"),
		]
		assert_eq(
			C3OpenAIClient.make_user_msg_with_parts(parts),
			{"role": "user", "content": parts}
		)


class TestChatOptions extends GutTest:
	func test_default_model() -> void:
		assert_eq(C3OpenAIClient.ChatOptions.new().model, "")

	func test_default_temperature() -> void:
		assert_true(is_nan(C3OpenAIClient.ChatOptions.new().temperature))

	func test_default_max_tokens() -> void:
		assert_eq(C3OpenAIClient.ChatOptions.new().max_tokens, -1)


class TestChatCompletion extends GutTest:
	var client: TestableClient

	func before_each() -> void:
		client = TestableClient.new()
		add_child_autofree(client)

	## Returns a minimal JSON-encoded chat completion response body.
	func make_json_res(
		content: String,
		finish_reason: String = "stop",
		model: String = "gpt-4o",
		refusal: Variant = null
	) -> String:
		var content_to_send = null if refusal != null else (content as Variant)
		return JSON.stringify(
			{
				"id": "chatcmpl-abc",
				"object": "chat.completion",
				"created": 1234567890,
				"model": model,
				"choices":
				[
					{
						"index": 0,
						"message":
						{
							"role": "assistant",
							"content": content_to_send,
							"refusal": refusal
						},
						"finish_reason": finish_reason
					}
				],
				"usage":
				{
					"prompt_tokens": 10,
					"completion_tokens": 5,
					"total_tokens": 15
				}
			}
		)

	func test_returns_chat_completion_response() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_is(result, C3OpenAIClient.ChatCompletionResponse)

	func test_content_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hello there!").to_utf8_buffer()
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.content, "Hello there!")

	func test_finish_reason_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi", "length").to_utf8_buffer()
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.finish_reason, "length")

	func test_model_is_populated() -> void:
		client.preset_response = {
			"ok": true,
			"body": make_json_res("Hi", "stop", "llama-3.1-8b").to_utf8_buffer()
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.model, "llama-3.1-8b")

	func test_usage_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.usage["prompt_tokens"], 10)
		assert_eq(result.usage["completion_tokens"], 5)
		assert_eq(result.usage["total_tokens"], 15)

	func test_refusal_is_populated() -> void:
		client.preset_response = {
			"ok": true,
			"body":
			(
				make_json_res("", "stop", "gpt-4o", "I can't help with that.")
				. to_utf8_buffer()
			)
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Do something bad")]
		)
		assert_eq(result.refusal, "I can't help with that.")

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com"
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_eq(
			client.request_log[0]["url"],
			"http://example.com/v1/chat/completions"
		)

	func test_messages_sent_in_body() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var messages := [C3OpenAIClient.make_user_msg("Hello")]
		await client.chat_completion(messages)
		assert_eq(client.request_log[0]["body"]["messages"], messages)

	func test_options_model_sent_in_body() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.model = "llama-3.1-8b"
		await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")], opts
		)
		assert_eq(client.request_log[0]["body"]["model"], "llama-3.1-8b")

	func test_temperature_omitted_when_nan() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_false(client.request_log[0]["body"].has("temperature"))

	func test_temperature_sent_when_set() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.temperature = 0.2
		await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")], opts
		)
		assert_eq(client.request_log[0]["body"]["temperature"], 0.2)

	func test_max_tokens_omitted_when_minus_one() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_false(client.request_log[0]["body"].has("max_tokens"))

	func test_max_tokens_sent_when_set() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.max_tokens = 100
		await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")], opts
		)
		assert_eq(client.request_log[0]["body"]["max_tokens"], 100)

	func test_returns_null_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		var result: C3OpenAIClient.ChatCompletionResponse = await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_null(result)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_null(result)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_null(result)

	func test_emits_request_failed_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_empty_choices() -> void:
		client.preset_response = {
			"ok": true, "body": '{"choices": []}'.to_utf8_buffer()
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_null(result)

	func test_emits_request_failed_on_empty_choices() -> void:
		client.preset_response = {
			"ok": true, "body": '{"choices": []}'.to_utf8_buffer()
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_warns_when_model_is_empty() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_push_warning(
			"C3OpenAIClient: opts.model is empty — using server default."
		)

	func test_no_warning_when_model_is_set() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.model = "gpt-4o"
		await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")], opts
		)
		assert_push_warning_count(0)


class TestHeaders extends GutTest:
	var client: C3OpenAIClient

	func before_each() -> void:
		client = C3OpenAIClient.new()
		add_child_autofree(client)

	func test_content_type_always_present() -> void:
		client.api_key = ""
		var headers := client._headers()
		assert_true(headers.has("Content-Type: application/json"))

	func test_bearer_token_added_when_api_key_set() -> void:
		client.api_key = "test-key-123"
		var headers := client._headers()
		assert_true(headers.has("Authorization: Bearer test-key-123"))

	func test_no_auth_header_when_api_key_empty() -> void:
		client.api_key = ""
		var headers := client._headers()
		for h in headers:
			assert_false(h.begins_with("Authorization:"))


class TestSpeechOptions extends GutTest:
	func test_default_model() -> void:
		assert_eq(C3OpenAIClient.SpeechOptions.new().model, "")

	func test_default_voice() -> void:
		assert_eq(C3OpenAIClient.SpeechOptions.new().voice, "")

	func test_default_response_format() -> void:
		assert_eq(C3OpenAIClient.SpeechOptions.new().response_format, "mp3")


class TestTranscriptionOptions extends GutTest:
	func test_default_model() -> void:
		assert_eq(C3OpenAIClient.TranscriptionOptions.new().model, "")

	func test_default_language() -> void:
		assert_eq(C3OpenAIClient.TranscriptionOptions.new().language, "")


class TestCreateSpeech extends GutTest:
	var client: TestableClient

	func before_each() -> void:
		client = TestableClient.new()
		add_child_autofree(client)

	## Real MP3 bytes are required because AudioStreamMP3 validates data on assignment.
	func mp3_bytes() -> PackedByteArray:
		return (load("res://tests/data/demo-speech.mp3") as AudioStreamMP3).data

	func ok_mp3() -> Dictionary:
		return {"ok": true, "body": mp3_bytes()}

	func test_returns_audio_stream() -> void:
		client.preset_response = ok_mp3()
		var result := await client.create_speech("Hello")
		assert_is(result, AudioStream)

	func test_returns_audio_stream_mp3_by_default() -> void:
		client.preset_response = ok_mp3()
		var result := await client.create_speech("Hello")
		assert_is(result, AudioStreamMP3)

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com"
		client.preset_response = ok_mp3()
		await client.create_speech("Hello")
		assert_eq(
			client.request_log[0]["url"], "http://example.com/v1/audio/speech"
		)

	func test_makes_exactly_one_request() -> void:
		client.preset_response = ok_mp3()
		await client.create_speech("Hello")
		assert_eq(client.request_log.size(), 1)

	func test_sends_input_in_body() -> void:
		client.preset_response = ok_mp3()
		await client.create_speech("Test speech text")
		assert_eq(client.request_log[0]["body"]["input"], "Test speech text")

	func test_sends_model_in_body() -> void:
		client.preset_response = ok_mp3()
		var opts := C3OpenAIClient.SpeechOptions.new()
		opts.model = "kokoro-82m"
		await client.create_speech("Hello", opts)
		assert_eq(client.request_log[0]["body"]["model"], "kokoro-82m")

	func test_sends_voice_in_body() -> void:
		client.preset_response = ok_mp3()
		var opts := C3OpenAIClient.SpeechOptions.new()
		opts.voice = "af_heart"
		await client.create_speech("Hello", opts)
		assert_eq(client.request_log[0]["body"]["voice"], "af_heart")

	func test_sends_response_format_in_body() -> void:
		client.preset_response = ok_mp3()
		var opts := C3OpenAIClient.SpeechOptions.new()
		opts.response_format = "mp3"
		await client.create_speech("Hello", opts)
		assert_eq(client.request_log[0]["body"]["response_format"], "mp3")

	func test_audio_stream_mp3_contains_response_bytes() -> void:
		var real_mp3 := (
			load("res://tests/data/demo-speech.mp3") as AudioStreamMP3
		)
		client.preset_response = {"ok": true, "body": real_mp3.data}
		var result := await client.create_speech("Hello") as AudioStreamMP3
		assert_eq(result.data, real_mp3.data)

	func test_returns_null_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		var result := await client.create_speech("Hello")
		assert_null(result)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		watch_signals(client)
		await client.create_speech("Hello")
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		var result := await client.create_speech("Hello")
		assert_null(result)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		watch_signals(client)
		await client.create_speech("Hello")
		assert_signal_emitted(client, "request_failed")


class TestCreateTranscription extends GutTest:
	var client: TestableClient

	func before_each() -> void:
		client = TestableClient.new()
		add_child_autofree(client)

	func make_json_res(text: String) -> PackedByteArray:
		return JSON.stringify({"text": text}).to_utf8_buffer()

	func make_mp3_stream() -> AudioStreamMP3:
		return load("res://tests/data/demo-speech.mp3") as AudioStreamMP3

	func test_returns_transcription_response() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hello world")
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_is(result, C3OpenAIClient.TranscriptionResponse)

	func test_text_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hello world")
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_eq(result.text, "Hello world")

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com"
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_mp3_stream())
		assert_eq(
			client.request_log[0]["url"],
			"http://example.com/v1/audio/transcriptions"
		)

	func test_makes_exactly_one_request() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_mp3_stream())
		assert_eq(client.request_log.size(), 1)

	func test_sends_model_as_form_field() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		var opts := C3OpenAIClient.TranscriptionOptions.new()
		opts.model = "whisper-large-v3"
		await client.create_transcription(make_mp3_stream(), opts)
		assert_eq(
			client.request_log[0]["form_fields"]["model"], "whisper-large-v3"
		)

	func test_sends_language_when_set() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		var opts := C3OpenAIClient.TranscriptionOptions.new()
		opts.language = "en"
		await client.create_transcription(make_mp3_stream(), opts)
		assert_eq(client.request_log[0]["form_fields"]["language"], "en")

	func test_omits_language_when_empty() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_mp3_stream())
		assert_false(client.request_log[0]["form_fields"].has("language"))

	func test_sends_file_field_named_file() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_mp3_stream())
		assert_eq(client.request_log[0]["file_field"], "file")

	func test_sends_mp3_bytes_as_file() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		var stream := make_mp3_stream()
		await client.create_transcription(stream)
		assert_eq(client.request_log[0]["file_bytes"], stream.data)

	func test_sends_mp3_content_type() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_mp3_stream())
		assert_eq(client.request_log[0]["file_content_type"], "audio/mpeg")

	func test_returns_null_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_null(result)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_null(result)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")

	func test_returns_null_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_null(result)

	func test_emits_request_failed_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")
