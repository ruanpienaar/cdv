defmodule Cdv.Records do
  @moduledoc """
  Erlang record definitions extracted from OTP's `observer/src/crashdump_viewer.hrl`.
  These records are what `crashdump_viewer` returns from its API functions.
  """

  require Record

  for {name, fields} <- Record.extract_all(from_lib: "observer/src/crashdump_viewer.hrl") do
    Record.defrecord(name, fields)
  end

  def to_map(record) when is_tuple(record) and tuple_size(record) > 0 do
    case elem(record, 0) do
      :general_info -> general_info_to_map(record)
      :proc         -> proc_to_map(record)
      :port         -> port_to_map(record)
      :ets_table    -> ets_table_to_map(record)
      :timer        -> timer_to_map(record)
      :loaded_mod   -> loaded_mod_to_map(record)
      :sched        -> sched_to_map(record)
      :fu           -> fu_to_map(record)
      :nod          -> nod_to_map(record)
      :hash_table   -> hash_table_to_map(record)
      :index_table  -> index_table_to_map(record)
      _             -> record
    end
  end

  def to_map(value), do: value

  def general_info_to_map(r), do: %{
    created:      general_info(r, :created),
    slogan:       general_info(r, :slogan),
    system_vsn:   general_info(r, :system_vsn),
    compile_time: general_info(r, :compile_time),
    taints:       general_info(r, :taints),
    node_name:    general_info(r, :node_name),
    num_atoms:    general_info(r, :num_atoms),
    num_procs:    general_info(r, :num_procs),
    num_ets:      general_info(r, :num_ets),
    num_timers:   general_info(r, :num_timers),
    num_fun:      general_info(r, :num_fun),
    mem_tot:      general_info(r, :mem_tot),
    mem_max:      general_info(r, :mem_max),
    instr_info:   general_info(r, :instr_info),
    thread:       general_info(r, :thread),
  }

  def proc_to_map(r), do: %{
    pid:                  proc(r, :pid),
    name:                 proc(r, :name),
    init_func:            proc(r, :init_func),
    parent:               proc(r, :parent),
    start_time:           proc(r, :start_time),
    state:                proc(r, :state),
    current_func:         proc(r, :current_func),
    msg_q_len:            proc(r, :msg_q_len),
    msg_q:                proc(r, :msg_q),
    last_calls:           proc(r, :last_calls),
    links:                proc(r, :links),
    monitors:             proc(r, :monitors),
    mon_by:               proc(r, :mon_by),
    arity:                proc(r, :arity),
    dict:                 proc(r, :dict),
    reductions:           proc(r, :reds),
    stack_heap:           proc(r, :stack_heap),
    old_heap:             proc(r, :old_heap),
    heap_unused:          proc(r, :heap_unused),
    old_heap_unused:      proc(r, :old_heap_unused),
    bin_vheap:            proc(r, :bin_vheap),
    old_bin_vheap:        proc(r, :old_bin_vheap),
    bin_vheap_unused:     proc(r, :bin_vheap_unused),
    old_bin_vheap_unused: proc(r, :old_bin_vheap_unused),
    memory:               proc(r, :memory),
    stack_dump:           proc(r, :stack_dump),
    run_queue:            proc(r, :run_queue),
    int_state:            proc(r, :int_state),
  }

  def port_to_map(r), do: %{
    id:        port(r, :id),
    state:     port(r, :state),
    slot:      port(r, :slot),
    connected: port(r, :connected),
    links:     port(r, :links),
    name:      port(r, :name),
    monitors:  port(r, :monitors),
    suspended: port(r, :suspended),
    controls:  port(r, :controls),
    input:     port(r, :input),
    output:    port(r, :output),
    queue:     port(r, :queue),
    port_data: port(r, :port_data),
  }

  def ets_table_to_map(r), do: %{
    pid:       ets_table(r, :pid),
    slot:      ets_table(r, :slot),
    id:        ets_table(r, :id),
    name:      ets_table(r, :name),
    is_named:  ets_table(r, :is_named),
    data_type: ets_table(r, :data_type),
    buckets:   ets_table(r, :buckets),
    size:      ets_table(r, :size),
    memory:    ets_table(r, :memory),
    details:   ets_table(r, :details),
  }

  def timer_to_map(r), do: %{
    pid:  timer(r, :pid),
    name: timer(r, :name),
    msg:  timer(r, :msg),
    time: timer(r, :time),
  }

  def loaded_mod_to_map(r), do: %{
    mod:               loaded_mod(r, :mod),
    current_size:      loaded_mod(r, :current_size),
    old_size:          loaded_mod(r, :old_size),
    current_attrib:    loaded_mod(r, :current_attrib),
    current_comp_info: loaded_mod(r, :current_comp_info),
    old_attrib:        loaded_mod(r, :old_attrib),
    old_comp_info:     loaded_mod(r, :old_comp_info),
  }

  def sched_to_map(r), do: %{
    name:    sched(r, :name),
    type:    sched(r, :type),
    process: sched(r, :process),
    port:    sched(r, :port),
    run_q:   sched(r, :run_q),
    port_q:  sched(r, :port_q),
    details: sched(r, :details),
  }

  def fu_to_map(r), do: %{
    module:         fu(r, :module),
    uniq:           fu(r, :uniq),
    index:          fu(r, :index),
    address:        fu(r, :address),
    native_address: fu(r, :native_address),
    refc:           fu(r, :refc),
  }

  def nod_to_map(r), do: %{
    name:          nod(r, :name),
    channel:       nod(r, :channel),
    conn_type:     nod(r, :conn_type),
    controller:    nod(r, :controller),
    creation:      nod(r, :creation),
    remote_links:  nod(r, :remote_links),
    remote_mon:    nod(r, :remote_mon),
    remote_mon_by: nod(r, :remote_mon_by),
    error:         nod(r, :error),
  }

  def hash_table_to_map(r), do: %{
    name:  hash_table(r, :name),
    size:  hash_table(r, :size),
    used:  hash_table(r, :used),
    objs:  hash_table(r, :objs),
    depth: hash_table(r, :depth),
  }

  def index_table_to_map(r), do: %{
    name:    index_table(r, :name),
    size:    index_table(r, :size),
    limit:   index_table(r, :limit),
    used:    index_table(r, :used),
    rate:    index_table(r, :rate),
    entries: index_table(r, :entries),
  }
end
