defmodule DiscordBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discord_bot,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embeded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DiscordBot, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
        #{:nostrum, "~> 0.1"},
        {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
        {:gun, git: "https://github.com/ninenines/gun.git", override: true},
        {:quantum, ">= 2.0.2"},
        {:redix, ">= 0.0.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
