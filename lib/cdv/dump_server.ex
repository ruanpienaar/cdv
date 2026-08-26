defmodule Cdv.DumpServer do
  @moduledoc """
  Wraps the OTP `crashdump_viewer` backend GenServer.

  The `:crashdump_viewer` module is a pure backend — it parses the crash dump
  file and answers queries. `crashdump_viewer_wx` is the wx GUI normally layered
  on top. We bypass the GUI entirely and call the backend directly.

  ## Caching

  A crash dump is a file on disk that never changes while it is loaded, so every
  parse of a given section is guaranteed to produce the same answer. Parsing is
  the expensive part (seconds, for the process table of a large dump), so each
  section is parsed at most once and kept in an ETS table for the lifetime of
  the load. Readers hit ETS directly and never touch this GenServer.

  Two things follow from that:

    * Concurrent misses for the same section are de-duplicated — the first
      caller starts the work, the rest wait on the same result.
    * After a successful load, the sections are parsed in the background so the
      first visit to a page is usually a cache hit too.

  Only successful results are cached; an error is left uncached so it retries.
  """

  use GenServer
  alias Cdv.Records
  require Logger

  @cache :cdv_dump_cache

  # Warmed in the background after a load, in roughly the order a user meets
  # them: /general is the landing page, /processes the usual first stop.
  @warm_sections [
    :general_info,
    :processes,
    :memory,
    :ports,
    :ets_tables,
    :timers,
    :nodes,
    :loaded_mods
  ]

  # ---- Public API -----------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def load(path, display_name \\ nil, owned? \\ false) when is_binary(path) do
    GenServer.call(__MODULE__, {:load, path, display_name, owned?}, :infinity)
  end

  def unload do
    GenServer.call(__MODULE__, :unload)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def general_info, do: fetch(:general_info)
  def processes, do: fetch(:processes)
  def ports, do: fetch(:ports)
  def ets_tables, do: fetch(:ets_tables)
  def timers, do: fetch(:timers)
  def nodes, do: fetch(:nodes)
  def loaded_mods, do: fetch(:loaded_mods)
  def memory, do: fetch(:memory)

  def proc_info(pid_str), do: fetch({:proc_info, pid_str})
  def port_info(port_str), do: fetch({:port_info, port_str})

  @doc """
  Which sections are currently cached, and whether background warming is still
  running. Handy from IEx when checking whether a page will be instant.
  """
  def cache_info do
    GenServer.call(__MODULE__, :cache_info)
  end

  # Cache hits never reach the GenServer — that is the whole point.
  defp fetch(key) do
    case :ets.lookup(@cache, key) do
      [{^key, result}] -> result
      [] -> GenServer.call(__MODULE__, {:fetch, key}, :infinity)
    end
  end

  # ---- GenServer callbacks --------------------------------------------------

  @impl true
  def init(:ok) do
    :ets.new(@cache, [:named_table, :set, :public, read_concurrency: true])

    {:ok,
     %{
       status: :idle,
       path: nil,
       filename: nil,
       truncated: false,
       error: nil,
       owned?: false,
       # bumped on every load/unload so results from a previous dump can be
       # recognised and dropped
       gen: 0,
       inflight: %{},
       warm_queue: []
     }}
  end

  @impl true
  def handle_call({:load, path, display_name, owned?}, _from, state) do
    state = reset(state, "Dump was replaced while loading")
    stop_backend()
    cleanup_owned(state)

    charpath = String.to_charlist(path)
    filename = display_name || Path.basename(path)
    Logger.info("[CdvDumpServer] Loading: #{path}")

    with :ok <- ensure_backend_started() do
      :crashdump_viewer.read_file(charpath)
      # Any call after the cast is queued behind it — this blocks until loading is done
      case :crashdump_viewer.get_dump_versions() do
        {:ok, {_max, vsn}} when vsn != :undefined ->
          send(self(), :warm_next)

          new_state = %{
            state
            | status: :loaded,
              path: path,
              filename: filename,
              truncated: false,
              error: nil,
              owned?: owned?,
              warm_queue: @warm_sections
          }

          {:reply, :ok, new_state}

        _ ->
          msg = "File is not a valid Erlang crash dump"
          Logger.error("[CdvDumpServer] #{msg}: #{path}")

          {:reply, {:error, msg},
           %{state | status: :idle, path: nil, filename: nil, owned?: false, error: msg}}
      end
    else
      {:error, reason} ->
        Logger.error("[CdvDumpServer] Failed to start backend: #{reason}")

        {:reply, {:error, reason},
         %{state | status: :idle, path: nil, filename: nil, owned?: false, error: reason}}
    end
  end

  @impl true
  def handle_call(:unload, _from, state) do
    state = reset(state, "Dump was unloaded")
    stop_backend()
    cleanup_owned(state)

    {:reply, :ok,
     %{
       state
       | status: :idle,
         path: nil,
         filename: nil,
         truncated: false,
         error: nil,
         owned?: false
     }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:status, :path, :filename, :truncated, :error]), state}
  end

  @impl true
  def handle_call(:cache_info, _from, state) do
    cached = @cache |> :ets.select([{{:"$1", :_}, [], [:"$1"]}]) |> Enum.sort_by(&inspect/1)

    {:reply,
     %{
       cached: cached,
       warming: state.warm_queue,
       inflight: Map.keys(state.inflight)
     }, state}
  end

  @impl true
  def handle_call({:fetch, key}, from, %{status: :loaded} = state) do
    # Another caller may have filled the cache between the ETS miss and here.
    case :ets.lookup(@cache, key) do
      [{^key, result}] -> {:reply, result, state}
      [] -> {:noreply, start_or_join(state, key, from)}
    end
  end

  @impl true
  def handle_call({:fetch, _key}, _from, state) do
    {:reply, {:error, "No dump loaded"}, state}
  end

  @impl true
  def handle_info({:fetched, gen, key, result}, %{gen: gen} = state) do
    # Errors stay uncached so a later visit can retry.
    if match?({:ok, _}, result), do: :ets.insert(@cache, {key, result})

    {waiters, inflight} = Map.pop(state.inflight, key, [])
    Enum.each(waiters, &GenServer.reply(&1, result))

    send(self(), :warm_next)
    {:noreply, %{state | inflight: inflight}}
  end

  # A result for a dump that has since been unloaded or replaced.
  @impl true
  def handle_info({:fetched, _stale_gen, _key, _result}, state), do: {:noreply, state}

  @impl true
  def handle_info(:warm_next, %{status: :loaded, warm_queue: [key | rest]} = state) do
    state = %{state | warm_queue: rest}

    cond do
      :ets.member(@cache, key) ->
        send(self(), :warm_next)
        {:noreply, state}

      Map.has_key?(state.inflight, key) ->
        # Already being fetched for a user; its completion drives the queue on.
        {:noreply, state}

      true ->
        {:noreply, start_or_join(state, key, nil)}
    end
  end

  @impl true
  def handle_info(:warm_next, state), do: {:noreply, state}

  # ---- Fetch machinery ------------------------------------------------------

  # `from` is nil for background warming — nobody is waiting on the reply.
  defp start_or_join(state, key, from) do
    waiters = List.wrap(from)

    case state.inflight do
      %{^key => existing} ->
        put_in(state.inflight[key], existing ++ waiters)

      _ ->
        server = self()
        gen = state.gen
        Task.start(fn -> send(server, {:fetched, gen, key, compute(key)}) end)
        put_in(state.inflight[key], waiters)
    end
  end

  # Drop every cached answer and release anyone waiting on the old dump.
  defp reset(state, reason) do
    :ets.delete_all_objects(@cache)

    state.inflight
    |> Map.values()
    |> List.flatten()
    |> Enum.each(&GenServer.reply(&1, {:error, reason}))

    %{state | gen: state.gen + 1, inflight: %{}, warm_queue: []}
  end

  defp compute(:general_info),
    do: call_backend(:general_info, [], &Records.general_info_to_map/1)

  defp compute(:processes),
    do: call_backend_list(:processes, [], &Records.proc_to_map/1)

  defp compute(:ports),
    do: call_backend_list(:ports, [], &Records.port_to_map/1)

  defp compute(:ets_tables),
    do: call_backend_list(:ets_tables, [:all], &Records.ets_table_to_map/1)

  defp compute(:timers),
    do: call_backend_list(:timers, [:all], &Records.timer_to_map/1)

  defp compute(:nodes),
    do: call_backend_list(:dist_info, [], &Records.nod_to_map/1)

  defp compute(:loaded_mods),
    do: call_backend_list(:loaded_modules, [], &Records.loaded_mod_to_map/1)

  defp compute({:proc_info, pid_str}),
    do: call_backend(:proc_details, [String.to_charlist(pid_str)], &Records.proc_to_map/1)

  defp compute({:port_info, port_str}) do
    # get_ports stores ids as {X, Y} tuples; get_port looks up by "#Port<X.Y>" charlist
    port_id =
      case Regex.run(~r/^(\d+)\.(\d+)$/, port_str) do
        [_, a, b] -> String.to_charlist("#Port<#{a}.#{b}>")
        _ -> String.to_charlist(port_str)
      end

    call_backend(:port, [port_id], &Records.port_to_map/1)
  end

  defp compute(:memory) do
    try do
      case :crashdump_viewer.memory() do
        {:ok, list, _tw} when is_list(list) -> {:ok, Map.new(list)}
        {:ok, list} when is_list(list) -> {:ok, Map.new(list)}
        {:error, reason} -> {:error, to_string(reason)}
      end
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end

  # ---- Helpers --------------------------------------------------------------

  defp ensure_backend_started do
    case :crashdump_viewer.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  defp stop_backend do
    try do
      :crashdump_viewer.stop()
    catch
      _, _ -> :ok
    end
  end

  defp cleanup_owned(%{owned?: true, path: path}) when is_binary(path), do: File.rm(path)
  defp cleanup_owned(_state), do: :ok

  defp call_backend(fn_name, args, converter) do
    try do
      case apply(:crashdump_viewer, fn_name, args) do
        {:ok, record, _warnings} -> {:ok, converter.(record)}
        {:ok, record} -> {:ok, converter.(record)}
        {:error, reason} -> {:error, to_string(reason)}
      end
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end

  defp call_backend_list(fn_name, args, converter) do
    try do
      case apply(:crashdump_viewer, fn_name, args) do
        {:ok, list, _warnings} when is_list(list) -> {:ok, Enum.map(list, converter)}
        {:ok, {list, _tw}, _warnings} when is_list(list) -> {:ok, Enum.map(list, converter)}
        {:ok, list} when is_list(list) -> {:ok, Enum.map(list, converter)}
        {:error, reason} -> {:error, to_string(reason)}
      end
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end
end
