require "colorize"
require "./net"
require "./game/*"

# Functionality for the game elements of the MUD.
module Mud::Game
  # The game world.
  #
  # The world contains all the game information including
  # areas, rooms, and entities.
  #
  # It uses a `Mud::Net::Server` to interact with players over
  # the Telnet protocol.
  #
  # Persistence is implemented by connecting to an SQLite3
  # database, which can be used for backups and saving state
  # on game end.
  class World
    getter server : Mud::Net::Server

    def initialize(@server)
      @players = {} of Mud::Net::ClientId => Player
      @areas = {} of String => Area
      @events = Deque(Event).new
    end

    # Creates a new world with the given *server*.
    def self.start(server, &)
      world = new(server)
      begin
        yield world
      ensure
        world.save
      end
    end

    # Runs the main event loop for the game.
    def run
      # Receive the latest client information
      @server.run do |messages, joiners, leavers|
        messages.each do |msg|
          if command = Command.parse(msg.id, msg.message, self)
            command.run
          end
        end

        joiners.each do |id|
          player = Player.stranger
          @players[id] = player
          @server.send(id, BANNER.colorize(:magenta))
          @server.send(id, INTRO)
          @server.broadcast("#{player.name} rode into town".colorize(:yellow),
            exclude = id)
        end

        leavers.each do |id|
          if player = @players[id]?
            @server.broadcast("#{player.name} rode off into the sunset".colorize(:yellow))
            @players.delete id
          end
        end
      end

      # Finally we can process game events
      ongoing = Deque(Event).new
      while event = @events.shift?
        if !event.finished?
          ongoing << event
        end
      end
      @events.concat ongoing
    end

    # TODO: documentation
    def save
    end
  end
end
