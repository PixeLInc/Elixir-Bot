defmodule DiscordBot.EventHandlers do
    use Nostrum.Consumer
    alias Nostrum.Api

    def start_link do
        DiscordBot.Server.load_servers()

        Consumer.start_link(__MODULE__, :ok)
    end

    def handle_event({:READY, _, _w_state}, state) do
        dt = DateTime.utc_now
        # Api.update_status(:online, "Loggin' the logs")
        IO.puts("Bot ready at #{dt.month}/#{dt.day}/#{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second}")
        {:ok, state}
    end

    def handle_event({:GUILD_CREATE, {guild}, _ws_state}, state) do
        IO.puts "I joined a new guild named #{guild.name}!"

        owner_dm = case Api.create_dm(guild.owner_id) do
            {:ok, chan} ->
                chan
            {:error, _err} ->
                IO.puts "Could not get server owner from #{guild.name}"
            end

        if owner_dm != nil do
            Api.create_message(owner_dm.id, "Hey! I have just joined your server.\nI created a server profile for you, but currently it cannot be edited. Sorry! \nIf you have any questions, contact PixeL#7065 on Discord.")
        end

        {:ok, state}
    end

    def handle_event({:GUILD_BAN_ADD, {id, data}, _ws_state}, state) do
        server = find_server(id)

        if server != nil do
            if server.log_bans do 
                DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been banned!**", 0xff0000)
            end
        end

        {:ok, state}
    end

    def handle_event({:GUILD_BAN_REMOVE, {id, data}, _ws_state}, state) do
        server = find_server(id)

        if server != nil do
            if server.log_bans do
                DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been unbanned!**", 0x27ff00)
            end
        end

        {:ok, state}
    end

    def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}, state) do
       if !is_bot?(msg.author) do
            # Let's log the messages into our cache if the server exists inside of the list
            channel = Api.get_channel!(msg.channel_id)
            if channel != nil do
                case Api.get_guild(channel["guild_id"]) do
                    {:ok, guild} ->
                        IO.puts "(#{guild.name}<#{channel["name"]}>) #{msg.author.username}: #{msg.content}"
    
                        server = find_server(String.to_integer(guild.id))
    
                        if server != nil do
                            if server.cache_messages do
                                json = ~s({"user": {"name": "#{msg.author.username}", "id": #{msg.author.id}, "discriminator": #{msg.author.discriminator}, "avatar": "#{msg.author.avatar}"}, "channel_id": #{msg.channel_id}, "guild_id": #{guild.id}, "content": "#{msg.content}"})
                                Redix.command(:redix, ["SETEX", "logger:#{msg.channel_id}:#{msg.id}", 1209600, json])
                            end
                        end
    
                    {:error, _err} -> 
                        IO.puts "Error getting guild"
                end
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
            Redix.command(:redix, ["DEL", redix_query])

            json = Poison.decode!(data)

            if json != nil do
                server = find_server(json["guild_id"])

                if server != nil && server.log_channel != nil do
                    DiscordBot.Logger.send_log(server.log_channel, json["user"], "**Message sent by <@!#{json["user"]["id"]}> deleted in <##{channel_id}>**\n#{json["content"]}", 0xcc1717)
                end
            end
            
        else
            guild = case Api.get_guild(Api.get_channel!(channel_id)["guild_id"]) do
                {:ok, g} ->
                    g
                _ ->
                    nil
                end

            if guild != nil do
                server = find_server(String.to_integer(guild.id))

                if server != nil && server.log_channel != nil do
                    DiscordBot.Logger.send_guild_log(server.log_channel, guild, "**Unlogged message deleted in <##{channel_id}>**", 0xcc1717)
                end
            end
        end

        {:ok, state}
    end

    # To stop crashes and such.. 
    def handle_event(_, state) do
        {:ok, state}
    end

    defp is_bot?(user) do
        Map.has_key?(user, :bot)
    end

    defp find_server(server_id) do
        case :ets.lookup(:servers_map, server_id) do
            [{_id, data}] ->
                data
            [] -> 
                nil
        end
    end

    defp create_user_json(user) do
        %{
            "name" => user.username,
            "discriminator" => user.discriminator,
            "id" => user.id,
            "avatar" => user.avatar,
        }
    end
end