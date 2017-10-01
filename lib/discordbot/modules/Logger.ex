defmodule DiscordBot.Logger do
    alias Nostrum.Api

    # Add server support
    def send_log(channel_id, %Nostrum.Struct.Guild{} = guild, message, color) do
        if channel_id != nil do
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
    end

    def send_log(channel_id, user_json, message, color) do
        if channel_id != nil do # just in case.
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
    end

    def send_edit_log(channel_id, user_json, message, prev, cur, color) do
        if channel_id != nil do
            Api.create_message!(channel_id, [content: "", embed: %{
                description: message,
                author: %{
                    name: "#{user_json["name"]}##{user_json["discriminator"]}",
                    icon_url: avatar_url(user_json["id"], user_json["avatar"]),
                },
                footer: %{
                    text: "ID: #{user_json["id"]}",
                },
                color: color,
                fields: [
                    %{
                        name: "Before",
                        value: prev,
                    },
                    %{
                        name: "After",
                        value: cur,
                    },
                ]
            }], false)
        end
    end

    # Helper function since nostrum doesnt have it
    defp avatar_url(user_id, avatar_id) do
        if avatar_id != nil do
            format = case String.starts_with?(avatar_id, "a_") do
                  true ->
                    "gif"
                false ->
                    "webp"
            end

            "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar_id}.#{format}"
        else
            "https://cdn.browshot.com/static/images/not-found.png"
        end
    end

    defp server_url(server_id, icon_id) do
        if icon_id == nil do
            "https://biharcricketassociation.com/uploads/no_image.png"
        else
            "https://cdn.discordapp.com/icons/#{server_id}/#{icon_id}.webp"
        end
    end

end
