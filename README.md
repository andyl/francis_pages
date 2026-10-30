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

A layout is an EEx file in the layouts directory, named after the layout
(`layouts/app.html.eex` for `layout: "app"`). `@inner_content` is the
rendered page:

```eex
<html>
  <head>
    <title>My site</title>
  </head>
  <body>
    <%= @inner_content %>
  </body>
</html>
```

## Assigns

`.eex` and `.md.eex` pages, and all layouts, can use:

- `@conn`: the request's `%Plug.Conn{}`
- `@params`: route, query and body params. `[slug]` is in
  `@params["slug"]`, and `[...path]` is a list in `@params["path"]`
- each top-level key of the page's front matter
- each key returned by the `pages` call's `:assigns` loader
- anything a plug put in `conn.assigns`
- `@inner_content`: the rendered page (layouts only)

When two sources set the same key, the `:assigns` loader wins over front
matter, and front matter wins over `conn.assigns`. `conn`, `params` and
`inner_content` are reserved: front matter or a loader that sets one is an
error, and a plug can't override them.

EEx doesn't escape HTML, so pass anything from the request or a database
through `Francis.HTML.escape/1`.

## Loading data

Front matter is YAML, read once at compile time, so it can only hold static
values. To give a page the result of a function call, such as a database
lookup, on each request, use one of these.

### The `:assigns` option

`pages/2` takes an `:assigns` function. It gets the conn and returns a
keyword list or map, and its keys become assigns for the page and the
layout:

```elixir
defmodule MyApp do
  use Francis
  use FrancisPages, layouts: "layouts"

  pages "/blog", from: "pages/blog", layout: "app", assigns: &MyApp.Blog.assigns/1
end

defmodule MyApp.Blog do
  def assigns(conn) do
    case conn.params do
      %{"slug" => slug} -> [post: get_post!(slug)]
      _ -> [posts: list_posts()]
    end
  end
end
```

```eex
<!-- pages/blog/[slug].html.eex -->
<h1><%= Francis.HTML.escape(@post.title) %></h1>
```

- It runs on every request, for every page of that `pages` call, after the
  route matches, so route params like `[slug]` are in `conn.params`.
- It can be a remote capture (`&MyApp.Blog.assigns/1`), a local function in
  the router (`&load/1`, which can be a `defp`) or an anonymous `fn`.
- One function serves the whole directory, so match on `conn.params` or
  `conn.path_info` when pages need different data.

Use it when several pages share a loader, or when you want the data access
out of the templates.

### A function call in the page

EEx pages are compiled into functions in your router module, so they can
call any function. The call runs on every request:

```eex
<!-- pages/blog/[slug].html.eex -->
<% post = MyApp.Blog.get_post!(@params["slug"]) %>
<h1><%= Francis.HTML.escape(post.title) %></h1>
```

This needs no router changes, which suits a one-off lookup for one page.
Keep the logic in a regular module and call it from the page, so the
template stays short. A value bound this way is local to the page: the
layout doesn't see it.

### A plug in the router

A plug runs before every route in the router. Anything it puts in
`conn.assigns` becomes an assign:

```elixir
defmodule MyApp do
  use Francis
  use FrancisPages, layouts: "layouts"

  plug :put_user

  pages "/", from: "pages/site", layout: "app"

  defp put_user(conn, _opts), do: Plug.Conn.assign(conn, :user, MyApp.Accounts.current(conn))
end
```

```eex
<!-- layouts/app.html.eex -->
<p>Signed in as <%= Francis.HTML.escape(@user.name) %></p>
```

Use it for values that many pages and layouts share, such as the current
user. Two things to know:

- Plugs run before the route matches, so route params (`@params["slug"]`)
  aren't set yet. Query and body params are, and so is `conn.path_info`.
- It runs for every request, including hand-written `get` routes, so skip
  costly lookups for paths that don't need them.

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

## Related Packages 

- [francis_template](https://github.com/josefrichter/francis_template) - Template rendering with pluggable engines (EEx, Liquid/Solid)
- [francis_htmx](https://github.com/francis-build/francis_htmx) - HTMX integration 

