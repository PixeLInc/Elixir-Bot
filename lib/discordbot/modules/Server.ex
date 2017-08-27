defmodule DiscordBot.Server do
    defmodule ServerData do
        @derive [Poison.Encoder]
        defstruct [
            :name,
            :id,
            :log_channel,
            :log_join,
            :log_leave,
            :log_bans,
            :auto_role,
            :cache_messages,
            :join_message,
            :leave_message,
            :ban_message,
            :leave_on_master,
        ]
    end

    # Load all servers into file and keep it global
    def load_servers do
        servers = Path.wildcard("servers/*.json")
        serv_list = servers |>
            Enum.map(fn server ->
                IO.puts "Loading #{server}..."
                contents = File.read! server
                Poison.decode!(contents, as: %ServerData{})
            end)

        serv_list
    end
end