defmodule DiscordBot.Logger do
    alias Nostrum.Api

    # Add server support
    def send_log(channel_id, user_json, message, color) do
        Api.create_message!(channel_id, [content: "", embed: %{
            description: message,
            author: %{
                name: "#{user_json["name"]}##{user_json["discriminator"]}",
                icon_url: avatar_url(user_json["id"], user_json["avatar"]),
            },
            footer: %{
                text: "ID: #{user_json["id"]}",
            },
            color: color
        }], false)
    end

    def send_guild_log(channel_id, guild, message, color) do
        Api.create_message!(channel_id, [content: "", embed: %{
            description: message,
            author: %{
                name: "#{guild.name}",
                icon_url: server_url(guild.id, guild.icon), # guild.icon is nil for some odd reason..
            },
            footer: %{
                text: "ID: #{guild.id}",
            },
            color: color
        }], false)
    end

    # Helper function since nostrum doesnt have it
    defp avatar_url(user_id, avatar_id) do
        format = case String.starts_with?(avatar_id, "a_") do
            true ->
                "gif"
            false ->
                "webp"
        end

        "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar_id}.#{format}"
    end

    defp server_url(server_id, icon_id) do
        "https://cdn.discordapp.com/icons/#{server_id}/#{icon_id}.webp"   
    end

end