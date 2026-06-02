extends GutTest


class TestGetModels extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)

	func test_returns_models_response() -> void:
		client.preset_response = {
			"ok": true,
			"body":
			'{"data": [{"id": "model-a"}, {"id": "model-b"}]}'.to_utf8_buffer()
		}

		var result := await client.get_models()

		assert_is(result, C3OpenAIClient.ModelsResponse)

	func test_returns_model_ids() -> void:
		client.preset_response = {
			"ok": true,
			"body":
			'{"data": [{"id": "model-a"}, {"id": "model-b"}]}'.to_utf8_buffer()
		}

		var result := await client.get_models()

		assert_eq(result.ids, PackedStringArray(["model-a", "model-b"]))

	func test_returns_empty_ids_for_empty_data() -> void:
		client.preset_response = {
			"ok": true, "body": '{"data": []}'.to_utf8_buffer()
		}

		var result := await client.get_models()

		assert_eq(result.ids, PackedStringArray())

	func test_returns_empty_ids_when_data_key_missing() -> void:
		client.preset_response = {"ok": true, "body": "{}".to_utf8_buffer()}

		var result := await client.get_models()

		assert_eq(result.ids, PackedStringArray())

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com/v1"
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

	func test_returns_failed_response_on_network_error() -> void:
		client.preset_response = {
			"ok": false, "error": {"error": ERR_CANT_CONNECT}
		}

		var result := await client.get_models()

		assert_false(result.ok)

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}
		watch_signals(client)

		await client.get_models()

		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_http_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}
		}

		var result := await client.get_models()

		assert_false(result.ok)
