defmodule Commands do
    alias Nostrum.Api
    # DiscordEX command handling, basically.
    
    def command_from_message(message, prefix) do
        content = message.content
        if String.starts_with?(content, prefix) do
            tmp = _take_prefix(content, prefix)
            [cmd|tail] = String.split(tmp, ~r/\s/u, parts: 2)
            msg = List.first(tail)
            case msg do
                nil ->
                    {cmd, {}}
                m ->
                    {cmd, List.to_tuple(String.split(m, " "))}# I wanted a fucking args array.. >:( 
            end
        else
            {nil, content}
        end
    end

    def command_parser({message, channel, guild}, state) do
        # Shouldnt be from a bot since we do that via :MESSAGE_CREATE
        case command_from_message(message, "%") do
            {nil, content} ->
                nil # Dont do anything since it's not a command
            {cmd, msg} ->
                _execute_command({cmd, msg, channel, guild}, message, state)
        end
    end

    # Insert all the commands here

    # Allow server owners, and me to modify their server layout
    defp _execute_command({"settings", args, channel, guild}, message, _state) do
        if owner_check?(guild, message.author) do #it's either me or the owner running it
            # Let's make sure they even have a server profile..
            server = DiscordBot.EventHandlers.find_server(guild.id)
            if server != nil do
                args_length = tuple_size(args)
                if args_length >= 3 do
                    if String.downcase(elem(args, 0)) == "m" do
                        to_modify = String.to_atom(elem(args, 1)) # The thing they want to modify in the settings.
                        # TODO: Support people to set custom leave and join messages.. | Too lazy atm
                        new_value = convert_to_type(elem(args, 2))

                        if Map.has_key?(server, to_modify) do
                            try do # rescue from an invalid thingy
                                nserver = Map.put(server, to_modify, new_value)
                                :ets.insert(:servers_map, {guild.id, nserver})

                                DiscordBot.Server.save_server(guild.id, nserver)

                                Api.create_message!(channel.id, "Successfully set #{to_modify} to #{new_value}!")
                            catch
                                :exit, _ -> Api.create_message!(channel.id, "Hmm.. that doesn't seem right. Wrong setting name, or invalid value specified")
                            end
                        else
                            Api.create_message!(channel.id, "That setting does not exist.")
                        end
                    end
                else # Print out the current server settings | TODO: Do this more dynamically.
                    Api.create_message!(channel.id,  # too lazy to figure out whitespace /shrug
                    "Server Settings:
                    ```
name: #{server.name}
id: #{server.id}
log_channel: #{server.log_channel}
log_join: #{server.log_join}
log_leave: #{server.log_leave}
log_bans: #{server.log_bans}
auto_role: #{server.auto_role}
cache_messages: #{server.cache_messages}
join_message: #{server.join_message}
leave_message: #{server.leave_message}
ban_message: #{server.ban_message}
```")
                end
            end
        end
    end

    # Default Handler for Invalid Commands
    defp _execute_command({cmd, _args, _channel, _guild}, _payload, _state) do
        # Fail silently
        # IO.puts "User entered invalid command '#{cmd}'"
    end


    # Supposedly fast
    defp _take_prefix(full, prefix) do
        base = byte_size(prefix)
        <<_::binary-size(base), rest::binary>> = full
        rest
    end

    # Helper functions

    defp convert_to_type(value) do
        value = String.downcase(value)
        case Regex.run(~r{^[0-9]*$}, value) do
            nil ->
                if value == "true" || value == "false" do
                    String.to_existing_atom(value)
                else
                    value
                end
            num ->
                elem(Integer.parse(List.first(num)), 0)
        end
    end

    # Me, or the owner /shrug
    defp owner_check?(guild, sender) do
        (guild.owner_id == sender.id || sender.id == 117789813427535878) 
    end

end