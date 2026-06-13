# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

C3 REST Client for Godot is a Godot 4 addon providing an async `Node` for talking to JSON REST APIs. Callers `await client.request(...)` and check `response.ok` — a single check that covers transport failures and non-2xx statuses alike. `ok` reflects only the HTTP exchange; body content never affects it. Deliberately out of scope: retries, caching, cookies, middleware, and typed deserialization.

## Commands

**Run all tests:**
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Run a single test file:**
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gtest=res://tests/test_request.gd
```

If GUT reports "does not extend GutTest" or "Nothing was run" after files or classes have been renamed, the global script class cache is stale — rebuild it first with `godot --headless --path . --import`.

Tests require Godot 4.6+ on `$PATH`. CI runs on ubuntu-latest with Godot 4.6.2-stable via `.github/workflows/tests.yml` (which runs the `--import` step before GUT).

**Build asset for distribution:**
```
python scripts/build_asset.py <version>
```

## Architecture

The addon is a single script: [c3_rest_client/c3_rest_client.gd](c3_rest_client/c3_rest_client.gd).

**`C3RestClient`** — Extends `Node`, marked `@tool`. Public surface:
- `base_url` (`@export`) — prefix for every request path, including any API version prefix
- `base_headers` (`PackedStringArray`) — node-level headers merged into every request before per-request headers; use for auth and other standing concerns
- `request(path, method, body, query, headers, timeout)` → `ApiResponse` — the one async entry point. `method` is a `Method` enum value; `body` is JSON-encoded; `query` is URL-encoded; `headers` (`PackedStringArray`) are appended after `base_headers`; `timeout` (`float`, default `-1.0`) overrides `timeout_seconds` for this call (`0.0` disables, negative inherits node default). The response body is delivered raw on `ApiResponse.body` and best-effort parsed on `ApiResponse.json` — on success and failure both; a 2xx with a non-JSON body succeeds with `json == null`.
- `request_failed(error)` signal — secondary broadcast for cross-cutting concerns (e.g. global error logging); `response.ok` is the primary failure channel

**Inner classes:**
- `Method` enum — `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `OPTIONS`, `PATCH`
- `ApiResponse` — `ok: bool`, `error: ApiError`, `status: int`, `headers: PackedStringArray`, `body: String` (raw UTF-8), `json: Variant` (whatever the body parsed to when it was valid JSON, else `null`)
- `ApiError` — typed errors with `kind` string: `&"transport"`, `&"http"`, `&"api"`, `&"client"`, `&"cancelled"`. `from_response()` pulls `message`/`code`/`type` from a conventional `{"error": {...}}` JSON body when present.

**Transport** is Godot's `HTTPRequest`, created per call as a child node in `_http_request()` and mapped to a shared `{"ok", "body"/"error"}` shape by `_process_http_result()`.

**Tests** are in [tests/](tests/) using the GUT framework (in [addons/gut/](addons/gut/)). `TestableClient` in [tests/c3_test_doubles.gd](tests/c3_test_doubles.gd) overrides `_http_request()` so no real HTTP calls are made.

## GDScript Style Guide

Follow [CONTRIBUTING.md](CONTRIBUTING.md) strictly. Key rules:

- **Tabs** for indentation (never spaces), one tab per level.
- **Type hints are mandatory** on all parameters and return types. Use `:=` for inference; use explicit type when inference would be too broad (e.g., `instantiate()` calls).
- Signal awaits require explicit type annotation (GDScript limitation); function awaits may use `:=`.
- Multi-line function signatures: closing `)` goes on its own line at zero indent, before `->`.
- `##` doc comments for classes, `@export` vars, and public methods. `#` for private methods only when non-obvious. Comments explain *why*, not *what*.
- Private members and methods prefixed with `_`.

**Declaration order within a class:**
1. `class_name` / `extends`
2. Class-level `##` doc comment
3. Signals → Enums → Constants → `@export` vars → public vars → private vars → `@onready` vars
4. Built-in virtual methods (`_ready`, `_process`, …)
5. Public methods
6. Private methods
7. Inner classes
