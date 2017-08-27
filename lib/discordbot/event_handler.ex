defmodule DiscordBot.EventHandlers do
    use Nostrum.Consumer
    alias Nostrum.Api

    def start_link do
        Consumer.start_link(__MODULE__, :ok)
    end

    def handle_event({:READY, _, _w_state}, state) do
        dt = DateTime.utc_now
        IO.puts("Bot ready at #{dt.month}/#{dt.day}/#{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second}")
        {:ok, state}
    end

    def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}, state) do

       if !is_bot?(msg.author) do
            # Let's log the messages into our cache if the server exists inside of the list
            case Api.get_guild(Api.get_channel!(msg.channel_id)["guild_id"]) do
                {:ok, guild} ->
                    json = ~s({"user": {"name": "#{msg.author.username}", "id": #{msg.author.id}, "discriminator": #{msg.author.discriminator}, "avatar": "#{msg.author.avatar}"}, "channel_id": #{msg.channel_id}, "guild_id": #{guild.id}, "content": "#{msg.content}"})
                    Redix.command(:redix, ["SETEX", "logger:#{msg.channel_id}:#{msg.id}", 1209600, json])
                {:error, _err} -> 
                    IO.puts "Error getting guild"
            end
        end
        
        {:ok, state}
    end

    def handle_event({:MESSAGE_DELETE, {msg}, _ws_state}, state) do
        id = msg.id
        channel_id = msg.channel_id

        redix_query = "logger:#{channel_id}:#{id}"

        {:ok, data} = Redix.command(:redix, ["GET", redix_query])

        if data != nil do # we found a message
            # Let's delete it from the cache 
            {:ok, am} = Redix.command(:redix, ["DEL", redix_query])

            # TODO: Remove this in prod
            if am >= 1 do
                IO.puts "Successfully deleted key."
            else
                IO.puts "Failed to delete key."
            end

            json = Poison.decode!(data)

            if json != nil do
                # Make server based for channel
                DiscordBot.Logger.send_log(299653045699084289, json["user"], "**Message sent by <@!#{json["user"]["id"]}> deleted in <##{json["channel_id"]}>**\n#{json["content"]}", 0xcc1717)
            end
            
        else
            IO.puts "Data was nil"
        end

        {:ok, state}
    end

    # To stop crashes and such.. 
    def handle_event(_, state) do
        {:ok, state}
    end

    def is_bot?(user) do
        Map.has_key?(user, :bot)
    end
end