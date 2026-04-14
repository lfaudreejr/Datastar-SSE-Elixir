defmodule DataStarSSE do
  @moduledoc """
  Elixir SSE helpers for DataStar (https://data-star.dev).

  Provides functions to open Server-Sent Event connections, send DOM patches,
  update client signals, execute scripts, and parse incoming DataStar signals.
  """

  @default_retry_duration 1000

  @doc """
  Sets up a connection to respond with Server-Sent Events.

  Returns `Plug.Conn.t()`.
  """
  @spec new_sse(Plug.Conn.t()) :: Plug.Conn.t()
  def new_sse(conn) do
    conn
    |> Plug.Conn.put_resp_header("cache-control", "no-cache")
    |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
    |> Plug.Conn.put_resp_header("connection", "keep-alive")
    |> Plug.Conn.send_chunked(200)
  end

  @doc """
  Sends a DataStar patch elements event.

  - `conn` - `Plug.Conn`
  - `elements` - HTML string to patch into the DOM, or `nil` when using `mode: "remove"` with a selector
  - `opts` - keyword options: `:selector`, `:mode` (default `"outer"`), `:use_view_transition`, `:event_id`, `:retry_duration`

  Returns `{:ok, Plug.Conn.t()}` or `{:error, :closed | :enotconn}`.

  ## Examples

  ```elixir
  {:ok, conn} = DataStarSSE.patch_elements(
    conn,
    ~s(<div id="welcome">Hello World!</div>),
    mode: "outer",
    use_view_transition: false,
    event_id: 123
  )
  ```
  """
  @spec patch_elements(Plug.Conn.t(), String.t() | nil, keyword()) ::
          {:ok, Plug.Conn.t()} | {:error, :closed | :enotconn}
  def patch_elements(conn, elements, opts \\ []) do
    selector = Keyword.get(opts, :selector)
    mode = Keyword.get(opts, :mode, "outer")
    use_view_transition = Keyword.get(opts, :use_view_transition, false)
    event_id = Keyword.get(opts, :event_id)
    retry_duration = Keyword.get(opts, :retry_duration)

    data_lines = []
    data_lines = if mode && mode != "outer", do: ["mode #{mode}" | data_lines], else: data_lines
    data_lines = if selector, do: ["selector #{selector}" | data_lines], else: data_lines

    data_lines =
      if use_view_transition, do: ["useViewTransition true" | data_lines], else: data_lines

    data_lines =
      if is_bitstring(elements) do
        elements
        |> String.split("\n", trim: true)
        |> Enum.reduce(data_lines, fn line, acc ->
          ["elements #{line}" | acc]
        end)
      else
        data_lines
      end

    data_lines = Enum.reverse(data_lines)

    send_opts = []
    send_opts = if event_id, do: Keyword.put(send_opts, :event_id, event_id), else: send_opts

    send_opts =
      if retry_duration,
        do: Keyword.put(send_opts, :retry_duration, retry_duration),
        else: send_opts

    send_sse(conn, "datastar-patch-elements", data_lines, send_opts)
  end

  @doc """
  Sends a DataStar patch signals event.

  - `conn` - `Plug.Conn`
  - `signals` - pre-encoded JSON string (use `Jason.encode!/1` before calling)
  - `opts` - keyword options: `:only_if_missing`, `:event_id`, `:retry_duration`

  Returns `{:ok, Plug.Conn.t()}` or `{:error, :closed | :enotconn}`.

  ## Examples

  ```elixir
  {:ok, json} = Jason.encode(%{"signal" => "Hello World"})
  {:ok, conn} = DataStarSSE.patch_signals(conn, json, only_if_missing: true, event_id: 123)
  ```
  """
  @spec patch_signals(Plug.Conn.t(), String.t(), keyword()) ::
          {:ok, Plug.Conn.t()} | {:error, :closed | :enotconn}
  def patch_signals(conn, signals, opts \\ []) do
    only_if_missing = Keyword.get(opts, :only_if_missing, false)
    event_id = Keyword.get(opts, :event_id)
    retry_duration = Keyword.get(opts, :retry_duration)

    data_lines = []
    data_lines = if only_if_missing, do: ["onlyIfMissing true" | data_lines], else: data_lines

    data_lines =
      signals
      |> String.split("\n", trim: true)
      |> Enum.reduce(data_lines, fn line, acc ->
        ["signals #{line}" | acc]
      end)

    data_lines = Enum.reverse(data_lines)

    send_opts = []
    send_opts = if event_id, do: Keyword.put(send_opts, :event_id, event_id), else: send_opts

    send_opts =
      if retry_duration,
        do: Keyword.put(send_opts, :retry_duration, retry_duration),
        else: send_opts

    send_sse(conn, "datastar-patch-signals", data_lines, send_opts)
  end

  @doc """
  Sends a DataStar execute script event.

  Injects a `<script>` tag into `<body>` via a `datastar-patch-elements` event.
  The script is auto-removed from the DOM after execution by default.

  - `conn` - `Plug.Conn`
  - `script` - JavaScript string to execute
  - `opts` - keyword options: `:auto_remove` (default `true`), `:attributes`, `:event_id`, `:retry_duration`

  Returns `{:ok, Plug.Conn.t()}` or `{:error, :closed | :enotconn}`.

  ## Examples

  ```elixir
  {:ok, conn} = DataStarSSE.execute_script(conn, "console.log('Hello World!')", event_id: 123)
  ```
  """
  @spec execute_script(Plug.Conn.t(), String.t(), keyword()) ::
          {:ok, Plug.Conn.t()} | {:error, :closed | :enotconn}
  def execute_script(conn, script, opts \\ []) do
    auto_remove = Keyword.get(opts, :auto_remove, true)
    attributes = Keyword.get(opts, :attributes, [])
    event_id = Keyword.get(opts, :event_id)
    retry_duration = Keyword.get(opts, :retry_duration)

    attrs = []
    attrs = if auto_remove, do: ["data-effect=\"el.remove()\"" | attrs], else: attrs

    attributes = Enum.map(attributes, fn {k, v} -> "#{k}=\"#{v}\"" end)
    attrs = attributes ++ attrs

    attr_string = if Enum.empty?(attrs), do: "", else: " #{Enum.join(attrs, " ")}"

    script_tag = "<script#{attr_string}>#{script}</script>"

    data_lines = ["mode append", "selector body", "elements #{script_tag}"]

    send_opts = []
    send_opts = if event_id, do: Keyword.put(send_opts, :event_id, event_id), else: send_opts

    send_opts =
      if retry_duration,
        do: Keyword.put(send_opts, :retry_duration, retry_duration),
        else: send_opts

    send_sse(conn, "datastar-patch-elements", data_lines, send_opts)
  end

  @doc """
  Parses DataStar signals from a `Plug.Conn` as JSON.

  Handles both GET requests (signals in `?datastar=` query param) and
  POST requests (signals in request body). Works with both parsed and
  unparsed connections.

  Returns `{:ok, conn, signals}` or `{:error, reason}`.

  ## Examples

  ```elixir
  case DataStarSSE.read_signals(conn) do
    {:ok, conn, signals} -> # use signals map
    {:error, reason} -> # handle error
  end
  ```
  """
  @spec read_signals(Plug.Conn.t()) :: {:ok, Plug.Conn.t(), map()} | {:error, term()}
  def read_signals(conn) do
    case conn.method do
      "GET" -> read_get_signals(conn)
      _other -> read_post_signals(conn)
    end
  end

  defp read_get_signals(conn) do
    conn |> get_datastar_param() |> decode_json_param(conn)
  end

  defp get_datastar_param(%{query_params: %Plug.Conn.Unfetched{}, query_string: qs}) do
    qs |> URI.decode_query() |> Map.get("datastar")
  end

  defp get_datastar_param(%{query_params: params}) do
    Map.get(params, "datastar")
  end

  defp decode_json_param(nil, _conn), do: {:error, :no_datastar_param}

  defp decode_json_param(json_string, conn) do
    case Jason.decode(json_string) do
      {:ok, signals} -> {:ok, conn, signals}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_post_signals(%{body_params: %Plug.Conn.Unfetched{}} = conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)

    case Jason.decode(body) do
      {:ok, signals} -> {:ok, conn, signals}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_post_signals(conn), do: {:ok, conn, conn.body_params}

  defp send_sse(conn, event_type, data_lines, opts) do
    event_id = Keyword.get(opts, :event_id)
    retry_duration = Keyword.get(opts, :retry_duration, @default_retry_duration)

    lines = []
    lines = ["event: #{event_type}\n" | lines]
    lines = if event_id, do: ["id: #{event_id}\n" | lines], else: lines

    lines =
      if retry_duration != @default_retry_duration,
        do: ["retry: #{retry_duration}\n" | lines],
        else: lines

    lines =
      Enum.reduce(data_lines, lines, fn data_line, acc ->
        ["data: #{data_line}\n" | acc]
      end)

    lines = ["\n" | lines]

    lines = Enum.reverse(lines)

    Enum.reduce_while(lines, {:ok, conn}, fn chunk, {:ok, conn} ->
      case Plug.Conn.chunk(conn, chunk) do
        {:ok, conn} ->
          {:cont, {:ok, conn}}

        {:error, :closed} ->
          {:halt, {:error, :closed}}

        {:error, :enotconn} ->
          {:halt, {:error, :enotconn}}
      end
    end)
  end
end
