defmodule DiscordBot.EventHandlers do
    use Nostrum.TaskedConsumer
    alias Nostrum.Api
    alias RedisPool, as: Redis

    # Color constants for ease
    @informative 0x00aeff # Blueish
    @bad 0xff0000 # Red
    @good 0x17ff00 # Green

    def start_link do
        DiscordBot.Server.load_servers()

        TaskedConsumer.start_link(__MODULE__)
    end

    def handle_event({:READY, _, _w_state}) do
        dt = DateTime.utc_now
        Api.update_status(:online, "your every move..", 3)
        IO.puts("Bot ready at #{dt.month}/#{dt.day}/#{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second}")

        IO.puts "Logger Bot v1.3"
    end

    def handle_event({:GUILD_ROLE_CREATE, {gid, _role}, _ws_state}) do
      with {:ok, server} <- find_server(gid),
           guild = guild_or_get(gid)
      do
        if server.log_channel do
          DiscordBot.Logger.send_log(server.log_channel, guild, "**A new role has been created**", @informative)
        end
      end
    end

    def handle_event({:GUILD_ROLE_DELETE, {gid, role}, _ws_state}) do
      with {:ok, server} <- find_server(gid),
           guild = guild_or_get(gid)
      do
        if server.log_channel do
          message = if role.name != nil do
            "**The role '#{role.name}' has been deleted**"
          else
            "**A role has been deleted**"
          end

          DiscordBot.Logger.send_log(server.log_channel, guild, message, @informative)
        end
      end
    end

    def handle_event({:GUILD_CREATE, {guild}, _ws_state}) do
      IO.puts "I joined a new guild named #{guild.name}!"

      with {:ok, dm_channel} <- Api.create_dm(guild.owner_id)
      do
        IO.puts "Sending the owner of the new server a DM | #{dm_channel["id"]}"

        case Api.create_message(dm_channel["id"], "Hey! I just joined your server.\nI created a server profile for you which you can edit with %settings.\nIf you have any questions, contact PixeL#7065 on Discord.") do
          {:ok, msg} ->
            :ok
          {:error, error} ->
            IO.puts "Failed to send message to owner: #{inspect error}"
        end
      else
        {:error, _reason} ->
          IO.puts "Failed to get server owner from #{guild.name}"
      end

      # Piped just because I wanted to feel cool
      guild |> DiscordBot.Server.create_server_profile
    end

    def handle_event({:GUILD_BAN_ADD, {id, data}, _ws_state}) do
      with {:ok, server} <- find_server(id)
      do
        if server.log_channel && server.log_bans do
          DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been banned!**", @bad)
        end
      end
    end

    def handle_event({:GUILD_BAN_REMOVE, {id, data}, _ws_state}) do
      with {:ok, server} <- find_server(id)
      do
        if server.log_channel && server.log_bans do
          DiscordBot.Logger.send_log(server.log_channel, create_user_json(data.user), "**User has been unbanned!**", @good)
        end
      end
    end

    def handle_event({:GUILD_MEMBER_ADD, {gid, member}, _ws_state}) do
      with {:ok, server} <- find_server(gid)
      do
        if server.auto_role do
          Api.add_guild_member_role(gid, member.user.id, server.auto_role)
        end

        if server.log_channel && server.log_join do
          # TODO: Figure out default channel and send them a nice toasty welcome message set by the server owner
          DiscordBot.Logger.send_log(server.log_channel, create_user_json(member.user), "**User has joined the server**", @good)
        end
      end
    end

    def handle_event({:GUILD_MEMBER_REMOVE, {gid, member}, _ws_state}) do
      with {:ok, server} <- find_server(gid)
      do
        if server.log_channel && server.log_leave do
          #TODO: Default channel, send leave message.
          DiscordBot.Logger.send_log(server.log_channel, create_user_json(member.user), "**User has left the server**", @bad)
        end
      end
    end

    def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}) do
      if !is_bot?(msg.author) do
        # Let's log the messages into our cache if the server exists inside of the list
        with channel = channel_or_get(msg.channel_id),
             guild = guild_or_get(channel.guild_id),
             {:ok, server} <- find_server(guild.id)
        do
          IO.puts "(#{guild.name}<#{channel.name}>) #{msg.author.username}: #{msg.content}"

          msg.attachments |> Enum.each(fn attach ->
            IO.puts "Attachments: #{attach.filename} | #{attach.url}"
          end)

          # Let's parse this and throw in the args
          spawn fn ->
            Commands.command_parser({msg, channel, guild})
          end

          if server.cache_messages do
            json = ~s({"user": {"name": "#{msg.author.username}", "id": #{msg.author.id}, "discriminator": "#{msg.author.discriminator}", "avatar": "#{msg.author.avatar}"}, "channel_id": #{msg.channel_id}, "guild_id": #{guild.id}, "content": "#{msg.content}"})
            Redis.query( ["SETEX", "logger:#{msg.channel_id}:#{msg.id}", 1209600, json])
          end
        else
          :serverr -> # Server not found
            IO.puts "The bot is in a server without a profile! | cid: #{msg.channel_id}"
        end
      end
    end

    def handle_event({:MESSAGE_UPDATE, {updated_message}, _ws_state}) do # smh why cant you store the channel and guild in message :(
      channel_id = updated_message.channel_id

      with channel = channel_or_get(channel_id),
           guild = guild_or_get(channel.guild_id),
           {:ok, server} <- find_server(guild.id),
           {:ok, data} <- query_redis(["GET", "logger:#{channel_id}:#{updated_message.id}"]),
           json = Poison.decode!(data)
      do
        # Log Edit
        DiscordBot.Logger.send_edit_log(server.log_channel, create_user_json(updated_message.author), "**Messaged edited in <##{channel_id}>**", json["content"], updated_message.content, @informative)

        # now we have to just reset the ttl and stuff since you can't update :?
        njson = ~s({"user": {"name": "#{json["user"]["name"]}", "id": #{json["user"]["id"]}, "discriminator": "#{json["user"]["discriminator"]}", "avatar": "#{json["user"]["avatar"]}"}, "channel_id": #{json["channel_id"]}, "guild_id": #{json["guild_id"]}, "content": "#{updated_message.content}"})

        Redis.query( ["SETEX", "logger:#{channel_id}:#{updated_message.id}", 1209600, njson])
      end
    end

    def handle_event({:MESSAGE_DELETE, {msg}, _ws_state}) do
      id = msg.id
      channel_id = msg.channel_id

      redix_query = "logger:#{channel_id}:#{id}"

      with {:ok, data} <- query_redis(["GET", redix_query] ),
           Redis.query( ["DEL", redix_query] ),
           json = Poison.decode!(data),
           {:ok, server} <- find_server(json["guild_id"])
      do
        if server.log_channel do
          DiscordBot.Logger.send_log(server.log_channel, json["user"], "**Message sent by <@!#{json["user"]["id"]}> deleted in <##{channel_id}>**\n#{json["content"]}", @informative)
        end
      else
        nil ->
          with channel = channel_or_get(channel_id),
               guild = guild_or_get(channel.guild_id),
               {:ok, server} <- find_server(guild.id)
          do
            if server.log_channel do
              DiscordBot.Logger.send_log(server.log_channel, guild, "**Unlogged message deleted in <##{channel_id}>**", @informative)
            end
          end
      end
    end

    def handle_event({:MESSAGE_DELETE_BULK, {updated_messages}, _ws_state}) do
      # %{channel_id, ids: [message_ids]}

      with channel = channel_or_get(updated_messages.channel_id),
           guild = guild_or_get(channel.guild_id),
           {:ok, server} <- find_server(guild.id)
      do
        if server.log_channel do
          message_count = updated_messages[:ids] |> Enum.count

          # We need to delete them from the database as they aren't there anymore obv
          updated_messages[:ids] |> Enum.each(fn id ->
            Redis.query( ["DEL", "logger:#{updated_messages.channel_id}:#{id}"])
          end)

          DiscordBot.Logger.send_log(server.log_channel, guild, "**#{message_count} messages deleted in <##{updated_messages.channel_id}>**", @informative)
        end
      end
    end

    # To stop crashes and such..
    def handle_event(_) do
      :noop
    end

    defp is_bot?(user) do
      Map.has_key?(user, :bot)
    end

    def find_server(server_id) do
      case :ets.lookup(:servers_map, server_id) do
          [{_id, data}] ->
            {:ok, data}
          [] ->
            :serverr
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

    defp query_redis(query) do
      case Redis.query(query) do
        {:ok, data} ->
          if data == :undefined do
            nil
          else
            {:ok, data}
          end
        _ ->
          nil
      end
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
