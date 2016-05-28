require 'rubygems'
require 'websocket-client-simple'
require './deep_struct'
require './channel'
require 'json'
require './base_client'

class Client < BaseClient
  def initialize(name, password)
    super(name, password)
  end

  def play
    neutrals = planets.select { |p| p.player != player_num }
    my = planets.select { |p| p.player == player_num}

    if my.count > 0
      #puts "shooting something"
      my.shuffle.first(2).each do |src|
        sorted = neutrals.sort { |x, y| src.distance(x) <=> src.distance(y) }
        t = sorted.first
        print "."
        shoot(src.idx, t.idx) if t
      end
    end
  end
end

client = Client.new("ai_test", "blabla")
client.main_loop
