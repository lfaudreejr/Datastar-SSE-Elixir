# DataStarSSE

Elixir SSE Helpers for [DataStar](https://data-star.dev) - A framework for building reactive web applications using Server-Sent Events and hypermedia.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `datastar_sse` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:datastar_sse, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
  def get("/sse") do
    conn
      |> DataStarSSE.ServerSentEventGenerator.new_sse()
      |> DataStarSSE.ServerSentEventGenerator.patch_elements(
          """
          <div id="question">What do you put in a toaster?</div>
          """,
        )
      |> DataStarSSE.ServerSentEventGenerator.patch_signals(
          %{"response" => "", "answer" => "bread"},
        )
      |> DataStarSSE.ServerSentEventGenerator.execute_script("console.log(123)")
  end
```

If using Phoenix, add to config.exs
```elixir
  # Accept event-stream requests
  config :mime, :types, %{
    "text/event-stream" => ["sse"]
  }
```
and to router.ex
```elixir
  plug :accepts, ["sse"]
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/datastar>.
