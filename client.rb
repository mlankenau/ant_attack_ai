require 'rubygems'
require 'websocket-client-simple'
require 'json'
require './base_client'

class Client < BaseClient
  LOBBY = "games:lobby"

  def name
    'AI Player'
  end

  def play
    neutrals = planets.select { |p| p.player != player_num }
    my = planets.select { |p| p.player == player_num}

    my.each do |src|
      sorted = neutrals.sort { |x, y| src.distance(x) <=> src.distance(y) }
      shoot(src.idx, sorted.first.idx)
    end
  end
end

client = Client.new
client.main_loop
