defmodule Mix.Tasks.Cdv.Assets do
  @shortdoc "Copy Phoenix/LiveView JS from deps into priv/static/assets — run once after mix deps.get"
  use Mix.Task

  @out "priv/static/assets"
  @files [
    {"phoenix",           "priv/static/phoenix.min.js",      "phoenix.min.js"},
    {"phoenix_live_view", "priv/static/phoenix_live_view.js", "phoenix_live_view.js"},
  ]

  def run(_args) do
    File.mkdir_p!(@out)
    for {dep, src, dst_name} <- @files do
      src_path = Path.join([Mix.Project.deps_path(), dep, src])
      dst_path = Path.join(@out, dst_name)
      if File.exists?(src_path) do
        File.cp!(src_path, dst_path)
        Mix.shell().info("  Copied #{dep}/#{src} → #{dst_path}")
      else
        Mix.shell().error("  NOT FOUND: #{src_path}")
      end
    end
    Mix.shell().info("\nDone. Run: mix phx.server")
  end
end