# README

Erlang/Elixir Crash Dump viewer in live view

## Running

`cdv.asserts` copies phoenix.min.js + phoenix_live_view.js into priv/static/assets/

```Bash
mix deps.get
mix cdv.assets
mix phx.server
```

---

## Project structure summary

```Text
cdv/
├── mix.exs                         # :observer in extra_applications
├── config/{config,dev,prod,runtime}.exs
└── lib/
    ├── cdv/
    │   ├── application.ex           # Starts DumpServer + Endpoint
    │   ├── dump_server.ex           # GenServer wrapping :crashdump_viewer backend
    │   └── records.ex               # Record.extract_all from cdv_info.hrl → maps
    └── cdv_web/
        ├── endpoint.ex
        ├── router.ex
        ├── components/
        │   ├── core_components.ex   # state_badge, format_int, humanize_bytes, kv_grid
        │   └── layouts/{root,app}.html.heex
        └── live/
            ├── home_live.ex         # Upload / path picker
            ├── general_live.ex      # General tab
            ├── processes_live.ex    # Sortable/filterable process table
            ├── process_detail_live.ex
            ├── ports_live.ex
            ├── port_detail_live.ex
            ├── ets_live.ex
            ├── timers_live.ex
            ├── memory_live.ex
            ├── nodes_live.ex
            └── modules_live.ex