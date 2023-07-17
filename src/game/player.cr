module Mud::Game
  # A player character.
  #
  # TODO: documentation.
  class Player < Entity
    property name : String
    property password : String?

    @@stranger = 0

    def initialize(@name)
    end

    # Create a placeholder for new connections
    def self.stranger
      player = new("Stranger\##{@@stranger}")
      @@stranger += 1
      player
    end
  end
end
