Mix.install([:plug, :bandit, :jason])
# defmodule EchoServer do
#   def init(options) do
#     {:ok, options}
#   end

#   def handle_in({"ping", [opcode: :text]}, state) do
#     {:reply, :ok, {:text, "pong"}, state}
#   end

#   def terminate(:timeout, state) do
#     {:ok, state}
#   end
# end
Code.require_file("../data_star.ex", __DIR__)

defmodule Router do
  require DataStar
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  post "/test" do
    conn = DataStar.ServerSentEventGenerator.new_sse(conn)
    {:ok, conn, signals} = DataStar.ServerSentEventGenerator.read_signals(conn)

    Enum.reduce(signals["events"], conn, fn event, conn ->
      case event["type"] do
        "executeScript" ->
          DataStar.ServerSentEventGenerator.execute_script(conn, event["script"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            attributes: [type: "text/javascript", blocking: "false"]
          )

        "patchElements" ->
          DataStar.ServerSentEventGenerator.patch_elements(conn, event["elements"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            selector: event["selector"],
            mode: event["mode"],
            use_view_transition: event["useViewTransition"]
          )

        "patchSignals" ->
          DataStar.ServerSentEventGenerator.patch_signals(
            conn,
            event["signals"] || event["signals-raw"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            only_if_missing: event["onlyIfMissing"]
          )
      end
    end)
  end

  get "/test" do
    conn = DataStar.ServerSentEventGenerator.new_sse(conn)
    {:ok, conn, signals} = DataStar.ServerSentEventGenerator.read_signals(conn)

    Enum.reduce(signals["events"], conn, fn event, conn ->
      case event["type"] do
        "executeScript" ->
          DataStar.ServerSentEventGenerator.execute_script(conn, event["script"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            attributes: [type: "text/javascript", blocking: "false"]
          )

        "patchElements" ->
          DataStar.ServerSentEventGenerator.patch_elements(conn, event["elements"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            selector: event["selector"],
            mode: event["mode"],
            use_view_transition: event["useViewTransition"]
          )

        "patchSignals" ->
          DataStar.ServerSentEventGenerator.patch_signals(
            conn,
            event["signals"] || event["signals-raw"],
            event_id: event["eventId"],
            retry_duration: event["retryDuration"],
            only_if_missing: event["onlyIfMissing"]
          )
      end
    end)
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end

require Logger
webserver = {Bandit, plug: Router, scheme: :http, port: 7331}
{:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)
Logger.info("Plug now running on localhost:4000")
Process.sleep(:infinity)
