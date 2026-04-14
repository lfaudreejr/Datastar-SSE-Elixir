# DataStarSSE

Elixir SSE Helpers for [DataStar](https://data-star.dev) - A framework for building reactive web applications using Server-Sent Events and hypermedia.

## Installation

```elixir
def deps do
  [
    {:datastar_sse, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
def sse(conn, _params) do
  {:ok, json} = Jason.encode(%{"response" => "", "answer" => "bread"})
  conn = DataStarSSE.new_sse(conn)

  with {:ok, conn} <- DataStarSSE.patch_elements(conn, ~s(<div id="question">What do you put in a toaster?</div>)),
       {:ok, conn} <- DataStarSSE.patch_signals(conn, json),
       {:ok, conn} <- DataStarSSE.execute_script(conn, "console.log(123)") do
    conn
  end
end
```

`patch_signals/3` accepts a pre-encoded JSON string — encode with `Jason.encode/1` before calling.

## Reading Signals

DataStar sends signals as part of the request. Use `read_signals/1` to parse them:

```elixir
def sse(conn, _params) do
  conn = SSE.new_sse(conn)

  with {:ok, conn, signals} <- SSE.read_signals(conn),
       {:ok, json} <- Jason.encode(%{"echo" => signals["message"]}),
       {:ok, conn} <- SSE.patch_signals(conn, json) do
    conn
  end
end
```

## Phoenix Setup

Add to `config.exs`:
```elixir
config :mime, :types, %{
  "text/event-stream" => ["sse"]
}
```

Add to `router.ex`:
```elixir
plug :accepts, ["sse"]
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm/datastar_sse).
