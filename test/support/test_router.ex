defmodule FrancisPages.TestRouter do
  use Francis
  use FrancisPages, layouts: "test/fixture/layouts"

  plug(:put_assigns)

  get("/health", fn _ -> %{status: "ok"} end)

  pages "/notes", from: "test/fixture/pages/notes", layout: "notes"
  pages "/", from: "test/fixture/pages/site", layout: "app"
  pages "/raw", from: "test/fixture/pages/raw"
  pages "/loaded", from: "test/fixture/pages/loaded", assigns: &load/1

  # A plug assign reaches pages and layouts; front matter wins on a clash
  defp put_assigns(conn, _opts) do
    conn
    |> Plug.Conn.assign(:user, "Ann")
    |> Plug.Conn.assign(:title, "Plug title")
  end

  # Runs after the route matches, so it sees [id]; its keys beat front matter
  defp load(conn), do: %{item: String.upcase(conn.params["id"]), title: "Loader title"}
end
