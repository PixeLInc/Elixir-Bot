defmodule DiscordBot do
    use Application

    def start(_, _) do
        DiscordBot.Supervisor.start_link
    end
end