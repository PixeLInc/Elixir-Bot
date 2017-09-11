# Elixir Logging Bot
**This bot is NOT ready to be used in production, it is still under active development**

> This bot uses [Nostrum](https://github.com/Kraigie/nostrum/) dev. 
Thanks to everyone inside of the #elixir_nostrum channel in Discord, helped me a lot!

## My current goals for this bot:

Logging Plans ->
- [x] Message Delete
- [x] Message Create
- [x] Message Update/Edit
- [x] Role Create
- [x] Role Delete
- [ ] Role Update
- [x] Guild Ban
- [x] Guild Unban
- [x] Guild User Join
- [x] Guild User Leave
- [x] This bot joining
- [ ] I can't think of anything rn :?

# Contributing
If you do want to contribute to this project, just modify/add/delete the code and then submit a pull request that I will review and either accept, request changes, or deny depending on the code.

# Running it yourself?
You probably shouldn't run it yourself..
but if you really want to run it yourself, you need to do a few things. (Please note that this bot isn't meant for other users, I only made this for myself)
1. You need to install Redis. Either google redis if you're on Linux, or go [here](https://github.com/MicrosoftArchive/redis/releases) if you're on Windows.
2. You will then need to setup a discord bot application, that can be done [here](https://discordapp.com/developers/applications/me)
3. Once you do that, you can either start the bot now and it **should** create a server profile once you invite it. Otherwise you can create one yourself. Follow [this guide](https://github.com/PixeLInc/Elixir-Bot/wiki/Setting-up-a-server-profile)
4. Once you have done all that, make sure you have Elixir 1.5.1 and Erlang OTP 20 installed.
5. Finally, use `mix run --no-halt` in the directory of the git clone, and it should start.. if not you can ask me I guess.

