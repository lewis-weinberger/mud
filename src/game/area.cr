module Mud::Game
  # An area of the game world
  class Area
    property name : String
    property description : String
    property rooms : Hash(String, Room)

    def initialize(@name, @description, @rooms)
    end
  end

  # A room that players can occupy within an area of the world
  class Room
    property name : String
    property description : String
    property players : Hash(String, Player)
    property north : String
    property south : String
    property east : String
    property west : String

    def initialize(@name, @description, @north, @south, @east, @west, @players)
    end
  end
end
