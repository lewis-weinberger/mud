require "option_parser"
require "log"
require "./net"
require "./game"
require "./config"

module Mud
  VERSION     = "0.1.0"
  DESCRIPTION = "Multi User Dungeon (MUD), a simple game server."
  config_path = "config.yml"

  OptionParser.parse do |parser|
    parser.banner = "#{DESCRIPTION}\n\nUsage: mud"
    parser.on("-v", "--version", "Print version.") do
      puts "mud #{VERSION}"
      exit
    end
    parser.on("-h", "--help", "Print help.") do
      puts parser
      exit
    end
    parser.on("-c PATH",
      "--config=PATH",
      "Specifies configuration file.") do |path|
      config_path = path
    end
    parser.invalid_option do |flag|
      STDERR.puts "Error: #{flag} is not a valid option."
      STDERR.puts parser
      exit 1
    end
  end

  begin
    Log.setup_from_env

    config = Config.new config_path
    Log.info { "Using #{config}" }

    # Start a server and create a new game world to run
    Mud::Net::Server.open(config.host, config.port) do |server|
      Mud::Game::World.start(server, config) do |world|
        world.run
      end
    end
  rescue ex
    STDERR.puts "Error: #{ex.message}!"
    exit 1
  end
end
