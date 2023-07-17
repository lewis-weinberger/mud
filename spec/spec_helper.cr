require "spec"
require "../src/net/telnet.cr"

def create_test_telnet
  channel = Channel(String).new(64)
  telnet = Mud::Net::Telnet.new(channel)
  return channel, telnet
end
