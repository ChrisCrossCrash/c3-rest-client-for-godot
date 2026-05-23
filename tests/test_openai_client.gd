extends GutTest


## Test double for [C3OpenAIClient] that bypasses real HTTP requests.
## Set [member preset_response] before calling any method that triggers a request.
## Inspect [member request_history] after the call to assert which endpoints were
## called and how many times.
class TestableClient extends C3OpenAIClient:
	## The response returned by [method _http_get]. Defaults to an empty success.
	var preset_response: Dictionary = {"ok": true, "body": PackedByteArray()}
	## Ordered list of URLs passed to [method _http_get], one entry per call.
	var request_history: Array[String] = []

	func _http_get(url: String) -> Dictionary:
		request_history.append(url)
		return preset_response


class TestGetModels extends GutTest:
	var client: TestableClient

	func before_each() -> void:
		client = TestableClient.new()
		add_child_autofree(client)

	func _set_body(json: String) -> void:
		client.preset_response = {"ok": true, "body": json.to_utf8_buffer()}

	func test_returns_model_ids() -> void:
		_set_body('{"data": [{"id": "model-a"}, {"id": "model-b"}]}')

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray(["model-a", "model-b"]))

	func test_returns_empty_array_for_empty_data() -> void:
		_set_body('{"data": []}')

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_returns_empty_array_when_data_key_missing() -> void:
		_set_body('{}')

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com"
		_set_body('{"data": []}')

		await client.get_models()

		assert_eq(client.request_history, ["http://example.com/v1/models"])

	func test_makes_exactly_one_request() -> void:
		_set_body('{"data": []}')

		await client.get_models()

		assert_eq(client.request_history.size(), 1)

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {"ok": false, "error": {"error": ERR_CANT_CONNECT}}
		watch_signals(client)

		await client.get_models()

		assert_signal_emitted(client, "request_failed")

	func test_returns_empty_array_on_network_error() -> void:
		client.preset_response = {"ok": false, "error": {"error": ERR_CANT_CONNECT}}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())

	func test_emits_request_failed_on_http_failure() -> void:
		client.preset_response = {"ok": false, "error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}}
		watch_signals(client)

		await client.get_models()

		assert_signal_emitted(client, "request_failed")

	func test_returns_empty_array_on_http_failure() -> void:
		client.preset_response = {"ok": false, "error": {"result": HTTPRequest.RESULT_CONNECTION_ERROR}}

		var ids := await client.get_models()

		assert_eq(ids, PackedStringArray())


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
