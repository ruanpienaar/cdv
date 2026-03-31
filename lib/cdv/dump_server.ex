defmodule Cdv.DumpServer do
  @moduledoc """
  Wraps the OTP `crashdump_viewer` backend GenServer.

  The `:crashdump_viewer` module is a pure backend — it parses the crash dump
  file and answers queries. `crashdump_viewer_wx` is the wx GUI normally layered
  on top. We bypass the GUI entirely and call the backend directly.
  """

  use GenServer
  alias Cdv.Records
  require Logger

  # ---- Public API -----------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def load(path) when is_binary(path) do
    GenServer.call(__MODULE__, {:load, path}, :infinity)
  end

  def unload do
    GenServer.call(__MODULE__, :unload)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def general_info do
    GenServer.call(__MODULE__, :general_info, 30_000)
  end

  def processes(opts \\ []) do
    GenServer.call(__MODULE__, {:processes, opts}, 60_000)
  end

  def proc_info(pid_str) do
    GenServer.call(__MODULE__, {:proc_info, pid_str}, 30_000)
  end

  def ports(opts \\ []) do
    GenServer.call(__MODULE__, {:ports, opts}, 30_000)
  end

  def port_info(port_str) do
    GenServer.call(__MODULE__, {:port_info, port_str}, 30_000)
  end

  def ets_tables(opts \\ []) do
    GenServer.call(__MODULE__, {:ets_tables, opts}, 30_000)
  end

  def timers(opts \\ []) do
    GenServer.call(__MODULE__, {:timers, opts}, 30_000)
  end

  def nodes do
    GenServer.call(__MODULE__, :nodes, 30_000)
  end

  def loaded_mods(opts \\ []) do
    GenServer.call(__MODULE__, {:loaded_mods, opts}, 30_000)
  end

  def memory do
    GenServer.call(__MODULE__, :memory, 30_000)
  end

  # ---- GenServer callbacks --------------------------------------------------

  @impl true
  def init(:ok) do
    {:ok, %{status: :idle, path: nil, filename: nil, truncated: false, error: nil}}
  end

  @impl true
  def handle_call({:load, path}, _from, state) do
    stop_backend()
    charpath = String.to_charlist(path)
    Logger.info("[CdvDumpServer] Loading: #{path}")

    with :ok <- ensure_backend_started() do
      :crashdump_viewer.read_file(charpath)
      # Any call after the cast is queued behind it — this blocks until loading is done
      case :crashdump_viewer.get_dump_versions() do
        {:ok, {_max, vsn}} when vsn != :undefined ->
          new_state = %{state | status: :loaded, path: path,
                                filename: Path.basename(path),
                                truncated: false, error: nil}
          {:reply, :ok, new_state}

        _ ->
          msg = "File is not a valid Erlang crash dump"
          Logger.error("[CdvDumpServer] #{msg}: #{path}")
          {:reply, {:error, msg}, %{state | status: :idle, error: msg}}
      end
    else
      {:error, reason} ->
        Logger.error("[CdvDumpServer] Failed to start backend: #{reason}")
        {:reply, {:error, reason}, %{state | status: :idle, error: reason}}
    end
  end

  @impl true
  def handle_call(:unload, _from, state) do
    stop_backend()
    {:reply, :ok, %{state | status: :idle, path: nil, filename: nil,
                             truncated: false, error: nil}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:status, :path, :filename, :truncated, :error]), state}
  end

  @impl true
  def handle_call(:general_info, from, state) do
    async_reply(from, fn -> call_backend(:general_info, [], &Records.general_info_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:processes, opts}, from, state) do
    sort_col = Keyword.get(opts, :sort, :memory)
    async_reply(from, fn ->
      case call_backend_list(:processes, [], &Records.proc_to_map/1) do
        {:ok, procs} -> {:ok, sort_procs(procs, sort_col)}
        err -> err
      end
    end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:proc_info, pid_str}, from, state) do
    async_reply(from, fn ->
      call_backend(:proc_details, [String.to_charlist(pid_str)], &Records.proc_to_map/1)
    end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:ports, _opts}, from, state) do
    async_reply(from, fn -> call_backend_list(:ports, [], &Records.port_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:port_info, port_str}, from, state) do
    async_reply(from, fn ->
      # get_ports stores ids as {X, Y} tuples; get_port looks up by "#Port<X.Y>" charlist
      port_id =
        case Regex.run(~r/^(\d+)\.(\d+)$/, port_str) do
          [_, a, b] -> String.to_charlist("#Port<#{a}.#{b}>")
          _         -> String.to_charlist(port_str)
        end
      call_backend(:port, [port_id], &Records.port_to_map/1)
    end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:ets_tables, _opts}, from, state) do
    async_reply(from, fn -> call_backend_list(:ets_tables, [:all], &Records.ets_table_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:timers, _opts}, from, state) do
    async_reply(from, fn -> call_backend_list(:timers, [:all], &Records.timer_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call(:nodes, from, state) do
    async_reply(from, fn -> call_backend_list(:dist_info, [], &Records.nod_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:loaded_mods, _opts}, from, state) do
    async_reply(from, fn -> call_backend_list(:loaded_modules, [], &Records.loaded_mod_to_map/1) end)
    {:noreply, state}
  end

  @impl true
  def handle_call(:memory, from, state) do
    async_reply(from, fn ->
      try do
        case :crashdump_viewer.memory() do
          {:ok, list, _tw} when is_list(list) -> {:ok, Map.new(list)}
          {:ok, list} when is_list(list)      -> {:ok, Map.new(list)}
          {:error, reason}                    -> {:error, to_string(reason)}
        end
      catch
        kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
      end
    end)
    {:noreply, state}
  end

  # ---- Helpers --------------------------------------------------------------

  defp sort_procs(procs, :memory),     do: Enum.sort_by(procs, &parse_mem(&1.memory), :desc)
  defp sort_procs(procs, :reductions), do: Enum.sort_by(procs, &(&1.reductions || 0), :desc)
  defp sort_procs(procs, :msg_q_len),  do: Enum.sort_by(procs, &(&1.msg_q_len || 0), :desc)
  defp sort_procs(procs, :pid),        do: Enum.sort_by(procs, &fmt_pid(&1.pid))
  defp sort_procs(procs, _),           do: procs

  defp fmt_pid(pid) when is_pid(pid),  do: pid |> :erlang.pid_to_list() |> List.to_string()
  defp fmt_pid(pid) when is_list(pid), do: List.to_string(pid)
  defp fmt_pid(pid), do: to_string(pid)

  defp parse_mem(n) when is_integer(n), do: n
  defp parse_mem(_), do: 0

  defp async_reply(from, fun) do
    Task.start(fn -> GenServer.reply(from, fun.()) end)
  end

  defp ensure_backend_started do
    case :crashdump_viewer.start_link() do
      {:ok, _}                        -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason}                -> {:error, to_string(reason)}
    end
  end

  defp stop_backend do
    try do
      :crashdump_viewer.stop()
    catch
      _, _ -> :ok
    end
  end

  defp call_backend(fn_name, args, converter) do
    try do
      case apply(:crashdump_viewer, fn_name, args) do
        {:ok, record, _warnings} -> {:ok, converter.(record)}
        {:ok, record}            -> {:ok, converter.(record)}
        {:error, reason}         -> {:error, to_string(reason)}
      end
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end

  defp call_backend_list(fn_name, args, converter) do
    try do
      case apply(:crashdump_viewer, fn_name, args) do
        {:ok, list, _warnings} when is_list(list)         -> {:ok, Enum.map(list, converter)}
        {:ok, {list, _tw}, _warnings} when is_list(list)  -> {:ok, Enum.map(list, converter)}
        {:ok, list} when is_list(list)                    -> {:ok, Enum.map(list, converter)}
        {:error, reason}                                  -> {:error, to_string(reason)}
      end
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end
end