require 'rubygems'
require 'websocket-client-simple'
require 'json'
require 'ostruct'

class Planet < OpenStruct
  def distance(planet)
    Math.sqrt((planet.x - x)*(planet.x - x) + (planet.y - y)*(planet.y - y))
  end
end

class BaseClient
  LOBBY = "games:lobby"

  attr_accessor :player_num
  attr_accessor :planets

  def initialize
    @mode = :lobby

    puts "init"
    #@ws = WebSocket::Client::Simple.connect('ws://ant-attack.com/socket/websocket')
    @ws = WebSocket::Client::Simple.connect('ws://localhost:4000/socket/websocket')
    puts "got ws #{@ws}"
    me = self
    @ws.on :message do |msg|
      begin
        msg = JSON.parse(msg.data)
        event = msg['event']
        payload = msg['payload']
        me.send("on_#{event}".to_sym, payload)
      rescue NoMethodError => e
        puts "missing method: #{e}"
      rescue => e
        puts "#{e.class} #{e.message}, #{e.backtrace[0..100]}"
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
    ws_send(LOBBY, 'phx_join', {name: name})
  end

  def ws_send(topic, event, payload)
    msg = {topic: topic, event: event, payload: payload, ref: next_ref.to_s}
    @ws.send(msg.to_json)
  end

  def shoot(from, to)
    ws_send(@game_channel, 'shoot', {from: from, to: to})
  end

  def on_phx_reply(payload)
  end

  def on_challenge(payload)
    if payload['to'] == name
      ws_send(LOBBY, 'accept_challenge', from: payload['from'], to: name)
    end
  end

  def on_players_update(payload)
    @players = payload["players"]
    puts "players update #{payload}"
  end

  def on_enter_game(payload)
    if payload['name'] == name
      @map = payload['map']
      @planets = []
      @player_num = payload['player_num'].to_i
      @game_channel = "games:#{payload['game_pid']}"
      ws_send(LOBBY, 'phx_leave', {})
      ws_send(@game_channel, 'phx_join', {player_num: payload['player_num']})
      @mode = :transient
    end
  end

  def on_update_planets_score(payload)
    @planets = payload['planets'].map { |h| Planet.new(h)}
  end

  def on_heartbeat(payload)
    ws_send('phoenix', 'heartbeat', {})
  end

  def on_update_planets(payload)
    @planets = payload['planets'].map { |h| Planet.new(h)}
  end

  def on_game_over(payload)
    sleep 2
    ws_send(@game_channel, 'phx_leave', {})
    login
    @mode = :lobby
  end

  def on_send_ships(payload)
  end

  def wait_for_challenge
    @mode = :lobby
    while @mode == :lobby do
      sleep 1
      ws_send(LOBBY, 'lobby_alive', {from: name})

      @players.reject { |p| p == name }.shuffle.first.tap { |p|
        if p
          ws_send(LOBBY, 'challenge', from: name, to: p)
        end
      }
    end
  end

  def game_loop
    @mode = :game
    while @mode == :game do
      play if planets.size > 0
      sleep(1)
    end
  end

  def ask_to_challenge
    if @user_to_challenge.nil?
      puts 'Do you want to challenge a user? Enter the name or leave blank.'
      print '> '
      @user_to_challenge = gets.chomp
    end
    return false if @user_to_challenge.empty?
    puts "challenging #{@user_to_challenge}"
    @mode = :lobby
    while @mode == :lobby
      ws_send(LOBBY, 'challenge', from: name, to: @user_to_challenge)
      sleep 2
    end
    true
  end

  def main_loop
    loop do
      if @ws.open?
        login
        sleep 1
        game_active = true
        loop do
          wait_for_challenge
          game_loop
        end
      else
        sleep 1
      end
    end
  end

  private

  def next_ref
    @next_ref ||= 0
    @next_ref += 1
  end

end
