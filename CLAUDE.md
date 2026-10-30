# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

francis_pages is a standalone Mix package (github.com/andyl/francis_pages)
that adds a `pages/2` macro to [Francis](https://francis.build) routers: each
file in a pages directory becomes a route. It is not published to Hex; apps
use it through a `path:` or `github:` dependency.

The design doc is `../notes/francis/francis-pages.md`. It holds the routing
rules, file types, front matter and gaps, plus a copy of the macro. When you
change `lib/francis_pages.ex`, update the copy in that doc too.

## Commands

```bash
mix deps.get
mix compile --warnings-as-errors
mix test
mix format --check-formatted
```

## Layout

- `lib/francis_pages.ex`: the whole package, one module (`FrancisPages`).
  `use FrancisPages` sets up the router; `pages/2` expands into Francis
  `get` routes at compile time.
- `test/fixture/`: pages and layouts used by the tests.
- `test/support/test_router.ex`: `FrancisPages.TestRouter`, a Francis router
  that mounts the fixtures. Compiled only in `:test`.
- `test/francis_pages_test.exs`: route tests against the test router, plus
  unit tests for `FrancisPages.route/2`.

## Things to keep in mind

- `pages/2` runs while the app's router compiles, so `from:` and
  `:layouts` paths are relative to the app's root (the package root, in
  the tests).
- Pages are read at compile time and listed in `@external_resource`;
  `__mix_recompile__?/0` in the router catches added or removed pages.
- The module name is `FrancisPages`, not `Francis.Pages`: the `Francis`
  namespace belongs to the Francis package.
- Tested with Elixir 1.20.4, Francis 0.4.0, MDEx 0.14.3, YamlElixir 2.12.2.
