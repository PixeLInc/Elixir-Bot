defmodule DiscordBot.Supervisor do
    use Supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, :ok)
    end

    def init(:ok) do
        children = [
             worker(DiscordBot.EventHandlers, []),
             worker(DiscordBot.Scheduler, []),
             worker(Redix, [[], [name: :redix]]), # Global variable thx
        ]

        Process.flag(:trap_exit, true)
        supervise(children, strategy: :one_for_one)
    end

    def terminate(_reason, _state) do
        IO.puts("Exiting...")
        :ok
    end
end