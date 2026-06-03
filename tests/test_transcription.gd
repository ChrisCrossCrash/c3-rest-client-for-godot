extends GutTest


## Tests for [C3OpenAIClient.TranscriptionOptions] defaults.
class TestTranscriptionOptions extends GutTest:
	func test_default_model() -> void:
		assert_eq(C3OpenAIClient.TranscriptionOptions.new().model, "")

	func test_default_language() -> void:
		assert_eq(C3OpenAIClient.TranscriptionOptions.new().language, "")


## Tests for [method C3OpenAIClient.create_transcription].
class TestCreateTranscription extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)

	## Returns a minimal JSON-encoded transcription response body.
	func make_json_res(text: String) -> PackedByteArray:
		return JSON.stringify({"text": text}).to_utf8_buffer()

	## Loads and returns the test MP3 fixture.
	func make_mp3_stream() -> AudioStreamMP3:
		return load("res://tests/data/demo-speech.mp3") as AudioStreamMP3

	## Creates a minimal in-memory WAV stream for testing.
	func make_wav_stream() -> AudioStreamWAV:
		var stream := AudioStreamWAV.new()
		stream.mix_rate = 44100
		stream.stereo = false
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.data = PackedByteArray([0x00, 0x01, 0x02, 0x03])
		return stream

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
		client.base_url = "http://example.com/v1"
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

	func test_sends_wav_bytes_as_file() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		var stream := make_wav_stream()
		await client.create_transcription(stream)
		assert_eq(
			client.request_log[0]["file_bytes"],
			client._audio_stream_wav_to_bytes(stream)
		)

	func test_sends_wav_content_type() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_wav_stream())
		assert_eq(client.request_log[0]["file_content_type"], "audio/wav")

	func test_sends_wav_filename() -> void:
		client.preset_response = {"ok": true, "body": make_json_res("Hi")}
		await client.create_transcription(make_wav_stream())
		assert_eq(client.request_log[0]["filename"], "audio.wav")

	func test_returns_failed_response_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Could not connect.")
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_false(result.ok)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Could not connect.")
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Connection error.")
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_false(result.ok)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Connection error.")
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		var result := await client.create_transcription(make_mp3_stream())
		assert_false(result.ok)
		assert_eq(result.error.kind, &"parse")

	func test_emits_request_failed_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		watch_signals(client)
		await client.create_transcription(make_mp3_stream())
		assert_signal_emitted(client, "request_failed")

	func test_unsupported_audio_type_is_client_error() -> void:
		var result := await client.create_transcription(
			AudioStreamGenerator.new()
		)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"client")
		assert_eq(client.request_log.size(), 0)
		assert_push_error("Unsupported AudioStream type")
