require "socket"

module Antivirus
  # Our own client of clamd's INSTREAM over TCP (RN-20-015, D-639), without a gem. The
  # protocol, from ClamAV's documentation (clamd(8), "Clamd protocol"): the command goes
  # as "zINSTREAM\0"; the file follows in chunks, each one with its size in 4 bytes, big
  # endian, and a chunk of size zero ends it; clamd answers "stream: OK" or
  # "stream: <signature> FOUND", ended by "\0", and closes the connection. clamd
  # authenticates nobody, so it stays on the private network (RN-20-012).
  class Clamd
    # clamd is out of reach or not configured: the file stays in scanning (RN-20-015).
    class Unavailable < StandardError; end
    # clamd answered something other than a result, such as the size limit.
    class Error < StandardError; end

    Result = Data.define(:signature) do
      def clean?
        signature.nil?
      end
    end

    CHUNK_SIZE = 64.kilobytes
    CONNECT_TIMEOUT = 5
    # clamd's own ReadTimeout is 120 seconds; a 10 MB file takes far less.
    READ_TIMEOUT = 60
    NETWORK_ERRORS = [ SocketError, SystemCallError, IOError, IO::TimeoutError ].freeze

    def self.configured?
      Rails.configuration.x.clamav_host.present?
    end

    def initialize(host: Rails.configuration.x.clamav_host, port: Rails.configuration.x.clamav_port)
      @host = host
      @port = port
    end

    # io: anything that answers read(size), such as the file Active Storage opens.
    def scan(io)
      reply = exchange do |socket|
        socket.write("zINSTREAM\0")
        while (chunk = io.read(CHUNK_SIZE))
          socket.write([ chunk.bytesize ].pack("N"), chunk)
        end
        socket.write([ 0 ].pack("N"))
      end
      parse(reply)
    end

    def ping?
      exchange { |socket| socket.write("zPING\0") } == "PONG"
    rescue Unavailable
      false
    end

    private

    def exchange
      raise Unavailable, "ClamAV host not configured" if @host.blank?
      raise Simulation::ExternalCallBlocked, "ClamAV call refused during an impersonate simulation" if Simulation.active?

      Socket.tcp(@host, @port, connect_timeout: CONNECT_TIMEOUT) do |socket|
        socket.timeout = READ_TIMEOUT
        yield socket
        socket.read.to_s.delete_suffix("\0").strip
      end
    rescue *NETWORK_ERRORS => error
      raise Unavailable, error.class.name
    end

    def parse(reply)
      case reply
      when "stream: OK" then Result.new(signature: nil)
      when /\Astream: (.+) FOUND\z/ then Result.new(signature: Regexp.last_match(1))
      else raise Error, reply.truncate(200)
      end
    end
  end
end
