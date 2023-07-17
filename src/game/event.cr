module Mud::Game
  # A game event.
  #
  # Events are generated as a result of the actions of player and
  # non-player characters.
  #
  # If an event needs to do something that will block progress, it
  # MUST spawn a Fiber to do this, otherwise the game will grind to
  # a halt.
  class Event
    def initialize(@finished = false)
    end

    def run
      @finished = true
    end

    def finished?
      @finished
    end
  end
end
