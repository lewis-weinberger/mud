require "db"

module Mud::Game
  # Database record for a Player
  class PlayerRecord
    DB.mapping({
      name:     String,
      password: String,
      id:       Int32,
      room:     String,
    })

    def player
      Player.new(@name, @id.to_u16, @password, @room)
    end
  end

  # Database record for an Area
  class AreaRecord
    DB.mapping({
      name:        String,
      description: String,
    })

    # Load an Area from the database
    def area(db, all_players)
      rooms = Hash(String, Room).new
      RoomRecord.from_rs(db.query(<<-SQL
        SELECT name, description, north, south, east, west
        FROM #{@name}
        SQL
      )).each do |record|
        room = record.room(@name, all_players)
        rooms[room.name] = room
      end
      Area.new(@name, @description, rooms)
    end
  end

  # Database record for a Room
  class RoomRecord
    DB.mapping({
      name:        String,
      description: String,
      north:       String,
      south:       String,
      east:        String,
      west:        String,
    })

    # Load a Room from the database
    def room(area, all_players)
      players = Hash(String, Player).new
      all_players.values.each do |player|
        if player.room == @name
          players[player.name] = player
        end
      end
      Room.new(@name, @description, @north, @south, @east, @west, players)
    end
  end
end
