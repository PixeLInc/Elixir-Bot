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
                serv_data = Poison.decode!(contents, as: %ServerData{})

                IO.puts "Loaded #{serv_data.name}"

                :ets.insert(:servers_map, {serv_data.id, serv_data}) # Insert with id as key for fast lookups
            end)

        serv_list
    end

    def save_server(server_id, server_map) do
        File.write!("servers/#{server_id}.json", Poison.encode!(server_map), [:binary])
    end

    def create_server_profile(guild) do
        server_data = %ServerData {
            :name => guild.name,
            :id => guild.id,
            :log_channel => nil,
            :log_join => true,
            :log_leave => true,
            :log_bans => true,
            :auto_role => nil,
            :cache_messages => true,
            :join_message => "Welcome to the server, {user}!",
            :leave_message => "Oh noes, {user} left the server :(",
            :ban_message => "{user} just got the ban hammer!",
            :leave_on_master => false,
        }

        :ets.insert(:servers_map, {guild.id, server_data})

        case File.write("servers/#{guild.id}.json", Poison.encode!(server_data), [:binary]) do
            :ok -> 
                IO.puts "#{guild.id} saved successfully!"
            {:error, _posix} ->
                IO.puts "Failed to create server file"
        end
    end
end