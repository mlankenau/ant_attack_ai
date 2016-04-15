require 'rubygems'
require 'websocket-client-simple'
require 'json'


class Client
  LOBBY = "games:lobby"

  def initialize
    puts "init"
    @ws = WebSocket::Client::Simple.connect('ws://localhost:4000/socket/websocket')
    puts "got ws #{@ws}"
    me = self
    @ws.on :message do |msg|
      begin
        msg = JSON.parse(msg.data)
        event = msg['event']
        payload = msg['payload']
        if event == 'players_update'
          me.on_player_update(payload)
        elsif event == 'challenge'
          if payload['to'] == me.name
            me.on_challenge(payload['from'])
          else
            puts msg
          end
        elsif event == 'enter_game'
          if payload['name'] == me.name
            me.on_enter_game(payload)
          end
        else
          puts "unknown event #{msg['event']}"
        end
      rescue => e
        puts "#{e.message}, #{e.backtrace}"
      end
    end

    @ws.on :open do
      puts "open event"
    end

    @ws.on :close do |e|
      p e
      exit 1
    end

    @ws.on :error do |e|
      p e
    end
  end

  def name
    "AI Player"
  end

  def login
    puts "login open: #{@connected}"
    ws_send(LOBBY, 'phx_join', {name: name})
  end

  def ws_send(topic, event, payload)
    msg = {topic: topic, event: event, payload: payload, ref: next_ref.to_s}
    @ws.send(msg.to_json)
  end

  def on_challenge(from)
    puts "received challenge from #{from}"
    ws_send(LOBBY, 'accept_challenge', from: from, to: name)
  end

  def on_player_update(payload)
    puts "got player update #{payload['players']}"
  end

  def on_enter_game(payload)
    @map = payload['map']
    puts "enter game: #{payload}"
    ws_send(LOBBY, 'phx_leave', {})
    ws_send("game:#{@map['game_pid']}", 'phx_join', {player_num: @map['player_num']})
  end

  def wait_for_challenge
    loop do
      sleep 1
      ws_send(LOBBY, 'lobby_alive', {from: name})
    end
  end

  def main_loop
    loop do
      if @ws.open?
        login
        sleep 1
        game_active = true
        wait_for_challenge
      else
        sleep 1
        p "waiting for connection"
      end
    end
  end

  private

  def next_ref
    @next_ref ||= 0
    @next_ref += 1
  end

end

client = Client.new
client.main_loop
