require "rails_helper"

# Spec 20 (RN-20-015, D-639): our own client of clamd's INSTREAM, against a fake clamd on
# a local port that reads the protocol as clamd does. No test reaches a real ClamAV.
RSpec.describe Antivirus::Clamd do
  # Answers each connection with the reply for what it received.
  def fake_clamd(reply)
    server = TCPServer.new("127.0.0.1", 0)
    received = []
    thread = Thread.new do
      loop do
        socket = server.accept
        command = socket.gets("\0")
        data = +""
        if command == "zINSTREAM\0"
          while (size = socket.read(4).unpack1("N")).positive?
            data << socket.read(size)
          end
        end
        received << [ command, data ]
        socket.write(reply.respond_to?(:call) ? reply.call(command) : reply)
        socket.close
      end
    end
    yield described_class.new(host: "127.0.0.1", port: server.addr[1]), received
  ensure
    thread&.kill
    server&.close
  end

  it "streams the file in chunks and reads a clean answer" do
    content = "%PDF-1.4\n" + ("a" * 200_000)

    fake_clamd("stream: OK\0") do |client, received|
      expect(client.scan(StringIO.new(content))).to be_clean
      expect(received.sole).to eq([ "zINSTREAM\0", content ])
    end
  end

  it "reads the signature found" do
    fake_clamd("stream: Eicar-Test-Signature FOUND\0") do |client, _received|
      result = client.scan(StringIO.new("X5O!P"))

      expect(result).not_to be_clean
      expect(result.signature).to eq("Eicar-Test-Signature")
    end
  end

  it "raises on any other answer, such as the size limit" do
    fake_clamd("INSTREAM size limit exceeded. ERROR\0") do |client, _received|
      expect { client.scan(StringIO.new("x")) }.to raise_error(described_class::Error, /size limit/)
    end
  end

  it "pings" do
    fake_clamd(->(command) { command == "zPING\0" ? "PONG\0" : "" }) do |client, _received|
      expect(client.ping?).to be(true)
    end
  end

  it "is unavailable out of reach or without a host (RN-20-015)" do
    port = TCPServer.new("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }

    expect { described_class.new(host: "127.0.0.1", port: port).scan(StringIO.new("x")) }.to raise_error(described_class::Unavailable)
    expect { described_class.new(host: nil, port: 3310).scan(StringIO.new("x")) }.to raise_error(described_class::Unavailable)
    expect(described_class.new(host: nil, port: 3310).ping?).to be(false)
    expect(described_class).not_to be_configured
  end
end
