require "yaml"
require "log"

module Mud
  # Server configuration
  class Config
    include YAML::Serializable

    property host : String = "127.0.0.1"
    property port : UInt16 = 5023
    property passwd : String = Random::Secure.hex 8

    def to_s(io : IO)
      io << "Config { host: #{host}, port: #{port}, passwd: #{passwd} }"
    end

    def self.new(path)
      # Read configuration from file if it's available
      File.open(path) do |file|
        Log.info { "Loading configuration from #{path}" }
        Config.from_yaml file
      end
    rescue
      Config.from_yaml ""
    end
  end
end
