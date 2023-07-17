require "option_parser"
require "./net"
require "./game"

module Mud
  VERSION     = "0.1.0"
  DESCRIPTION = "Multi User Dungeon (MUD), a simple game server."

  OptionParser.parse do |parser|
    parser.banner = "#{DESCRIPTION}\n\nUsage: mud ADDRESS PORT"
    parser.on("-v", "--version", "Print version.") do
      puts "mud #{VERSION}"
      exit
    end
    parser.on("-h", "--help", "Print help.") do
      puts parser
      exit
    end
    parser.invalid_option do |flag|
      STDERR.puts "Error: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end
  end

  begin
    if ARGV.size < 2
      raise "incorrect argument; require ADDRESS & PORT"
      exit(1)
    end

    # Start a server and create a new game world to run
    Mud::Net::Server.open(ARGV[0], ARGV[1].to_i) do |server|
      Mud::Game::World.start(server) do |world|
        world.run
      end
    end
  rescue ex
    STDERR.puts "Error: #{ex.message}!"
    exit(1)
  end
end
