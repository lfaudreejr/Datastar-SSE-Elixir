# DataStar

Elixir SSE Helpers for [Datastar](https://data-star.dev) - A framework for building reactive web applications using Server-Sent Events and hypermedia.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `datastar` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:datastar, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
  def get("/sse") do
    conn
      |> DataStar.ServerSentEventGenerator.new_sse()
      |> DataStar.ServerSentEventGenerator.patch_elements(
          """
          <div id="question">What do you put in a toaster?</div>
          """,
        )
      |> DataStar.ServerSentEventGenerator.patch_signals(
          %{"response" => "", "answer" => "bread"},
        )
      |> DataStar.ServerSentEventGenerator.execute_script("console.log(123)")
  end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/datastar>.
