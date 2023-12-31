require "db"

module Mud::Game
  # A player character.
  #
  # TODO: documentation.
  class Player < Entity
    property name : String
    property password : String
    property id : Mud::Net::ClientId
    property room : String

    @@stranger = 0

    def initialize(@name, @id, @password, @room)
    end

    # Create a placeholder for new connections
    def self.stranger(id)
      player = new("Stranger\##{@@stranger}", id, "stranger#{@@stranger}", "Lobby")
      @@stranger += 1
      player
    end
  end
end
