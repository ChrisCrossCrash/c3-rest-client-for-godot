extends GutTest


## Tests for the per-verb convenience methods on [C3RestClient].
class TestHttpMethods extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)
		client.preset_response = {
			"ok": true, "body": '{"id": "x"}'.to_utf8_buffer()
		}

	func test_get_sends_get() -> void:
		await client.http_get("/models")
		assert_eq(client.request_log[0]["method"], "GET")

	func test_get_sends_no_body() -> void:
		await client.http_get("/models")
		assert_eq(client.request_log[0]["body"], "")

	func test_get_passes_query() -> void:
		client.base_url = "http://example.com"
		await client.http_get("/models", {"limit": 5})
		assert_true(client.request_log[0]["url"].ends_with("?limit=5"))

	func test_head_sends_head() -> void:
		await client.http_head("/models")
		assert_eq(client.request_log[0]["method"], "HEAD")

	func test_head_sends_no_body() -> void:
		await client.http_head("/models")
		assert_eq(client.request_log[0]["body"], "")

	func test_head_passes_query() -> void:
		client.base_url = "http://example.com"
		await client.http_head("/models", {"limit": 5})
		assert_true(client.request_log[0]["url"].ends_with("?limit=5"))

	func test_post_sends_post() -> void:
		await client.http_post("/completions")
		assert_eq(client.request_log[0]["method"], "POST")

	func test_post_sends_body() -> void:
		await client.http_post("/completions", {"model": "gpt-4"})
		var sent: Dictionary = JSON.parse_string(client.request_log[0]["body"])
		assert_eq(sent, {"model": "gpt-4"})

	func test_post_empty_body_sends_nothing() -> void:
		await client.http_post("/completions")
		assert_eq(client.request_log[0]["body"], "")

	func test_post_passes_query() -> void:
		client.base_url = "http://example.com"
		await client.http_post("/completions", {}, {"stream": "true"})
		assert_true(client.request_log[0]["url"].ends_with("?stream=true"))

	func test_put_sends_put() -> void:
		await client.http_put("/config/x")
		assert_eq(client.request_log[0]["method"], "PUT")

	func test_put_sends_body() -> void:
		await client.http_put("/config/x", {"key": "val"})
		var sent: Dictionary = JSON.parse_string(client.request_log[0]["body"])
		assert_eq(sent, {"key": "val"})

	func test_patch_sends_patch() -> void:
		await client.http_patch("/config/x")
		assert_eq(client.request_log[0]["method"], "PATCH")

	func test_patch_sends_body() -> void:
		await client.http_patch("/config/x", {"key": "val"})
		var sent: Dictionary = JSON.parse_string(client.request_log[0]["body"])
		assert_eq(sent, {"key": "val"})

	func test_delete_sends_delete() -> void:
		await client.http_delete("/models/x")
		assert_eq(client.request_log[0]["method"], "DELETE")

	func test_delete_sends_no_body() -> void:
		await client.http_delete("/models/x")
		assert_eq(client.request_log[0]["body"], "")

	func test_delete_passes_query() -> void:
		client.base_url = "http://example.com"
		await client.http_delete("/models/x", {"confirm": "true"})
		assert_true(client.request_log[0]["url"].ends_with("?confirm=true"))

	func test_options_sends_options() -> void:
		await client.http_options("/models")
		assert_eq(client.request_log[0]["method"], "OPTIONS")

	func test_options_sends_no_body() -> void:
		await client.http_options("/models")
		assert_eq(client.request_log[0]["body"], "")
