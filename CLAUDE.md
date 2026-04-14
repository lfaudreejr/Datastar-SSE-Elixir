# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`datastar_sse` is an Elixir library providing SSE (Server-Sent Events) helpers for [DataStar](https://data-star.dev) — a framework for building reactive web applications using SSE and hypermedia.

## Commands

```bash
mix test                              # Run all tests
mix test test/data_star_sse_test.exs:22   # Run a single test by line number
mix format                            # Format code
mix credo                             # Static analysis
mix dialyzer                          # Type checking (slow on first run — builds PLT)
mix docs                              # Generate ExDoc documentation
```

To run the example server (dev only):
```bash
mix run lib/scripts/server.exs
```

## Architecture

All library code lives in a single file: `lib/data_star_sse.ex`.

All public functions are on the `DataStarSSE` module directly.

**Function responsibilities:**

| Function | Returns | What it does |
|---|---|---|
| `new_sse/1` | `Plug.Conn.t()` | Sets SSE response headers and initiates chunked transfer |
| `patch_elements/3` | `{:ok, conn} \| {:error, :closed \| :enotconn}` | Sends a `datastar-patch-elements` event; updates DOM via HTML string |
| `patch_signals/3` | `{:ok, conn} \| {:error, :closed \| :enotconn}` | Sends a `datastar-patch-signals` event; accepts pre-encoded JSON string |
| `execute_script/3` | `{:ok, conn} \| {:error, :closed \| :enotconn}` | Injects a `<script>` tag into `<body>`; auto-removes by default |
| `read_signals/1` | `{:ok, conn, signals} \| {:error, reason}` | Parses incoming DataStar signals from GET query params or POST body |
| `send_sse/4` (private) | `{:ok, conn} \| {:error, :closed \| :enotconn}` | Formats and chunks the SSE wire format |

**`patch_signals/3` accepts pre-encoded JSON strings only.** Callers are responsible for encoding with `Jason.encode/1` before calling.

**Typical usage pattern:**
```elixir
{:ok, json} = Jason.encode(%{"count" => 1})
conn = DataStarSSE.new_sse(conn)

with {:ok, conn} <- DataStarSSE.patch_elements(conn, "<div id='feed'>...</div>"),
     {:ok, conn} <- DataStarSSE.patch_signals(conn, json) do
  conn
else
  {:error, _} -> conn  # client disconnected
end
```

`new_sse/1` returns a bare `Plug.Conn.t()` (no error possible). All other send functions return tagged tuples so long-running SSE handlers can detect client disconnection.

## SSE Wire Format

Each event is formatted as:
```
event: <event-type>
[id: <event_id>]
[retry: <ms>]
data: <data-line>
...

```

Multi-line HTML or JSON is split on `\n` and emitted as separate `data:` lines.
