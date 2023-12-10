require "colorize"
require "db"
require "sqlite3"
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
    property players : Hash(String, Player)
    property areas : Hash(String, Area)
    property online
    getter server : Mud::Net::Server

    def initialize(@server, @admin : String)
      @db = "WesternMud"
      @players, @areas = load
      @online = Hash(Mud::Net::ClientId, Player).new
      @events = Deque(Event).new
      @stop = false
    end

    # Loads previous save state from database (if present)
    def load
      uri = "sqlite3:./#{@db}.db"
      players = Hash(String, Player).new
      areas = Hash(String, Area).new

      DB.connect uri do |db|
        # First we load the players
        PlayerRecord.from_rs(db.query(<<-SQL
          SELECT name, password, id, room
          FROM players
          SQL
        )).each do |record|
          player = record.player
          players[player.name] = player
        end

        # Next we load the areas (which loads the rooms too)
        AreaRecord.from_rs(db.query(<<-SQL
          SELECT name, description
          FROM areas
          SQL
        )).each do |record|
          area = record.area(db, players)
          areas[area.name] = area
        end
      end
      Log.info { "World loaded from #{uri}" }

      # Make sure admin account consistent with command line invocation
      admin = players.fetch("admin") { Player.new("admin", 0_u16, @admin, "Lobby") }
      admin.password = @admin
      players["admin"] = admin

      {players, areas}
    rescue ex
      # Generate world from scratch
      Log.error { "Error loading world: #{ex.message}" }
      players = Hash(String, Player).new
      areas = Hash(String, Area).new

      # TODO

      admin = Player.new("admin", 0_u16, @admin, "Lobby")
      Log.info { "World generated from scratch" }

      {players, areas}
    end

    # Creates a new world with the given *server*.
    def self.start(server, admin, &)
      world = new(server, admin)
      begin
        yield world
      ensure
        world.save(timestamp = false)
      end
    end

    # Sends a message to a player
    def send(id, msg)
      @server.send(id, "\n#{msg}\n\n")
    end

    # Broadcasts a message to all players
    def broadcast(msg, exclude = -1)
      @server.broadcast("\n#{msg}\n\n", exclude)
    end

    # Stops the game
    def stop
      @stop = true
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
          player = Player.stranger(id)
          @online[id] = player # don't polute @players with strangers
          @server.send(id, BANNER.colorize(:magenta))
          send(id, INTRO)
          broadcast("#{player.name} rode into town".colorize(:yellow),
            exclude = id)
        end

        leavers.each do |id|
          if player = @online[id]?
            broadcast("#{player.name} rode off into the sunset".colorize(:yellow))
            @online.delete id
          end
        end

        # Check if the game has been stopped
        if @stop
          Log.info { "STOP received from admin" }
          broadcast("!!! SERVER CLOSED BY ADMINISTRATOR !!!".colorize(:red))
          break
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
    end

    # Save the game state to a database
    def save(timestamp = true)
      ts = timestamp ? Time.utc.to_s("_%Y%m%d_%H:%M:%S") : ""
      uri = "sqlite3:./#{@db}#{ts}.db"
      DB.connect uri do |db|
        db.transaction do |tx|
          con = tx.connection
          # TODO
        end
      end
      Log.info { "World saved to #{uri}" }
    rescue ex
      Log.error { "Error saving world: #{ex.message}" }
    end
  end
end
