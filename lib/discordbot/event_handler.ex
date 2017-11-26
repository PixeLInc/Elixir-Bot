defmodule DiscordBot.EventHandlers do
    use Nostrum.Consumer
    alias Nostrum.Api
    alias RedisPool, as: Redis

    # Color constants for ease
    @informative 0x00aeff # Blueish
    @bad 0xff0000 # Red
    @good 0x17ff00 # Green

    def start_link do
        DiscordBot.Server.load_servers()

        Consumer.start_link(__MODULE__, :ok)
    end

    def handle_event({:READY, _, _w_state}, state) do
        dt = DateTime.utc_now
        Api.update_status(:online, "Loggin' the logs")
        IO.puts("Bot ready at #{dt.month}/#{dt.day}/#{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second}")
        {:ok, state}
    end

    def handle_event({:GUILD_ROLE_CREATE, {gid, _role}, _ws_state}, state) do
        server = find_server(gid)

        guild = guild_or_get(gid)

        if guild != nil && server != nil do
            if server.log_channel != nil do
                DiscordBot.Logger.send_log(server.log_channel, guild, "**A new role has been created**", @informative)
            end
        end


        {:ok, state}
    end

    def handle_event({:GUILD_ROLE_DELETE, {gid, role}, _ws_state}, state) do
        server = find_server(gid)
        guild = guild_or_get(gid)

        if guild != nil && server != nil do
            if server.log_channel != nil do
                message = "**A role has been deleted**"
                message = if role.name != nil do
                    "**The role '#{role.name}' has been deleted**"
                end

                DiscordBot.Logger.send_log(server.log_channel, guild, message, @informative)
            end
        end

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

        DiscordBot.Server.create_server_profile(guild)

        {:ok, state}
    end

    def handle_event({:GUILD_BAN_ADD, {id, data}, _ws_state}, state) do
        server = find_server(id)

        if server != nil do
            if server.log_channel != nil && server.log_bans do
                DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been banned!**", @bad)
            end
        end

        {:ok, state}
    end

    def handle_event({:GUILD_BAN_REMOVE, {id, data}, _ws_state}, state) do
        server = find_server(id)

        if server != nil do
            if server.log_channel != nil && server.log_bans do
                DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been unbanned!**", @good)
            end
        end

        {:ok, state}
    end

    def handle_event({:GUILD_MEMBER_ADD, {gid, member}, _ws_state}, state) do
        server = find_server(gid)

      if server != nil do
            if server.auto_role != nil do
                Api.add_guild_member_role(gid, member.user.id, server.auto_role)
            end

            if server.log_channel != nil && server.log_join do
              # TODO: Figure out default channel and send them a nice toasty welcome message set by the server owner
              DiscordBot.Logger.send_log(server.log_channel, create_user_json(member.user), "**User has joined the server**", @good)
            end
        end
        {:ok, state}
    end

    def handle_event({:GUILD_MEMBER_REMOVE, {gid, member}, _ws_state}, state) do
        server = find_server(gid)

        if server != nil do
            if server.log_channel != nil && server.log_leave do
                #TODO: Default channel, send leave message.
                DiscordBot.Logger.send_log(server.log_channel, create_user_json(member.user), "**User has left the server**", @bad)
            end
        end

        {:ok, state}
    end

    def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}, state) do
       if !is_bot?(msg.author) do
            # Let's log the messages into our cache if the server exists inside of the list
            channel = channel_or_get(msg.channel_id)
            if channel != nil && Map.has_key?(channel, :guild_id) do
                guild = guild_or_get(channel.guild_id)

                if guild != nil do
                    IO.puts "(#{guild.name}<#{channel.name}>) #{msg.author.username}: #{msg.content}"

                    msg.attachments |> Enum.each(fn attach ->
                                         IO.puts "Attachments: #{attach.filename} | #{attach.url}"
                                       end)

                    # Let's parse the command if there is one and such.
                    spawn fn ->
                        # I mean, since we're here.. throw in the guild and channel lol
                        Commands.command_parser({msg, channel, guild}, state)
                    end

                    server = find_server(guild.id)

                    if server != nil do
                        if server.cache_messages do
                            json = ~s({"user": {"name": "#{msg.author.username}", "id": #{msg.author.id}, "discriminator": "#{msg.author.discriminator}", "avatar": "#{msg.author.avatar}"}, "channel_id": #{msg.channel_id}, "guild_id": #{guild.id}, "content": "#{msg.content}"})
                            Redis.query( ["SETEX", "logger:#{msg.channel_id}:#{msg.id}", 1209600, json])
                        end
                    end
                end
            end
        end

        {:ok, state}
    end

    def handle_event({:MESSAGE_UPDATE, {updated_message}, _ws_state}, state) do # smh why cant you store the channel and guild in message :(
        channel_id = updated_message.channel_id

        # might as well grab the channel and guild while im up here
        channel = channel_or_get(channel_id)

        if channel != nil && Map.has_key?(channel, :guild_id) do
            guild = guild_or_get(channel.guild_id)
            server = find_server(guild.id)
            if guild != nil && server != nil do
                # We need to get the old message
                redix_query = "logger:#{channel_id}:#{updated_message.id}"

                {:ok, data} = Redis.query( ["GET", redix_query])

                if data != nil && data != :undefined do
                    # Now we need to store the old content and then update it
                    json = Poison.decode!(data)

                    if !Map.has_key?(updated_message, :author) do
                        IO.puts "ERROR: Invalid Author Caught: #{json}"
                    end

                    # Log Edit
                    DiscordBot.Logger.send_edit_log(server.log_channel, create_user_json(updated_message.author), "**Messaged edited in <##{channel_id}>**", json["content"], updated_message.content, @informative)

                    # now we have to just reset the ttl and stuff since you can't update :?
                    njson = ~s({"user": {"name": "#{json["user"]["name"]}", "id": #{json["user"]["id"]}, "discriminator": "#{json["user"]["discriminator"]}", "avatar": "#{json["user"]["avatar"]}"}, "channel_id": #{json["channel_id"]}, "guild_id": #{json["guild_id"]}, "content": "#{updated_message.content}"})

                    Redis.query( ["SETEX", "logger:#{channel_id}:#{updated_message.id}", 1209600, njson])
                end

            end
        end

        {:ok, state}
    end

    def handle_event({:MESSAGE_DELETE, {msg}, _ws_state}, state) do
        id = msg.id
        channel_id = msg.channel_id

        redix_query = "logger:#{channel_id}:#{id}"

        {:ok, data} = Redis.query( ["GET", redix_query])

        if data != nil && data != :undefined do # we found a message
            # Let's delete it from the cache
            Redis.query( ["DEL", redix_query])

            try do
                json = Poison.decode!(data)

                if json != nil do
                    server = find_server(json["guild_id"])

                    if server != nil && server.log_channel != nil do
                        DiscordBot.Logger.send_log(server.log_channel, json["user"], "**Message sent by <@!#{json["user"]["id"]}> deleted in <##{channel_id}>**\n#{json["content"]}", @informative)
                    end
                end
            rescue
                _e in Poison.SyntaxError -> IO.puts "Error parsing JSON: #{data}"
            end
        else
            channel = channel_or_get(channel_id)
            if channel != nil && Map.has_key?(channel, :guild_id) do
                guild = guild_or_get(channel.guild_id)

                if guild != nil do
                    server = find_server(guild.id)

                    if server != nil && server.log_channel != nil do
                        DiscordBot.Logger.send_log(server.log_channel, guild, "**Unlogged message deleted in <##{channel_id}>**", @informative)
                    end
                end
            end
        end

        {:ok, state}
    end

    #TODO: Delete messages from database as well.. :?
    def handle_event({:MESSAGE_DELETE_BULK, {updated_messages}, _ws_state}, state) do
        # First we need to get the channel id from the map | %{channel_id, ids: [message_ids]}
        cid = updated_messages.channel_id
        channel = channel_or_get(cid)

        if channel != nil do
            guild = guild_or_get(channel.guild_id)
            if guild != nil do
                server = find_server(guild.id)
                if server != nil && server.log_channel != nil do
                    message_count = Enum.count(updated_messages)

                    DiscordBot.Logger.send_log(server.log_channel, guild, "**#{message_count} messages deleted in <##{cid}>**", @informative)
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

    def find_server(server_id) do
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

    defp channel_or_get(channel_id) do
        if channel_id != nil do
            channel = case Nostrum.Cache.ChannelCache.get(id: channel_id) do
                {:ok, chan} ->
                    chan
                {:error, _atom} ->
                    Api.get_channel!(channel_id)
            end

            channel
        end
    end

    defp guild_or_get(guild_id) do
        if guild_id != nil do
            guild = case Nostrum.Cache.Guild.GuildServer.get(id: guild_id) do
                {:ok, g} ->
                    g
                {:error, _reason} ->
                    Api.get_guild!(guild_id)
            end

            guild
        end
    end
end
