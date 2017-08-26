defmodule DiscordBot.EventHandlers do
    use Nostrum.Consumer
    alias Nostrum.Api

    def start_link do
        Consumer.start_link(__MODULE__)
    end

    def handle_event({:READY, _, _w_state}, state) do
        dt = DateTime.utc_now
        IO.puts("Bot ready at #{dt.month}/#{dt.day}/#{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second}")
        {:ok, state}
    end


    # To stop crashes and such.. 
    def handle_event(_, state) do
        {:ok, state}
    end

end