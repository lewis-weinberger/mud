require "socket"
require "log"

module Mud::Net
  # A Telnet protocol manager (RFC 854).
  #
  # The game implementation assumes a few things about a client connection:
  #   - UTF-8 encoding of text in both directions,
  #   - terminal emulation on the client side that supports ANSI control
  #   codes to modify the presentation of text.
  #
  # In order to guarantee these assumptions hold, when we open a new Telnet
  # connection we negotiate the following options:
  #   - Binary Transmission (RFC 856), to ensure 8-bit clean data transfer,
  #   - Terminal Type (RFC 1091), to query the client's terminal capabilites,
  #
  # Additionally the interface is intended to be used with Line-editing on the
  # client side such that the server receives content a line at a time. To
  # guarantee this we try to negotiate (but don't require):
  #   - Linemode (RFC 1184), to set the required line-editing configuration.
  #
  # If during initial negotiations any of these options are rejected, then
  # the client is informed of the incompability and the connection is closed.
  # Otherwise we begin sub-negotiations to check for the right terminal type
  # and line-editing configuration.
  #
  # Once all the configuration is complete the game can start to talk to the
  # client, safe in the above assumptions.
  #
  # The implementation below has been tested against the following Telnet
  # client programs:
  #   - Inetutils telnet on xterm
  #   - OpenBSD telnet on xterm
  #   - Windows 10 telnet on CMD
  #   - PuTTY telnet
  class Telnet
    SE   = 240_u8
    BRK  = 243_u8
    IP   = 244_u8
    SB   = 250_u8
    WILL = 251_u8
    WONT = 252_u8
    DO   = 253_u8
    DONT = 254_u8
    IAC  = 255_u8

    BT =  0_u8
    TT = 24_u8
    LM = 34_u8

    # Accepted terminal types
    TERMS = ["XTERM", "ANSI"]

    @cache : String?
    @previous_term : String?

    def initialize(@channel : Channel(String))
      @options = {} of UInt8 => Option
      @state = State::Data
      @previous = 0_u8
      @sub = [] of Array(UInt8)

      # Start negotiations for the options that we need
      @binary = Negotiation::Before
      @terminal = Negotiation::Before
      @linemode = Negotiation::Before

      @options[BT] = Option.wantyes
      @options[TT] = Option.new(OptionState::No, OptionState::WantYes)
      @options[LM] = Option.new(OptionState::No, OptionState::WantYes)
      @channel.send(String.new(Bytes[IAC, DO, BT, IAC, WILL, BT,
        IAC, DO, TT, IAC, DO, LM]))
    end

    # Processes bytes read from Telnet stream.
    def parse?(buf : Bytes) : Array(String)
      sub = [] of UInt8
      str = String.build do |io|
        if @cache
          io << @cache
          @cache = nil
        end
        buf.each do |x|
          if @state == State::Data
            data(x, io)
          elsif @state == State::Command
            command(x)
          else
            subnegotiation(x, sub)
          end
          @previous = x
        end
      end
      lines = str.lines(false)

      # Return only complete lines, otherwise cache for later
      if lines.size == 0 || lines[-1].ends_with?("\n")
        lines
      else
        @cache = lines[-1]
        lines[...-1]
      end
    end

    # Responds to Telnet negotiations.
    def negotiate
      @options.each do |code, option|
        case code
        when BT
          negotiate_bt(option)
          next
        when TT
          negotiate_tt(option)
          next
        when LM
          negotiate_lm(option)
          next
        end

        # Otherwise we deny requests
        if option.us == OptionState::Yes
          @channel.send(String.new(Bytes[IAC, WONT, code]))
          option.us = OptionState::WantNo
        end

        if option.them == OptionState::Yes
          @channel.send(String.new(Bytes[IAC, DONT, code]))
          option.them = OptionState::WantNo
        end
      end

      if done = negotiated?
        @sub.clear
      end
      done
    end

    # Returns whether all prerequisite negotiations have succeeded?
    def negotiated?
      @binary == Negotiation::After &&
        @terminal == Negotiation::After &&
        @linemode == Negotiation::After
    end

    # Negotiates the binary transmission option.
    def negotiate_bt(option)
      if option.them == OptionState::No || option.us == OptionState::No
        @channel.send("Incompatible Telnet configuration!\r\n" \
                      "Binary transmission required.\r\n")
        raise "incompatible Telnet client (binary transmission)"
      elsif option.them == OptionState::Yes &&
            option.us == OptionState::Yes &&
            @binary == Negotiation::Before
        @binary = Negotiation::After
        Log.debug { "Binary transmission accepted" }
      end
    end

    # Negotiates the terminal type option.
    def negotiate_tt(option)
      if option.them == OptionState::No
        @channel.send("Incompatible Telnet configuration!\r\n" \
                      "Terminal type required.\r\n")
        raise "incompatible Telnet client (terminal type)"
      elsif option.them == OptionState::Yes && @terminal == Negotiation::Before
        @channel.send(String.new(Bytes[IAC, SB, TT, 1, IAC, SE]))
        @terminal = Negotiation::During
      elsif @terminal == Negotiation::During && @sub.size > 0
        i = 0
        while i < @sub.size
          sub = @sub[i]
          if sub.size >= 3 && sub[0] == TT && sub[1] == 0
            term = String.build do |io|
              sub[2..].each { |x| io.write_byte x }
            end
            Log.debug { "Received TERM = #{term}" }

            if TERMS.includes?(term.upcase)
              @terminal = Negotiation::After
              Log.debug { "Accepted TERM = #{term}" }
              break
            elsif term == @previous_term
              # A repeat indicates the client has looped through all their
              # options. Since we've got here without accepting a terminal
              # type, unfortunately we have to close the connection.
              @channel.send("Incompatible Telnet configuration!\r\n" \
                            "Terminal type in #{TERMS} required.\r\n")
              raise "incompatible Telnet client (terminal type)"
            else
              # Request another terminal type
              @channel.send(String.new(Bytes[IAC, SB, TT, 1, IAC, SE]))
            end

            @previous_term = term
            @sub.delete_at i
            i -= 1
          end
          i += 1
        end
      end
    end

    # Attempts to negotiate the linemode option.
    def negotiate_lm(option)
      if option.them == OptionState::No && @linemode == Negotiation::Before
        # It's not ideal but if linemode isn't supported we'll continue anyway.
        @linemode = Negotiation::After
        Log.debug { "Linemode not supported" }
      elsif option.them == OptionState::Yes && @linemode == Negotiation::Before
        # Ignore any initial linemode messages from the client.
        @sub.reject! { |sub| sub.size > 0 && sub[0] == LM }

        # Send our desired linemode
        @channel.send(String.new(Bytes[IAC, SB, LM, 1, 3, IAC, SE,
          IAC, SB, LM, DONT, 2, IAC, SE]))
        @linemode = Negotiation::During
      elsif @linemode == Negotiation::During && @sub.size > 0
        i = 0
        while i < @sub.size
          sub = @sub[i]
          if sub.size > 0 && sub[0] == LM
            # Process confirmation of our linemode configuration
            # request. Currently we ignore SLC-related messages.
            if sub.size >= 3 && sub[1] == 1
              if sub[2] == 7 # EDIT, TRAPSIG, MODE_ACK
                @linemode = Negotiation::After
                Log.debug { "Linemode accepted" }
                break
              else
                @channel.send("Incompatible Telnet configuration!\r\n" \
                              "Linemode EDIT + TRAPSIG required.\r\n")
                raise "incompatible Telnet client (linemode)"
              end
            end

            @sub.delete_at i
            i -= 1
          end
          i += 1
        end
      end
    end

    # Interprets input byte as data.
    def data(b, str)
      case b
      when IAC
        @state = State::Command
      when 8
        # Backspace
        str.back 1
      when 3
        # Ctrl-C
        raise "received Interrupt Process"
      else
        # In some Telnet clients when binary transmission is active
        # the return key sends only a linefeed and so the cursor
        # position is not returned to the beginning of the line.
        # We therefore send a carriage return just in case!
        if b == 10 && @previous != 13
          @channel.send("\r")
          str << "\r\n"
          # Newlines are complicated
        elsif b == 13
          str << "\r\n"
        elsif b == 10 && @previous == 13
          # Already accounted for
        elsif b == 9 || b > 31
          str.write_byte b
        end
      end
    end

    # Interprets input byte as part of a command.
    def command(b)
      case b
      when SB
        @state = State::Subnegotiation
      when DO, DONT, WILL, WONT
        @state = State::Command
      when IP, BRK
        raise "received Interrupt Process"
      else
        case @previous
        when DO
          option = @options.fetch(b, Option.no)
          option.us = option.us.receive_positive
          @options[b] = option
        when WILL
          option = @options.fetch(b, Option.no)
          option.them = option.them.receive_positive
          @options[b] = option
        when DONT
          option = @options.fetch(b, Option.no)
          option.us = option.us.receive_negative
          @options[b] = option
        when WONT
          option = @options.fetch(b, Option.no)
          option.them = option.them.receive_negative
          @options[b] = option
        end
        @state = State::Data
      end
    end

    # Interprets input byte as part of a subnegotiation.
    def subnegotiation(b, sub)
      if b == SE && @previous == IAC
        @sub << sub[...-1]
        sub.clear
        @state = State::Data
      else
        sub << b
      end
    end
  end

  # Possible states for a Telnet option (RFC 1143).
  enum OptionState
    No
    WantNo
    WantNoOpposite
    Yes
    WantYes
    WantYesOpposite

    def receive_positive : OptionState
      case self
      when No
        Yes
      when WantNo
        WantNo
      when WantNoOpposite
        Yes
      when Yes
        Yes
      when WantYes
        Yes
      else # WantYesOpposite
        WantNo
      end
    end

    def receive_negative : OptionState
      case self
      when No
        No
      when WantNo
        No
      when WantNoOpposite
        WantYes
      when Yes
        No
      when WantYes
        No
      else # WantYesOpposite
        No
      end
    end
  end

  # State for an option under negotiation (Q method).
  class Option
    property us : OptionState
    property them : OptionState

    def initialize(@us : OptionState, @them : OptionState)
    end

    def self.no
      new(OptionState::No, OptionState::No)
    end

    def self.wantyes
      new(OptionState::WantYes, OptionState::WantYes)
    end
  end

  # Possible states for interpreting a Telnet stream.
  enum State
    Data
    Command
    Subnegotiation
  end

  # Possible states for negotiating an option.
  enum Negotiation
    Before
    During
    After
  end
end
