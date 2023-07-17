require "../net"

module Mud::Game
  # The base class for all user commands.
  abstract class Command
    @id : Mud::Net::ClientId
    @world : Mud::Game::World

    UNKNOWN = [["Sorry pard, I don't know what \"",
                "\" means... Highfalutin city speak, no doubt."],
               ["Well I declare! I ain't never heard \"",
                "\" before. Whatever do you mean?"],
               ["Say what now, friend? I don't comprehend \"",
                "\". When in doubt, let your horse do the thinkin'."]]

    @@unknown = 0

    def initialize(@id, @world)
    end

    # Attempts to parse user input into a command.
    def self.parse(id, input, world) : Command?
      words = input.split
      if words.empty?
        return
      end

      case words[0].upcase
      when "NAME", "NA"
        Name.new(id, world, words)
      when "SAY", "SA"
        Say.new(id, world, input)
      when "SHOUT", "SH"
        Shout.new(id, world, input)
      when "LOOK", "L"
        Look.new(id, world)
      when "HELP", "H", "?"
        Help.new(id, world)
      else
        # Print a message to say we don't recognise that command
        s = UNKNOWN[@@unknown]
        @@unknown = (@@unknown + 1) % 3
        world.server.send(id, s[0] + words[0].colorize(:red).to_s + s[1])
        nil
      end
    end

    # Runs the command.
    # `Mud::Game::Command` sends a message indicating the command isn't
    # implemented, but subclasses will override this.
    def run
      @world.server.send(@id, {{ @type.stringify }} + " not yet implemented")
    end
  end

  # A command to allow players to login or create a new character.
  class Name < Command
    def initialize(@id, @world, words)
    end

    # Yields help description.
    def self.help(&)
      yield "name/na", "NAME", "identify yourself by a given player name"
    end
  end

  # A command to let players communicate with other players in the same room.
  class Say < Command
    def initialize(@id, @world, input)
    end

    # Yields help description.
    def self.help(&)
      yield "say/sa", "MESSAGE", "send MESSAGE to other players in the room"
    end
  end

  # A command to let players communicate with the rest of the server.
  class Shout < Command
    def initialize(@id, @world, input)
    end

    # Yields help description.
    def self.help
      yield "shout/sh", "MESSAGE", "send MESSAGE to everyone"
    end
  end

  # A command to let players learn about the room they're in.
  class Look < Command
    def initialize(@id, @world)
    end

    # Yields help description.
    def self.help
      yield "look/l", "", "print a description of the room occupied by the player"
    end
  end

  # The help command to tell players what commands are available.
  class Help < Command
    def initialize(@id, @world)
    end

    @@str : String = self.compile

    # Constructs the help string based on implemented commands.
    def self.compile
      cmds = [] of String
      args = [] of String
      descs = [] of String
      {% for command, index in Command.all_subclasses %}
        {{command.name}}.help do |cmd, arg, desc|
          cmds << cmd
          args << arg
          descs << desc
        end
      {% end %}

      # Build help string from individual command help strings
      str = String.build do |str|
        str << HELP
        (0...cmds.size).each do |i|
          str << cmds[i].colorize(:magenta).to_s
          str << " " * (cmds.max_of { |x| x.size } - cmds[i].size + 1)
          str << args[i].colorize(:cyan).to_s
          str << " " * (args.max_of { |x| x.size } - args[i].size + 1)
          str << "- "
          str << descs[i]
          str << "\n"
        end
        str << "\nFinally, remember: don't squat with your spurs on!\n\n"
      end
      str
    end

    # Runs the help command to print information about available commands.
    def run
      @world.server.send(@id, @@str)
    end

    # Yields help description.
    def self.help
      yield "help/h/?", "", "print available commands"
    end
  end
end
