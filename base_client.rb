require 'rubygems'
require 'websocket-client-simple'
require 'json'

class Planet < OpenStruct
  def distance(planet)
    Math.sqrt((planet.x - x)*(planet.x - x) + (planet.y - y)*(planet.y - y))
  end
end

class BaseClient
  attr_accessor :planets
  attr_accessor :player_num

  def initialize(username, password)
    @username = username
    @password = password
    @ws = WebSocket::Client::Simple.connect('ws://ant-attack.com/socket/websocket')
  end

  def shoot(from, to)
    @game_channel.send('shoot', {from: from, to: to})
  end

  def play
  end

  def enter_game(game_info)
    @player_num = game_info.player_num
    @planets = game_info.map.planets.map { |h| Planet.new(h)}
    Thread.new do
      loop do
        puts "invoking play"
        sleep 1
        begin
          play
        rescue => e
          puts e
        end
      end
    end
    Channel.connect(@ws, "games:#{game_info.game_pid}", {player_num: game_info.player_num}) do |c|
      @game_channel = c
      c.on_update_planets_score do |payload|
        @planets = payload.planets.map { |h| Planet.new(h)}
      end
      c.on_update_planets do |payload|
        @planets = payload.planets.map { |h| Planet.new(h)}
      end
    end
  end

  def enter_lobby(token)
    Channel.connect(@ws, 'lobby', {token: token}) do |c|
      c.on_challenge do |payload|
        if payload.to == @username
          c.send("accept_challenge", {from: payload.from, to: payload.to, id: payload.id})
        end
      end
      c.on_enter_game do |payload|
        if payload.name == @username
          enter_game(payload)
        end
      end
      c.on_players_update do |_|
      end
    end
  end

  def login()
    Channel.connect(@ws, 'login', {name: @username, password: @password}) do |c|
      c.on_phx_reply do |payload|
        puts "payload: #{payload}"
        token = payload.response.token
        enter_lobby(token)
      end
    end
  end

  def main_loop
    while !@ws.open? do
     sleep 1
    end
    login
    sleep 1000000
  end
end

