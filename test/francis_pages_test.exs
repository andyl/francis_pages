defmodule FrancisPagesTest do
  use ExUnit.Case
  import Plug.Test

  defp call(path),
    do: FrancisPages.TestRouter.call(conn(:get, path), FrancisPages.TestRouter.init([]))

  test "routes" do
    for {path, expect} <- [
          {"/health", ~s("ok")},
          {"/", "<nav>app</nav><h1>Home</h1>"},
          {"/about", "<em>there</em>"},
          {"/blog", "Blog index"},
          {"/blog/new", "New post form"},
          {"/blog/hello", "Post hello"},
          {"/blog/%3Cb%3E", "Post &lt;b&gt;"},
          {"/notes", "<nav>notes</nav><h1>Notes</h1>"},
          {"/notes/elixir/macros", "<h1>Macros</h1>"},
          {"/notes/a/b/c", "Catch-all: a/b/c"},
          {"/raw", "<p>raw page</p>"},
          {"/tags/elixir", "<h1>Pages tagged elixir</h1>"},
          {"/tags/elixir", "<li>item <em>1</em></li>\n<li>item <em>2</em></li>"},
          {"/tags/%3Cb%3E", "Pages tagged &lt;b&gt;"},
          {"/about", "<title>About us</title>"},
          {"/", "<title>My site</title>"},
          {"/tags/x", "<title>Tags</title>"},
          {"/team", "<title>Team</title><"},
          {"/team", "<h1>Team</h1>\n<li>Ann (dev)</li><li>Bob (ops)</li>"},
          {"/raw/empty", "<p>empty fm</p>"},
          {"/plain", "<p>No <strong>assigns</strong>.</p>"}
        ] do
      conn = call(path)
      assert conn.status == 200, path
      assert conn.resp_body =~ expect, "#{path}: #{conn.resp_body}"
    end

    assert call("/_partials/nav").status == 404
    assert call("/nope").status == 404
    assert Plug.Conn.get_resp_header(call("/"), "content-type") == ["text/html; charset=utf-8"]
    assert FrancisPages.TestRouter.__mix_recompile__?() == false
  end

  test "route mapping" do
    assert FrancisPages.route("/", "index.html.eex") == "/"
    assert FrancisPages.route("/notes", "index.md") == "/notes"
    assert FrancisPages.route("/notes", "a/b.html") == "/notes/a/b"
    assert FrancisPages.route("/", "blog/[slug].html.eex") == "/blog/:slug"
    assert FrancisPages.route("/", "tags/[tag].md.eex") == "/tags/:tag"
    assert_raise ArgumentError, fn -> FrancisPages.route("/", "[...a]/b.html") end
  end
end
