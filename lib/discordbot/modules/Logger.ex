defmodule DiscordBot.Logger do
    alias Nostrum.Api

    # Add server support
    def send_log(channel_id, user_json, message, color) do
        Api.create_message(channel_id, [content: "", embed: %{
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

end