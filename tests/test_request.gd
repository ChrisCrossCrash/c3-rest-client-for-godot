extends GutTest


## Tests for [method C3RestClient.request].
class TestRequest extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)
		client.preset_response = {
			"ok": true, "body": '{"object": "list"}'.to_utf8_buffer()
		}

	func test_returns_api_response() -> void:
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_is(result, C3RestClient.ApiResponse)

	func test_uses_the_given_path() -> void:
		client.base_url = "http://example.com/v1"
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(
			client.request_log[0]["url"], "http://example.com/v1/embeddings"
		)

	func test_adds_missing_leading_slash() -> void:
		client.base_url = "http://example.com/v1"
		await client.request("embeddings", C3RestClient.Method.POST)
		assert_eq(
			client.request_log[0]["url"], "http://example.com/v1/embeddings"
		)

	func test_makes_exactly_one_request() -> void:
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(client.request_log.size(), 1)

	func test_sends_method() -> void:
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(client.request_log[0]["method"], "POST")

	func test_sends_body_as_json() -> void:
		await client.request(
			"/embeddings", C3RestClient.Method.POST, {"model": "m", "input": "hi"}
		)
		var sent: Dictionary = JSON.parse_string(client.request_log[0]["body"])
		assert_eq(sent, {"model": "m", "input": "hi"})

	func test_empty_body_sends_nothing() -> void:
		await client.request("/models/gpt-x", C3RestClient.Method.GET)
		assert_eq(client.request_log[0]["body"], "")

	func test_appends_query_string() -> void:
		await client.request("/files", C3RestClient.Method.GET, {}, {"limit": 5})
		assert_eq(
			client.request_log[0]["url"], client.base_url + "/files?limit=5"
		)

	func test_query_values_are_url_encoded() -> void:
		await client.request("/files", C3RestClient.Method.GET, {}, {"q": "a b"})
		var url: String = client.request_log[0]["url"]
		assert_true(url.ends_with("?q=a%20b"))

	func test_no_query_string_when_query_empty() -> void:
		await client.request("/files", C3RestClient.Method.GET)
		var url: String = client.request_log[0]["url"]
		assert_false(url.contains("?"))

	func test_base_headers_are_sent() -> void:
		client.base_headers = PackedStringArray(["Authorization: Bearer secret"])
		await client.request("/embeddings", C3RestClient.Method.POST)
		var headers: PackedStringArray = client.request_log[0]["headers"]
		assert_true(headers.has("Authorization: Bearer secret"))

	func test_per_request_headers_are_sent() -> void:
		await client.request(
			"/embeddings", C3RestClient.Method.POST, {}, {},
			PackedStringArray(["X-Custom: value"])
		)
		var headers: PackedStringArray = client.request_log[0]["headers"]
		assert_true(headers.has("X-Custom: value"))

	func test_per_request_headers_merged_with_base_headers() -> void:
		client.base_headers = PackedStringArray(["Authorization: Bearer secret"])
		await client.request(
			"/embeddings", C3RestClient.Method.POST, {}, {},
			PackedStringArray(["X-Custom: value"])
		)
		var headers: PackedStringArray = client.request_log[0]["headers"]
		assert_true(headers.has("Authorization: Bearer secret"))
		assert_true(headers.has("X-Custom: value"))

	func test_empty_base_headers_omits_extra_headers() -> void:
		client.base_headers = PackedStringArray()
		await client.request("/embeddings", C3RestClient.Method.POST)
		var headers: PackedStringArray = client.request_log[0]["headers"]
		assert_eq(headers, PackedStringArray(["Content-Type: application/json"]))

	func test_default_timeout_is_zero() -> void:
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(client.request_log[0]["timeout"], 0.0)

	func test_node_timeout_is_applied() -> void:
		client.timeout_seconds = 30.0
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(client.request_log[0]["timeout"], 30.0)

	func test_per_request_timeout_overrides_node_timeout() -> void:
		client.timeout_seconds = 30.0
		await client.request(
			"/embeddings", C3RestClient.Method.POST, {}, {}, PackedStringArray(), 5.0
		)
		assert_eq(client.request_log[0]["timeout"], 5.0)

	func test_per_request_timeout_zero_disables_timeout() -> void:
		client.timeout_seconds = 30.0
		await client.request(
			"/embeddings", C3RestClient.Method.POST, {}, {}, PackedStringArray(), 0.0
		)
		assert_eq(client.request_log[0]["timeout"], 0.0)

	func test_response_headers_are_set_on_success() -> void:
		client.preset_response = {
			"ok": true,
			"status": 200,
			"headers": PackedStringArray(["X-Rate-Limit: 100"]),
			"body": PackedByteArray(),
		}
		var result := await client.request("/todos", C3RestClient.Method.GET)
		assert_true(result.headers.has("X-Rate-Limit: 100"))

	func test_response_headers_empty_on_transport_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3RestClient.ApiError.transport("Could not connect.")
		}
		var result := await client.request("/todos", C3RestClient.Method.GET)
		assert_eq(result.headers, PackedStringArray())

	func test_status_is_set_on_success() -> void:
		client.preset_response = {
			"ok": true, "status": 201, "body": '{"id": 1}'.to_utf8_buffer()
		}
		var result := await client.request("/todos", C3RestClient.Method.POST)
		assert_eq(result.status, 201)

	func test_status_is_zero_on_transport_failure() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3RestClient.ApiError.transport("Could not connect.")
		}
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_eq(result.status, 0)

	func test_body_contains_parsed_response() -> void:
		client.preset_response = {
			"ok": true,
			"body": '{"object": "embedding.list", "model": "m"}'.to_utf8_buffer()
		}
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_true(result.ok)
		assert_eq(result.body, {"object": "embedding.list", "model": "m"})

	func test_empty_body_response_is_success() -> void:
		client.preset_response = {"ok": true, "body": PackedByteArray()}
		var result := await client.request("/files/abc", C3RestClient.Method.DELETE)
		assert_true(result.ok)
		assert_null(result.error)
		assert_eq(result.body, {})

	# --- failure paths ---

	func test_returns_failed_response_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3RestClient.ApiError.transport("Could not connect.")
		}
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"transport")

	func test_emits_request_failed_on_network_error() -> void:
		client.preset_response = {
			"ok": false,
			"error": C3RestClient.ApiError.transport("Could not connect.")
		}
		watch_signals(client)
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_signal_emitted(client, "request_failed")

	func test_returns_failed_response_on_invalid_json() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"parse")

	func test_returns_failed_response_on_non_object_json() -> void:
		client.preset_response = {"ok": true, "body": "[1, 2]".to_utf8_buffer()}
		var result := await client.request("/embeddings", C3RestClient.Method.POST)
		assert_false(result.ok)
		assert_eq(result.error.kind, &"parse")
		assert_eq(result.error.raw, "[1, 2]")

	func test_emits_request_failed_on_parse_failure() -> void:
		client.preset_response = {
			"ok": true, "body": "not json".to_utf8_buffer()
		}
		watch_signals(client)
		await client.request("/embeddings", C3RestClient.Method.POST)
		assert_signal_emitted(client, "request_failed")


## Tests for [C3RestClient.ApiResponse] defaults.
class TestApiResponse extends GutTest:
	func test_default_ok() -> void:
		assert_true(C3RestClient.ApiResponse.new().ok)

	func test_default_error() -> void:
		assert_null(C3RestClient.ApiResponse.new().error)

	func test_default_status() -> void:
		assert_eq(C3RestClient.ApiResponse.new().status, 0)

	func test_default_headers() -> void:
		assert_eq(C3RestClient.ApiResponse.new().headers, PackedStringArray())

	func test_default_body() -> void:
		assert_eq(C3RestClient.ApiResponse.new().body, {})
