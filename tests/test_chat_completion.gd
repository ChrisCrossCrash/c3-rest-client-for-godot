extends GutTest


## Tests for [method C3OpenAIClient.chat_completion].
class TestChatCompletion extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)

	## Returns a minimal JSON-encoded chat completion response body.
	func make_json_res(
		content: String,
		finish_reason: String = "stop",
		model: String = "gpt-4o",
		refusal: Variant = null
	) -> String:
		var content_to_send: Variant = null if refusal != null else (content as Variant)
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
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_is(result, C3OpenAIClient.ChatCompletionResponse)

	func test_content_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hello there!").to_utf8_buffer()
		}
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.content, "Hello there!")

	func test_finish_reason_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi", "length").to_utf8_buffer()
		}
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.finish_reason, "length")

	func test_model_is_populated() -> void:
		client.preset_response = {
			"ok": true,
			"body": make_json_res("Hi", "stop", "llama-3.1-8b").to_utf8_buffer()
		}
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(result.model, "llama-3.1-8b")

	func test_usage_is_populated() -> void:
		client.preset_response = {
			"ok": true, "body": make_json_res("Hi").to_utf8_buffer()
		}
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_eq(typeof(result.usage["prompt_tokens"]), TYPE_INT)
		assert_eq(typeof(result.usage["completion_tokens"]), TYPE_INT)
		assert_eq(typeof(result.usage["total_tokens"]), TYPE_INT)
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
		client.base_url = "http://example.com/v1"
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

	func test_returns_failed_response_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Could not connect.")
		}
		var result := await (
			client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		)
		assert_false(result.ok)

	func test_propagates_transport_error_unchanged() -> void:
		var err := C3OpenAIClient.ApiError.transport("Could not connect.")
		client.preset_response = {"ok": false, "error": err}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_same(result.error, err)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Could not connect.")
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Connection error.")
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_false(result.ok)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3OpenAIClient.ApiError.transport("Connection error.")
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"parse")
		assert_eq(result.error.raw, "not json")

	func test_emits_request_failed_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		watch_signals(client)
		await client.chat_completion([C3OpenAIClient.make_user_msg("Hello")])
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_empty_choices() -> void:
		client.preset_response = {
			"ok": true, "body": '{"choices": []}'.to_utf8_buffer()
		}
		var result := await client.chat_completion(
			[C3OpenAIClient.make_user_msg("Hello")]
		)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"parse")

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


## Tests for the HTTP headers assembled by [C3OpenAIClient].
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
