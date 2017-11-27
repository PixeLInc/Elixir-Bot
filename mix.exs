defmodule DiscordBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discord_bot,
      version: "0.1.0",
      elixir: "~> 1.5",
      build_embeded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DiscordBot, []},
      extra_applications: [:redis_connection_pool]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
        #{:nostrum, "~> 0.1"},
        {:nostrum, git: "https://github.com/PixeLInc/nostrum.git", branch: "master"},
        {:gun, git: "https://github.com/ninenines/gun.git", override: true},
        {:redis_connection_pool, "~> 0.1.5"},
        {:ex2ms, "~> 1.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
