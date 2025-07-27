defmodule DataStarTest do
  use ExUnit.Case
  doctest DataStar

  import Plug.Test

  test "starts sse conn" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    assert conn.status == 200

    assert conn.resp_headers == [
             {"cache-control", "no-cache"},
             {"content-type", "text/event-stream"},
             {"connection", "keep-alive"}
           ]

    assert conn.state == :chunked
  end

  test "patch_elements minimal" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.patch_elements(
        conn,
        """
        <div id="feed"><span>1</span></div>
        """,
        []
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: elements <div id=\"feed\"><span>1</span></div>\n\n"
  end

  test "patch_elements ID based" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.patch_elements(
        conn,
        """
        <div id="id1">New content.</div>
        <div id="id2">Other new content.</div>
        """,
        []
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: elements <div id=\"id1\">New content.</div>\ndata: elements <div id=\"id2\">Other new content.</div>\n\n"
  end

  test "patch_elements insert by selector" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.patch_elements(
        conn,
        """
        <div>New content</div>
        """,
        mode: "append",
        selector: "#mycontainer"
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: mode append\ndata: selector #mycontainer\ndata: elements <div>New content</div>\n\n"
  end

  test "patch_elements remove selector" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.patch_elements(
        conn,
        nil,
        mode: "remove",
        selector: "#feed, #otherid"
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: mode remove\ndata: selector #feed, #otherid\n\n"
  end

  test "patch_elements remove without selector" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.patch_elements(
        conn,
        """
        <div id="first"></div><div id="second"></div>
        """,
        mode: "remove"
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: mode remove\ndata: elements <div id=\"first\"></div><div id=\"second\"></div>\n\n"
  end

  test "patch_signals" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    {:ok, json} = Jason.encode(%{"newSignal" => "test"})

    conn =
      DataStar.ServerSentEventGenerator.patch_signals(
        conn,
        json,
        []
      )

    assert conn.resp_body ==
             "event: datastar-patch-signals\ndata: signals {\"newSignal\":\"test\"}\n\n"
  end

  test "execute_script minimal" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.execute_script(
        conn,
        "console.log('Here')",
        []
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\ndata: mode append\ndata: selector body\ndata: elements <script data-effect=\"el.remove()\">console.log('Here')</script>\n\n"
  end

  test "execute_script full" do
    conn = conn(:get, "/sse")
    conn = DataStar.ServerSentEventGenerator.new(conn, [])

    conn =
      DataStar.ServerSentEventGenerator.execute_script(
        conn,
        "console.log('Here')",
        event_id: "123",
        retry_duration: 2000,
        attributes: [type: "application/javascript"]
      )

    assert conn.resp_body ==
             "event: datastar-patch-elements\nid: 123\nretry: 2000\ndata: mode append\ndata: selector body\ndata: elements <script type=\"application/javascript\" data-effect=\"el.remove()\">console.log('Here')</script>\n\n"
  end

  test "read signals post - non parsed json" do
    {:ok, json} = Jason.encode(%{signal: "test"})

    conn =
      conn(:post, "/sse", json) |> Plug.Conn.put_req_header("content-type", "application/json")

    {:ok, _, signals} =
      DataStar.ServerSentEventGenerator.read_signals(conn, nil)

    assert signals == %{"signal" => "test"}
  end

  test "read_signals post - parsed json" do
    {:ok, json} = Jason.encode(%{signal: "test"})
    conn = json |> json_conn() |> parse()

    {:ok, _, signals} =
      DataStar.ServerSentEventGenerator.read_signals(conn, nil)

    assert signals == %{"signal" => "test"}
  end

  test "read_Signals get - query params" do
    {:ok, json} = Jason.encode(%{signal: "test"})
    conn = conn(:get, "/sse?datastar=#{json}")

    {:ok, _, signals} =
      DataStar.ServerSentEventGenerator.read_signals(conn, nil)

    assert signals == %{"signal" => "test"}
  end

  test "read_Signals get - query params parse" do
    {:ok, json} = Jason.encode(%{signal: "test"})
    conn = conn(:get, "/sse?datastar=#{json}") |> parse()

    {:ok, _, signals} =
      DataStar.ServerSentEventGenerator.read_signals(conn, nil)

    assert signals == %{"signal" => "test"}
  end

  def json_conn(body, content_type \\ "application/json") do
    Plug.Conn.put_req_header(conn(:post, "/", body), "content-type", content_type)
  end

  def parse(conn, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:parsers, [:json])
      |> Keyword.put_new(:json_decoder, JSON)

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
