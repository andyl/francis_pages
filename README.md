# FrancisPages

File-based pages for [Francis](https://francis.build) routers. Drop a file
into a pages directory and it becomes a route, the way
[Astral](https://github.com/elixir-volt/astral) does.

```elixir
defmodule MyApp do
  use Francis
  use FrancisPages, layouts: "layouts"

  pages "/notes", from: "pages/notes", layout: "notes"
  pages "/",      from: "pages/site",  layout: "app"
end
```

Pages can be `.html`, `.md`, `.html.eex` or `.md.eex`, with optional YAML
front matter. `[slug]` and `[...path]` file names become dynamic routes.

## Installation

Not published to Hex. Add it as a path or GitHub dependency:

```elixir
def deps do
  [
    {:francis, "~> 0.4"},
    {:francis_pages, github: "andyl/francis_pages"}
    # or: {:francis_pages, path: "../francis_pages"}
  ]
end
```

To call `pages` without parentheses, add `import_deps: [:francis_pages]` to
your `.formatter.exs`.
