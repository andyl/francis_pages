defmodule FrancisPages do
  @moduledoc "File-based pages for a Francis router."

  @extensions ~w(.html .eex .md)
  @reserved ~w(conn params inner_content)a

  defmacro __using__(opts) do
    layouts = Keyword.get(opts, :layouts, "layouts")

    quote do
      import FrancisPages, only: [pages: 2]
      require EEx

      @pages_layouts unquote(layouts)
      Module.register_attribute(__MODULE__, :pages_sources, accumulate: true)
      @before_compile FrancisPages

      def __pages_no_layout__(assigns), do: assigns[:inner_content]
    end
  end

  defmacro pages(prefix, opts) do
    dir = Keyword.fetch!(opts, :from)
    layout = Keyword.get(opts, :layout)

    unless is_binary(prefix) and is_binary(dir) and (is_nil(layout) or is_binary(layout)) do
      raise ArgumentError, "pages/2 needs string literals for the prefix, :from and :layout"
    end

    layout_fun = if layout, do: :"__layout_#{layout}__", else: :__pages_no_layout__

    routes =
      dir
      |> files()
      |> Enum.map(&{route(prefix, Path.relative_to(&1, dir)), &1})
      |> check_unique!()
      |> Enum.sort_by(fn {route, _file} -> {rank(route), route} end)

    page_routes =
      for {route, file} <- routes do
        page_fun = :"__page_#{:erlang.phash2({prefix, file})}__"
        {front_matter, body, line} = read_page(file)

        quote do
          @external_resource unquote(file)
          unquote(page_def(page_fun, file, body, line))

          get(unquote(route), fn conn ->
            assigns = [conn: conn, params: conn.params] ++ unquote(Macro.escape(front_matter))
            inner = unquote(page_fun)(assigns)
            html = unquote(layout_fun)(Keyword.put(assigns, :inner_content, inner))
            FrancisPages.respond(conn, html)
          end)
        end
      end

    quote do
      @pages_sources {unquote(dir), unquote(hash(dir))}
      unquote(layout_def(layout, layout_fun))
      unquote_splicing(page_routes)
    end
  end

  defmacro __before_compile__(env) do
    sources = Module.get_attribute(env.module, :pages_sources)

    quote do
      # Recompile when a page is added or removed, not just edited
      def __mix_recompile__? do
        Enum.any?(unquote(sources), fn {dir, hash} -> FrancisPages.hash(dir) != hash end)
      end
    end
  end

  @doc "Page files under `dir`. Anything under a `_`-prefixed name is skipped."
  def files(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&(Path.extname(&1) in @extensions))
    |> Enum.reject(fn file ->
      file |> Path.relative_to(dir) |> Path.split() |> Enum.any?(&String.starts_with?(&1, "_"))
    end)
  end

  def hash(dir), do: dir |> files() |> :erlang.phash2()

  @doc "Maps a file path, relative to the pages dir, to a Plug.Router route."
  def route(prefix, relative) do
    segments = relative |> strip_extensions() |> Path.split()
    segments = if List.last(segments) == "index", do: Enum.drop(segments, -1), else: segments
    segments = Enum.map(segments, &segment/1)

    if Enum.any?(Enum.drop(segments, -1), &String.starts_with?(&1, "*")) do
      raise ArgumentError, "pages: a [...rest] segment must come last, in #{relative}"
    end

    Path.join(["/", prefix | segments])
  end

  def respond(conn, html) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, html)
  end

  defp strip_extensions(path) do
    if Path.extname(path) in @extensions, do: strip_extensions(Path.rootname(path)), else: path
  end

  defp segment("[..." <> rest), do: "*" <> String.trim_trailing(rest, "]")
  defp segment("[" <> rest), do: ":" <> String.trim_trailing(rest, "]")
  defp segment(name), do: name

  # Plug.Router takes the first match, so static segments go before :params, and those before *globs
  defp rank(route) do
    route
    |> String.split("/", trim: true)
    |> Enum.map(fn
      ":" <> _ -> 1
      "*" <> _ -> 2
      _ -> 0
    end)
  end

  defp check_unique!(routes) do
    for {route, [_, _ | _] = dupes} <- Enum.group_by(routes, &elem(&1, 0), &elem(&1, 1)) do
      raise ArgumentError, "pages: #{Enum.join(dupes, " and ")} both map to #{route}"
    end

    routes
  end

  # Splits a page into its front matter (as assigns), its body and the body's first line
  defp read_page(file) do
    source = File.read!(file)

    case Regex.run(~r/\A---\r?\n(.*?)^---[ \t]*(?:\r?\n|\z)/ms, source) do
      nil ->
        {[], source, 1}

      [block, yaml] ->
        body = binary_part(source, byte_size(block), byte_size(source) - byte_size(block))
        {parse_front_matter(yaml, file), body, length(String.split(block, "\n"))}
    end
  end

  defp parse_front_matter(yaml, file) do
    map =
      case YamlElixir.read_from_string(yaml) do
        {:ok, map} when is_map(map) -> map
        {:ok, nil} -> %{}
        _ -> raise ArgumentError, "pages: front matter must be YAML key/value pairs, in #{file}"
      end

    for {key, value} <- map do
      key = String.to_atom(to_string(key))

      if key in @reserved do
        raise ArgumentError, "pages: front matter can't set @#{key}, in #{file}"
      end

      {key, value}
    end
  end

  defp page_def(fun, file, source, line) do
    case Path.extname(file) do
      ".eex" ->
        # Like EEx.function_from_file/4, minus the unused-variable warning on static pages
        body = EEx.compile_string(source, file: file, line: line)

        # A .md.eex page renders its Markdown on each request, then converts it to HTML
        body =
          if Path.extname(Path.rootname(file)) == ".md",
            do: quote(do: MDEx.to_html!(unquote(body))),
            else: body

        quote do
          def unquote(fun)(var!(assigns)) do
            _ = var!(assigns)
            unquote(body)
          end
        end

      ".md" ->
        if String.contains?(file, "[") do
          raise ArgumentError, "pages: Markdown pages can't be dynamic, use .md.eex for #{file}"
        end

        html = MDEx.to_html!(source)
        quote do: def(unquote(fun)(_assigns), do: unquote(html))

      ".html" ->
        quote do: def(unquote(fun)(_assigns), do: unquote(source))
    end
  end

  defp layout_def(nil, _fun), do: nil

  defp layout_def(layout, fun) do
    quote do
      # Several pages/2 calls can share a layout; compile it once
      unless Module.defines?(__MODULE__, {unquote(fun), 1}) do
        @external_resource Path.join(@pages_layouts, unquote("#{layout}.html.eex"))
        EEx.function_from_file(
          :def,
          unquote(fun),
          Path.join(@pages_layouts, unquote("#{layout}.html.eex")),
          [:assigns]
        )
      end
    end
  end
end
