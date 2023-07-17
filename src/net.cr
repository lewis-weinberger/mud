require "socket"
require "log"
require "./net/*"

# Functionality for communicating with clients over Telnet.
module Mud::Net
  alias ClientId = UInt16
  record Message, id : ClientId, message : String
  record Joiner, id : ClientId, sender : Channel(String)

  # A TCP server to host the game, which handles client connections.
  class Server
    # Time during which to process latest network activity
    private TICK = Time::Span.new(nanoseconds: 100_000_000)

    # Creates a TCP socket and spawns a fiber to wait for connections.
    def initialize(host, port)
      Log.setup_from_env
      Log.info &.emit("Hosting server", host: host, port: port)
      @server = TCPServer.new(host, port)
      @messages = Channel(Message).new(64)
      @joiners = Channel(Joiner).new(64)
      @leavers = Channel(ClientId).new(64)
      @clients = {} of ClientId => Channel(String)
      spawn accept
    end

    # Starts a server instance and yields it to the block.
    def self.open(host, port, &)
      server = new(host, port)
      begin
        yield server
      ensure
        server.close
      end
    end

    # Spawns a new handler fiber on each client connection.
    def accept
      id : ClientId = 0
      while client = @server.accept?
        Log.info { "Client #{id} connected on #{client.remote_address}" }
        channel = Channel(String).new(64)
        spawn handle_client(client, id, channel)
        id += 1
      end
    end

    # Runs main event loop which processes messages to and from clients
    # and then yields for game operations to take place.
    def run(&)
      messages = Array(Message).new
      joiners = Array(ClientId).new
      leavers = Array(ClientId).new

      loop do
        messages.clear
        joiners.clear
        leavers.clear

        # Accumulate messages from channels
        wait = TICK
        loop do
          start = Time.monotonic
          select
          when message = @messages.receive
            messages << message
          when joiner = @joiners.receive
            @clients[joiner.id] = joiner.sender
            joiners << joiner.id
          when leaver = @leavers.receive
            @clients.delete leaver
            leavers << leaver
          when timeout wait
            break
          end

          tick = Time.monotonic - start
          if tick < wait
            wait -= tick
          else
            break
          end
        end

        yield messages, joiners, leavers
      end
    end

    # Sends and receives messages from a client connection.
    def handle_client(socket, id, channel)
      reader = Channel(Nil).new
      spawn client_reader(id, socket, channel, reader)

      writer = Channel(Nil).new
      spawn client_writer(id, socket, channel, writer)

      # Wait until either handler ends, signifying client disconnect
      select
      when reader.receive?
      when writer.receive?
      end
      Log.info { "Client #{id} disconnected" }
      @leavers.send(id)
      socket.close
    end

    # Reads messages from the client.
    def client_reader(id, socket, channel, done)
      begin
        q = Telnet.new(channel)
        buffer = Bytes.new(2048)
        joined = false

        loop do
          n = socket.read(buffer)
          Log.debug { "Received from client #{id}: #{buffer[...n]}" }
          if n == 0
            raise "Socket closed"
          end

          q.parse?(buffer[...n]).each do |message|
            @messages.send(Message.new id, message)
          end

          if q.negotiate && joined == false
            @joiners.send(Joiner.new id, channel)
            joined = true
          end
        end
      rescue ex
        Log.debug(exception: ex) { "Client reader #{id}" }
      ensure
        channel.close
        done.close
      end
    end

    # Writes messages to the client.
    def client_writer(id, socket, channel, done)
      check_time = Time::Span.new(seconds: 5)
      begin
        loop do
          select
          when message = channel.receive
            Log.debug { "Sending to client #{id}: #{message.bytes}" }
            socket.write_string message.to_slice
          when timeout check_time
            socket.write_byte 0
          end
        end
      rescue ex
        Log.debug(exception: ex) { "Client writer #{id}" }
      ensure
        done.close
      end
    end

    # Sends a message to a specific connected client.
    def send(id, msg)
      if channel = @clients[id]?
        msg.to_s.each_line(chomp = true) do |line|
          # Telnet requires lines to end with CR LF
          channel.send("#{line}\r\n")
        end
      end
    end

    # Broadcasts a message to all connected clients.
    # Does not send to *exclude*.
    def broadcast(msg, exclude = -1)
      clients = @clients
      clients.each_key do |id|
        if exclude == id
          next
        end
        send(id, msg)
      end
    end

    # Tells the client to hide typed text.
    def hide(id)
      if channel = @clients[id]?
        channel.send("\x1b[8m")
      end
    end

    # Tells the client to unhide typed text.
    def unhide(id)
      if channel = @clients[id]?
        channel.send("\x1b[28m")
      end
    end

    # Closes the server and all channels.
    def close
      Log.info { "Stopping server" }
      @clients.each_value do |channel|
        channel.send("Server stopping now!")
      end
      @server.close
      @messages.close
      @joiners.close
      @leavers.close
    end
  end
end
