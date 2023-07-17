require "./spec_helper.cr"

describe "Mud::Server::Telnet" do
  describe "#parse?" do
    it "correctly parses data" do
      sender, telnet = create_test_telnet

      # feed two complete and one incomplete line
      lines = telnet.parse?("test data\r\nanother\r\nincomplete".to_slice)
      lines[0].should eq "test data\r\n"
      lines[1].should eq "another\r\n"

      # complete final line to get cached data
      final = telnet.parse?("\r\n".to_slice)
      final[0].should eq "incomplete\r\n"
    end

    it "correctly parses non-data" do
      sender, telnet = create_test_telnet
      output = telnet.parse?(Bytes[Mud::Net::Telnet::IAC, Mud::Net::Telnet::DO])
      output.empty?.should be_true
    end

    it "correctly handles no input" do
      sender, telnet = create_test_telnet
      output = telnet.parse?(Bytes[])
      output.empty?.should be_true
    end
  end

  describe "#negotiate" do
    pending "correctly parses commands" do
      sender, telnet = create_test_telnet
    end

    pending "correctly parses subcommands" do
      sender, telnet = create_test_telnet
    end

    pending "correctly negotiates binary transmission" do
      sender, telnet = create_test_telnet
    end

    pending "correctly negotiates terminal type" do
      sender, telnet = create_test_telnet
    end

    pending "correctly negotiates linemode" do
      sender, telnet = create_test_telnet
    end
  end
end
