FROM elixir:1.5.2

RUN mkdir /opt/logger_bot
COPY . /opt/logger_bot
WORKDIR /opt/logger_bot

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get

CMD mix run --no-halt
