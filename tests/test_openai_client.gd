extends GutTest


## Test double for [C3OpenAIClient] that bypasses real HTTP requests.
## Set [member preset_response] before calling any method that triggers a request.
## Inspect [member request_log] after the call to assert which endpoints were called
## and with what bodies. Each entry is:[br] [code]{"method": String, "url": String, "body": Variant, "headers": PackedStringArray}[/code]
## [br]where [code]body[/code] is [code]null[/code] for GET requests and a [Dictionary] for POST requests.
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
							"content": null if refusal != null else (content as Variant),
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
