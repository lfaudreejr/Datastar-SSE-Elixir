defmodule DataStarSSE do
  @moduledoc """
  Documentation for `DataStarSSE`.
  """

  defmodule ServerSentEventGenerator do
    @moduledoc """
    The `ServerSentEventGenerator` module.
    """
    @default_retry_duration 1000

    @doc """
    Setups of connection to response with Server-Sent Events

    returns Plug.Conn
    """
    def new_sse(conn) do
      conn
      |> Plug.Conn.put_resp_header("cache-control", "no-cache")
      |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
      |> Plug.Conn.put_resp_header("connection", "keep-alive")
      |> Plug.Conn.send_chunked(200)
    end

    @doc """
    Sends a DataStar patch elements event

    conn - Plug.Conn
    elements - String
    opts - Optional Datastar patch element event options

    returns Plug.Conn

    ## Examples
      DataStarSSE.ServerSentEventGenerator.patch_elements(
        conn,
        "<div id="welcome">Hello World!</div>",
        mode: "outer",
        use_view_transition: false,
        event_id: 123
      )
    """
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

      send(conn, "datastar-patch-elements", data_lines, send_opts)
    end

    @doc """
    Sends a DataStar patch signals event

    conn - Plug.Conn
    signals - String
    opts - Optional Datastar patch element event options

    returns Plug.Conn

    ## Examples
      DataStarSSE.ServerSentEventGenerator.patch_signals(
        conn,
        Jason.encode(%{"signal" => "Hello World"}),
        only_if_missing: true,
        event_id: 123
      )
    """
    def patch_signals(conn, signals, opts \\ []) do
      only_if_missing = Keyword.get(opts, :only_if_missing, false)
      event_id = Keyword.get(opts, :event_id)
      retry_duration = Keyword.get(opts, :retry_duration)

      data_lines = []
      data_lines = if only_if_missing, do: ["onlyIfMissing true" | data_lines], else: data_lines

      signal_lines =
        if is_bitstring(signals) do
          String.split(signals, "\n", trim: true)
        else
          case Jason.encode(signals) do
            {:ok, json} ->
              String.split(json, "\n", trim: true)

            {:error, _} ->
              []
          end
        end

      data_lines =
        Enum.reduce(signal_lines, data_lines, fn line, acc ->
          ["signals #{line}" | acc]
        end)

      data_lines = Enum.reverse(data_lines)

      send_opts = []
      send_opts = if event_id, do: Keyword.put(send_opts, :event_id, event_id), else: send_opts

      send_opts =
        if retry_duration,
          do: Keyword.put(send_opts, :retry_duration, retry_duration),
          else: send_opts

      send(conn, "datastar-patch-signals", data_lines, send_opts)
    end

    @doc """
    Sends a DataStar execute script event

    conn - Plug.Conn
    script - String
    opts - Optional Datastar execute script event options

    returns Plug.Conn

    ## Examples
      DataStarSSE.ServerSentEventGenerator.execute_script(
        conn,
        "console.log('Hello World!')",
        auto_remove: true,
        event_id: 123
      )
    """
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

      send(conn, "datastar-patch-elements", data_lines, send_opts)
    end

    @doc """
    Parses DataStar signals from Plug.Conn as JSON

    conn - Plug.Conn
    script - String
    opts - Optional Datastar execute script event options

    returns {:ok, conn, signals} or {:error, reason}

    ## Examples
      DataStarSSE.ServerSentEventGenerator.read_signals(conn)
    """
    def read_signals(conn) do
      case conn.method do
        "GET" ->
          case conn.query_params do
            %Plug.Conn.Unfetched{} ->
              conn.query_string
              |> URI.decode_query()
              |> Map.get("datastar")
              |> case do
                nil ->
                  {:error, :no_datastar_param}

                json_string ->
                  case Jason.decode(json_string) do
                    {:ok, signals} ->
                      {:ok, conn, signals}

                    {:error, reason} ->
                      {:error, reason}
                  end
              end

            json ->
              json_string = Map.get(json, "datastar")

              case Jason.decode(json_string) do
                {:ok, signals} ->
                  {:ok, conn, signals}

                {:error, reason} ->
                  {:error, reason}
              end
          end

        _other ->
          case conn.body_params do
            %Plug.Conn.Unfetched{} ->
              {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)

              case Jason.decode(body) do
                {:ok, signals} ->
                  {:ok, conn, signals}

                {:error, reason} ->
                  {:error, reason}
              end

            signals ->
              {:ok, conn, signals}
          end
      end
    end

    defp send(conn, event_type, data_lines, opts) do
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

      Enum.reduce_while(lines, conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}

          {:error, :enotconn} ->
            {:halt, conn}
        end
      end)
    end
  end
end
