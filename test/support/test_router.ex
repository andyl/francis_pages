defmodule FrancisPages.TestRouter do
  use Francis
  use FrancisPages, layouts: "test/fixture/layouts"

  get("/health", fn _ -> %{status: "ok"} end)

  pages "/notes", from: "test/fixture/pages/notes", layout: "notes"
  pages "/", from: "test/fixture/pages/site", layout: "app"
  pages "/raw", from: "test/fixture/pages/raw"
end
